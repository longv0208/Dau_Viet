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
        assertThat(config.has("pairs")).isTrue();
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
