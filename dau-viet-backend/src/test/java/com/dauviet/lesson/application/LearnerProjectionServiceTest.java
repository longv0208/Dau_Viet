package com.dauviet.lesson.application;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Pure unit tests for learner-safe projection — no Spring, no DB. */
class LearnerProjectionServiceTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final LearnerProjectionService projection = new LearnerProjectionService();

    private JsonNode project(String json) throws Exception {
        return projection.project(MAPPER.readTree(json));
    }

    @Test
    void stripsAnswerKeysDeepInsideConfig() throws Exception {
        JsonNode out = project("""
                {"stages":[{"id":"s","type":"REASONING",
                            "activities":[{"id":"a","type":"MULTIPLE_CHOICE",
                                           "config":{"question":"q?",
                                                     "options":[{"id":"o1"},{"id":"o2"}],
                                                     "correctOptionIds":["o1"]}}]}]}
                """);
        JsonNode config = out.at("/stages/0/activities/0/config");
        assertThat(config.has("question")).isTrue();
        assertThat(config.has("options")).isTrue();
        assertThat(config.has("correctOptionIds")).isFalse();
    }

    @Test
    void stripsEveryHiddenKeyLeafName() throws Exception {
        JsonNode out = project("""
                {"stages":[{"id":"s","type":"EVIDENCE",
                            "activities":[{"id":"a","type":"MATCHING",
                                           "config":{"pairs":[],
                                                     "correctPairs":[{"left":"a","right":"b"}],
                                                     "correctOrder":["x"],
                                                     "expectedOrder":["y"],
                                                     "requiredEvidenceIds":["e1"],
                                                     "expectedHypothesis":"h",
                                                     "answerKey":{"a":1},
                                                     "answer":"v",
                                                     "key":"k",
                                                     "expected":42}}]}]}
                """);
        JsonNode config = out.at("/stages/0/activities/0/config");
        // MATCHING transform replaces pairs[] with leftItems/rightItems columns.
        assertThat(config.has("pairs")).isFalse();
        assertThat(config.has("leftItems")).isTrue();
        assertThat(config.has("rightItems")).isTrue();
        for (String hidden : new String[]{"correctPairs", "correctOrder", "expectedOrder",
                "requiredEvidenceIds", "expectedHypothesis", "answerKey",
                "answer", "key", "expected"}) {
            assertThat(config.has(hidden)).as("hidden key %s stripped", hidden).isFalse();
        }
    }

    @Test
    void stripsValidationAndStageRequiredEvidence() throws Exception {
        JsonNode out = project("""
                {"stages":[{"id":"s","type":"VERIFICATION","requiredEvidenceIds":["e1"],
                            "activities":[{"id":"a","type":"VERIFICATION",
                                           "validation":{"kind":"SCORE","pass":80},
                                           "config":{"visibleSourceIds":["e2"]}}]}]}
                """);
        JsonNode stage = out.at("/stages/0");
        assertThat(stage.has("requiredEvidenceIds")).isFalse();
        JsonNode act = out.at("/stages/0/activities/0");
        assertThat(act.has("validation")).isFalse();
    }

    @Test
    void stripsHiddenKeysNestedInArrays() throws Exception {
        JsonNode out = project("""
                {"stages":[{"id":"s","type":"CONCLUSION",
                            "activities":[{"id":"a","type":"CER",
                                           "config":{"rubric":{"criteria":[
                                                     {"id":"c1","answer":"secret"}]}}}]}]}
                """);
        JsonNode criteria = out.at("/stages/0/activities/0/config/rubric/criteria/0");
        assertThat(criteria.has("answer")).isFalse();
        assertThat(criteria.has("id")).isTrue();
    }

    @Test
    void keepsLearnerFacingFields() throws Exception {
        JsonNode out = project("""
                {"schemaVersion":1,"lessonId":"l","title":"T","centralQuestion":"Q?",
                 "objectives":["learn"],"templateCode":"tpl",
                 "stages":[{"id":"s","type":"CONTEXT","title":"Intro",
                            "nextStageIds":["n"],
                            "activities":[{"id":"a","type":"READ",
                                           "instruction":"Đọc","required":true,
                                           "config":{"text":"body"},
                                           "feedback":{"ok":"good"}}]}],
                 "completion":{"requireAllRequiredStages":true},
                 "evidence":[{"id":"e","title":"t"}]}
                """);
        assertThat(out.get("title").asText()).isEqualTo("T");
        assertThat(out.get("centralQuestion").asText()).isEqualTo("Q?");
        assertThat(out.at("/stages/0/title").asText()).isEqualTo("Intro");
        assertThat(out.at("/stages/0/nextStageIds/0").asText()).isEqualTo("n");
        assertThat(out.at("/stages/0/activities/0/instruction").asText()).isEqualTo("Đọc");
        assertThat(out.at("/stages/0/activities/0/config/text").asText()).isEqualTo("body");
        assertThat(out.at("/stages/0/activities/0/feedback/ok").asText()).isEqualTo("good");
        assertThat(out.at("/completion/requireAllRequiredStages").asBoolean()).isTrue();
        assertThat(out.at("/evidence/0/id").asText()).isEqualTo("e");
    }

    @Test
    void stripsHiddenKeysInDeepArraysAndValidationDescendants() throws Exception {
        JsonNode out = project("""
                {"stages":[{"id":"s","type":"EVIDENCE",
                            "activities":[{"id":"a","type":"EVIDENCE_SELECT",
                                           "validation":{"kind":"SCORE",
                                                         "rubric":{"answerKey":{"x":1}}},
                                           "config":{"groups":[[{"answer":"s"}]]}}]}]}
                """);
        // object-shaped validation is dropped wholesale
        assertThat(out.at("/stages/0/activities/0/validation").isMissingNode()).isTrue();
        // array nested inside array inside config
        assertThat(out.at("/stages/0/activities/0/config/groups").toString())
                .doesNotContain("answer");
    }

    @Test
    void listShapedValidation_keptButStripped() throws Exception {
        // Defensive: a list-shaped `validation` is not dropped by the
        // remove-name pass — hidden keys inside it must still die.
        JsonNode out = project("""
                {"stages":[{"id":"s","type":"EVIDENCE",
                            "activities":[{"id":"a","type":"EVIDENCE_SELECT",
                                           "config":{"checklist":[
                                                     {"item":"v","answerKey":{"x":1}},
                                                     [{"answer":"y"}]]}}]}]}
                """);
        String payload = out.at("/stages/0/activities/0/config/checklist").toString();
        assertThat(payload).doesNotContain("answerKey");
        assertThat(payload).doesNotContain("answer");
        assertThat(payload).contains("item");
    }

    @Test
    void stripsMultiCorrectLegacyKey() throws Exception {
        JsonNode out = project("""
                {"stages":[{"id":"s","type":"EVIDENCE",
                            "activities":[{"id":"a","type":"MULTIPLE_CHOICE",
                                           "config":{"question":"q?",
                                                     "options":[{"id":"o1"},{"id":"o2"}],
                                                     "multiCorrect":["o1","o2"],
                                                     "multiSelect":true}}]}]}
                """);
        JsonNode config = out.at("/stages/0/activities/0/config");
        assertThat(config.has("multiCorrect")).isFalse();
        assertThat(config.has("correctOptionIds")).isFalse();
        // multiSelect is a display flag, not an answer key — it stays.
        assertThat(config.get("multiSelect").asBoolean()).isTrue();
    }

    @Test
    void matching_stripsPairsAndEmitsIndependentColumns() throws Exception {
        JsonNode out = project("""
                {"stages":[{"id":"s","type":"REASONING",
                            "activities":[{"id":"m1","type":"MATCHING",
                                           "config":{"pairs":[
                                                     {"left":{"id":"l1","label":"L1"},
                                                      "right":{"id":"r1","label":"R1"}},
                                                     {"left":{"id":"l2","label":"L2"},
                                                      "right":{"id":"r2","label":"R2"}},
                                                     {"left":{"id":"l3","label":"L3"},
                                                      "right":{"id":"r3","label":"R3"}}],
                                                     "correctPairs":[
                                                     {"left":"l1","right":"r1"},
                                                     {"left":"l2","right":"r2"},
                                                     {"left":"l3","right":"r3"}]}}]}]}
                """);
        JsonNode config = out.at("/stages/0/activities/0/config");
        assertThat(config.has("pairs")).isFalse();
        assertThat(config.has("correctPairs")).isFalse();
        JsonNode left = config.get("leftItems");
        JsonNode right = config.get("rightItems");
        assertThat(left.isArray() && left.size() == 3).isTrue();
        assertThat(right.isArray() && right.size() == 3).isTrue();
        // All authored ids present on each side.
        var leftIds = new java.util.TreeSet<String>();
        left.forEach(n -> leftIds.add(n.get("id").asText()));
        var rightIds = new java.util.TreeSet<String>();
        right.forEach(n -> rightIds.add(n.get("id").asText()));
        assertThat(leftIds).containsExactly("l1", "l2", "l3");
        assertThat(rightIds).containsExactly("r1", "r2", "r3");
        // Structural non-reveal: index i on the left must not map to the
        // authored partner index on the right for at least one position —
        // i.e. you cannot reconstruct the mapping by zipping the two arrays.
        boolean reconstructible = true;
        java.util.Map<String, String> authored = java.util.Map.of(
                "l1", "r1", "l2", "r2", "l3", "r3");
        for (int i = 0; i < left.size(); i++) {
            if (!authored.get(left.get(i).get("id").asText())
                    .equals(right.get(i).get("id").asText())) {
                reconstructible = false;
                break;
            }
        }
        assertThat(reconstructible).isFalse();
    }

    @Test
    void matching_projectionDeterministicAcrossCalls() throws Exception {
        String draft = """
                {"stages":[{"id":"s","type":"REASONING",
                            "activities":[{"id":"m1","type":"MATCHING",
                                           "config":{"pairs":[
                                                     {"left":{"id":"l1","label":"L1"},
                                                      "right":{"id":"r1","label":"R1"}},
                                                     {"left":{"id":"l2","label":"L2"},
                                                      "right":{"id":"r2","label":"R2"}}],
                                                     "correctPairs":[
                                                     {"left":"l1","right":"r1"},
                                                     {"left":"l2","right":"r2"}]}}]}]}
                """;
        JsonNode first = project(draft);
        JsonNode second = project(draft);
        assertThat(first.at("/stages/0/activities/0/config/leftItems").toString())
                .isEqualTo(second.at("/stages/0/activities/0/config/leftItems").toString());
        assertThat(first.at("/stages/0/activities/0/config/rightItems").toString())
                .isEqualTo(second.at("/stages/0/activities/0/config/rightItems").toString());
    }

    @Test
    void matching_inputSnapshotNotMutated() throws Exception {
        JsonNode input = MAPPER.readTree("""
                {"stages":[{"id":"s","type":"REASONING",
                            "activities":[{"id":"m1","type":"MATCHING",
                                           "config":{"pairs":[
                                                     {"left":{"id":"l1"},"right":{"id":"r1"}}],
                                                     "correctPairs":[{"left":"l1","right":"r1"}]}}]}]}
                """);
        String before = MAPPER.writeValueAsString(input);
        projection.project(input);
        assertThat(MAPPER.writeValueAsString(input)).isEqualTo(before);
    }

    @Test
    void dragOrder_projectsItemsInDifferentStableOrder() throws Exception {
        String draft = """
                {"stages":[{"id":"s","type":"RECONSTRUCTION",
                            "activities":[{"id":"d1","type":"DRAG_ORDER",
                                           "config":{"items":[
                                                     {"id":"i1","label":"B1"},
                                                     {"id":"i2","label":"B2"},
                                                     {"id":"i3","label":"B3"}],
                                                     "expectedOrder":["i1","i2","i3"]}}]}]}
                """;
        JsonNode out = project(draft);
        JsonNode config = out.at("/stages/0/activities/0/config");
        assertThat(config.has("expectedOrder")).isFalse();
        JsonNode items = config.get("items");
        assertThat(items.size()).isEqualTo(3);
        var projectedIds = items.findValuesAsText("id");
        // Learner order must differ from the answer key.
        assertThat(projectedIds).isNotEqualTo(java.util.List.of("i1", "i2", "i3"));
        // All items still present.
        assertThat(new java.util.TreeSet<>(projectedIds))
                .containsExactly("i1", "i2", "i3");
        // Deterministic: same input → same projected order.
        JsonNode again = project(draft);
        assertThat(again.at("/stages/0/activities/0/config/items").toString())
                .isEqualTo(items.toString());
    }

    @Test
    void dragOrder_answerKeyStillGradesOriginalSequence() throws Exception {
        // Projection only rewrites the learner-facing copy — the snapshot the
        // handler reads keeps items + expectedOrder untouched.
        JsonNode input = MAPPER.readTree("""
                {"stages":[{"id":"s","type":"RECONSTRUCTION",
                            "activities":[{"id":"d1","type":"DRAG_ORDER",
                                           "config":{"items":[{"id":"i1"},{"id":"i2"}],
                                                     "expectedOrder":["i1","i2"]}}]}]}
                """);
        String before = MAPPER.writeValueAsString(input);
        projection.project(input);
        // Input snapshot unchanged → grading unaffected.
        assertThat(MAPPER.writeValueAsString(input)).isEqualTo(before);
    }

    @Test
    void doesNotMutateInput() throws Exception {
        JsonNode input = MAPPER.readTree("""
                {"stages":[{"id":"s","activities":[{"id":"a",
                            "config":{"correctOptionIds":["o1"]}}]}]}
                """);
        String before = MAPPER.writeValueAsString(input);
        projection.project(input);
        assertThat(MAPPER.writeValueAsString(input)).isEqualTo(before);
    }

    @Test
    void toleratesEmptyAndMissingStages() throws Exception {
        assertThat(projection.project(MAPPER.readTree("{}")).isObject()).isTrue();
        assertThat(projection.project(null).isObject()).isTrue();
        assertThat(projection.project(MAPPER.readTree("{\"stages\":[]}"))
                .get("stages").isArray()).isTrue();
    }
}
