package com.dauviet.lesson.draft;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.dauviet.lesson.draft.validators.MultipleChoiceValidator;
import com.dauviet.lesson.draft.validators.SimpleActivityValidators;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.dauviet.lesson.infrastructure.persistence.EvidenceRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Pure unit tests for CER_CHOICE + graded-mode validators. */
class CerChoiceValidatorTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final UUID EVENT = UUID.randomUUID();

    private EvidenceRepository evidences;
    private AssetRepository assets;
    private com.dauviet.animation.infrastructure.persistence
            .AnimationSceneVersionRepository sceneVersions;
    private DraftValidator validator;

    @BeforeEach
    void setUp() {
        evidences = mock(EvidenceRepository.class);
        assets = mock(AssetRepository.class);
        List<ActivityConfigValidator> impls = List.of(
                new MultipleChoiceValidator(),
                new SimpleActivityValidators.ReadValidator(),
                new SimpleActivityValidators.ViewImageValidator(),
                new SimpleActivityValidators.ExploreMapValidator(),
                new SimpleActivityValidators.ReflectionPromptValidator(),
                new SimpleActivityValidators.HypothesisChoiceValidator(),
                new SimpleActivityValidators.VerificationValidator(),
                new SimpleActivityValidators.EvidenceSelectValidator(),
                new SimpleActivityValidators.CerValidator(),
                new SimpleActivityValidators.ReasoningConnectValidator(),
                new SimpleActivityValidators.MatchingValidator(),
                new SimpleActivityValidators.DragOrderValidator(),
                new com.dauviet.lesson.draft.validators.CerChoiceValidator());
        sceneVersions = mock(com.dauviet.animation.infrastructure.persistence
                .AnimationSceneVersionRepository.class);
        validator = new DraftValidator(impls, evidences, assets, sceneVersions);
    }

    private JsonNode tree(String json) throws Exception {
        return MAPPER.readTree(json);
    }

    private Set<String> codes(List<FieldError> errors) {
        return errors.stream().map(FieldError::code).collect(Collectors.toSet());
    }

    private void usableEvidence(String... ids) {
        List<UUID> uuids = java.util.Arrays.stream(ids)
                .map(UUID::fromString).toList();
        when(evidences.findIdsByEventIdAndStatusIn(any(), anyCollection()))
                .thenReturn(uuids);
        when(assets.findActiveIds()).thenReturn(List.of());
    }

    /**
     * Wraps a CER_CHOICE config inside a publishable two-stage draft:
     * CONTEXT(READ required) -> CONCLUSION(cer required) so the graph has
     * an entry + reachable terminal and a required non-READ activity.
     * `feedback` lives at activity level (not inside config).
     */
    private String draftBody(String activityConfig) {
        return draftBody(activityConfig, null);
    }

    private String draftBody(String activityConfig, String feedbackJson) {
        String fb = feedbackJson == null ? "" : ",\"feedback\":" + feedbackJson;
        return """
                {"schemaVersion":1,
                 "stages":[{"id":"ctx","type":"CONTEXT","required":true,
                            "activities":[{"id":"r1","type":"READ","required":true,
                                           "config":{"text":"intro"}}],
                            "nextStageIds":["cc"]},
                           {"id":"cc","type":"CONCLUSION","required":true,
                            "activities":[{"id":"cer","type":"CER_CHOICE","required":true%s,
                                           "config":%s}],
                            "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(fb, activityConfig);
    }

    /* ---------- SAVE level ---------- */

    @Test
    void saveLevel_toleratesMissingKeys() throws Exception {
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}]}"));
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
    }

    @Test
    void saveLevel_rejectsMissingOptionLists() throws Exception {
        JsonNode draft = tree(draftBody("{}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.SAVE)))
                .contains("INVALID_CONFIG");
    }

    @Test
    void saveLevel_rejectsBadPriorEvidenceSource() throws Exception {
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"priorEvidenceSource\":\"NOT-A-VALID-ID!\"}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.SAVE)))
                .contains("INVALID_ID");
    }

    @Test
    void saveLevel_rejectsBadIntBounds() throws Exception {
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"minCorrect\":0,\"maxAttempts\":200}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.SAVE)))
                .contains("INVALID_VALUE");
    }

    /* ---------- PUBLISH level ---------- */

    @Test
    void publishLevel_requiresAnswerKeys() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"" + ev + "\"}]}"));
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).contains("MISSING_FIELD");
    }

    @Test
    void publishLevel_rejectsAcceptedSubsetViolation() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"" + ev + "\"}],"
              + "\"acceptedClaims\":[\"c9\"],"
              + "\"acceptedEvidenceIds\":[\"" + ev + "\"],"
              + "\"acceptedReasoningIds\":[\"r9\"]}",
                "{\"COMPLETED\":\"ok\",\"INCORRECT\":\"no\"}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("INVALID_CONFIG");
    }

    @Test
    void publishLevel_rejectsMissingEvidenceKey() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"acceptedClaims\":[\"c1\"],"
              + "\"acceptedReasoningIds\":[\"r1\"]}",
                "{\"COMPLETED\":\"ok\",\"INCORRECT\":\"no\"}"));
        // absent acceptedEvidenceIds surfaces as INVALID_CONFIG (requireNonEmptyArray)
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("INVALID_CONFIG");
    }

    @Test
    void publishLevel_rejectsMissingFeedback() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"" + ev + "\"}],"
              + "\"acceptedCombos\":[{\"claimId\":\"c1\","
              + "\"evidenceIds\":[\"" + ev + "\"],\"reasoningId\":\"r1\"}]}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("MISSING_FIELD");
    }

    @Test
    void publishLevel_acceptsCombosConfig() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"" + ev + "\"}],"
              + "\"acceptedCombos\":[{\"claimId\":\"c1\","
              + "\"evidenceIds\":[\"" + ev + "\"],\"reasoningId\":\"r1\"}],"
              + "\"maxAttempts\":3}",
                "{\"COMPLETED\":\"ok\",\"INCORRECT\":\"no\"}"));
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)).isEmpty();
    }

    @Test
    void publishLevel_acceptsLegacyFlatKeys() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"" + ev + "\"}],"
              + "\"acceptedClaims\":[\"c1\"],"
              + "\"acceptedEvidenceIds\":[\"" + ev + "\"],"
              + "\"acceptedReasoningIds\":[\"r1\"],"
              + "\"maxAttempts\":3}",
                "{\"COMPLETED\":\"ok\",\"INCORRECT\":\"no\"}"));
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)).isEmpty();
    }

    @Test
    void publishLevel_rejectsComboBadRefs() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"" + ev + "\"}],"
              + "\"acceptedCombos\":[{\"claimId\":\"c9\","
              + "\"evidenceIds\":[\"" + ev + "\"],\"reasoningId\":\"r9\"}]}",
                "{\"COMPLETED\":\"ok\",\"INCORRECT\":\"no\"}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("INVALID_CONFIG");
    }

    @Test
    void publishLevel_rejectsMinCorrect() throws Exception {
        // TASK-0020 §P4: minCorrect used to promote partial picks to full
        // credit — retired; new drafts cannot reintroduce the promotion.
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(draftBody(
                "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"" + ev + "\"}],"
              + "\"acceptedCombos\":[{\"claimId\":\"c1\","
              + "\"evidenceIds\":[\"" + ev + "\"],\"reasoningId\":\"r1\"}],"
              + "\"minCorrect\":2}",
                "{\"COMPLETED\":\"ok\",\"INCORRECT\":\"no\"}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("INVALID_CONFIG");
    }

    /* ---------- graded EVIDENCE_SELECT ---------- */

    private String evidenceSelectDraft(String config) {
        return """
                {"schemaVersion":1,
                 "stages":[{"id":"ev","type":"EVIDENCE","required":true,
                            "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                           "config":%s}],
                            "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(config);
    }

    @Test
    void evidenceSelect_graded_requiresAcceptedEvidenceIds() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(evidenceSelectDraft(
                "{\"graded\":true,\"visibleEvidenceIds\":[\"" + ev + "\"]}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("MISSING_FIELD");
    }

    @Test
    void evidenceSelect_graded_rejectsAcceptedNotSubset() throws Exception {
        String ev = UUID.randomUUID().toString();
        String other = UUID.randomUUID().toString();
        usableEvidence(ev, other);
        JsonNode draft = tree(evidenceSelectDraft(
                "{\"graded\":true,\"visibleEvidenceIds\":[\"" + ev + "\"],"
              + "\"acceptedEvidenceIds\":[\"" + other + "\"]}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("INVALID_CONFIG");
    }

    @Test
    void evidenceSelect_graded_acceptsValid() throws Exception {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree(evidenceSelectDraft(
                "{\"graded\":true,\"visibleEvidenceIds\":[\"" + ev + "\"],"
              + "\"acceptedEvidenceIds\":[\"" + ev + "\"],"
              + "\"maxAttempts\":2}"));
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)).isEmpty();
    }

    /* ---------- graded REASONING_CONNECT ---------- */

    private String reasoningDraft(String config) {
        return """
                {"schemaVersion":1,
                 "stages":[{"id":"rs","type":"REASONING","required":true,
                            "activities":[{"id":"rc","type":"REASONING_CONNECT","required":true,
                                           "config":%s}],
                            "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(config);
    }

    @Test
    void reasoning_graded_requiresExpectedOrAccepted() throws Exception {
        JsonNode draft = tree(reasoningDraft(
                "{\"graded\":true,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"}],"
              + "\"allowedRelations\":[\"causes\"]}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("MISSING_FIELD");
    }

    @Test
    void reasoning_graded_rejectsBadRelationReferences() throws Exception {
        JsonNode draft = tree(reasoningDraft(
                "{\"graded\":true,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"}],"
              + "\"allowedRelations\":[\"causes\"],"
              + "\"expectedRelations\":[{\"from\":\"n1\",\"to\":\"n9\",\"relation\":\"causes\"}]}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("INVALID_CONFIG");
    }

    @Test
    void reasoning_graded_rejectsDisallowedRelationName() throws Exception {
        JsonNode draft = tree(reasoningDraft(
                "{\"graded\":true,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"}],"
              + "\"allowedRelations\":[\"causes\"],"
              + "\"expectedRelations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"likes\"}]}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("INVALID_CONFIG");
    }

    @Test
    void reasoning_graded_acceptsValid() throws Exception {
        JsonNode draft = tree(reasoningDraft(
                "{\"graded\":true,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"}],"
              + "\"allowedRelations\":[\"causes\"],"
              + "\"expectedRelations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}],"
              + "\"acceptedRelationSets\":[[{\"from\":\"n2\",\"to\":\"n1\",\"relation\":\"causes\"}]]}"));
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)).isEmpty();
    }

    /* ---------- cross-activity source refs (TASK-0020 §P0/§P5) ---------- */

    /**
     * EVIDENCE -> VERIFICATION chain with vf1.config.evidenceSource pointing
     * at the upstream EVIDENCE_SELECT `es`.
     */
    private String verificationChainDraft(String vfConfig) {
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        return """
                {"schemaVersion":1,
                 "stages":[{"id":"ev","type":"EVIDENCE","required":true,
                            "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                           "config":{"visibleEvidenceIds":["%s"]}}],
                            "nextStageIds":["vf"]},
                           {"id":"vf","type":"VERIFICATION","required":true,
                            "activities":[{"id":"vf1","type":"VERIFICATION","required":true,
                                           "config":%s}],
                            "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(ev, vfConfig);
    }

    @Test
    void sourceRef_validUpstreamSelect_accepted() throws Exception {
        JsonNode draft = tree(verificationChainDraft(
                "{\"requiredEvidenceIds\":[],\"evidenceSource\":\"es\"}"));
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)).isEmpty();
    }

    @Test
    void sourceRef_unknownActivity_rejectedAtPublish() throws Exception {
        JsonNode draft = tree(verificationChainDraft(
                "{\"evidenceSource\":\"ghost\"}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("UNKNOWN_ACTIVITY_ID");
    }

    @Test
    void sourceRef_unknownActivity_toleratedAtSave() throws Exception {
        JsonNode draft = tree(verificationChainDraft(
                "{\"evidenceSource\":\"ghost\"}"));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.SAVE)))
                .doesNotContain("UNKNOWN_ACTIVITY_ID");
    }

    @Test
    void sourceRef_wrongType_rejected() throws Exception {
        // priorEvidenceSource pointing at a READ — only EVIDENCE_SELECT
        // produces selectable evidence output.
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree("""
                {"schemaVersion":1,
                 "stages":[{"id":"ctx","type":"CONTEXT","required":true,
                            "activities":[{"id":"rd","type":"READ","required":true,
                                           "config":{"text":"t"}}],
                            "nextStageIds":["cc"]},
                           {"id":"cc","type":"CONCLUSION","required":true,
                            "activities":[{"id":"cer","type":"CER_CHOICE","required":true,
                                           "config":{"claims":[{"id":"c1"},{"id":"c2"}],
                                                     "reasoningOptions":[{"id":"r1"},{"id":"r2"}],
                                                     "evidenceOptions":[{"id":"%s"}],
                                                     "priorEvidenceSource":"rd",
                                                     "acceptedCombos":[{"claimId":"c1",
                                                       "evidenceIds":["%s"],"reasoningId":"r1"}]},
                                           "feedback":{"COMPLETED":"ok","INCORRECT":"no"}}],
                            "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(ev, ev));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("INVALID_CONFIG");
    }

    @Test
    void sourceRef_unreachableStage_rejected() throws Exception {
        // Source lives on a dead branch: es sits in a stage that can never
        // execute before cc — the consumer could never see its output.
        String ev = UUID.randomUUID().toString();
        usableEvidence(ev);
        JsonNode draft = tree("""
                {"schemaVersion":1,
                 "stages":[{"id":"ctx","type":"CONTEXT","required":true,
                            "activities":[{"id":"rd","type":"READ","required":true,
                                           "config":{"text":"t"}}],
                            "nextStageIds":["cc"]},
                           {"id":"dead","type":"EVIDENCE","required":false,
                            "activities":[{"id":"es","type":"EVIDENCE_SELECT",
                                           "config":{"visibleEvidenceIds":["%s"]}}],
                            "nextStageIds":[]},
                           {"id":"cc","type":"CONCLUSION","required":true,
                            "activities":[{"id":"cer","type":"CER_CHOICE","required":true,
                                           "config":{"claims":[{"id":"c1"},{"id":"c2"}],
                                                     "reasoningOptions":[{"id":"r1"},{"id":"r2"}],
                                                     "evidenceOptions":[{"id":"%s"}],
                                                     "priorEvidenceSource":"es",
                                                     "acceptedCombos":[{"claimId":"c1",
                                                       "evidenceIds":["%s"],"reasoningId":"r1"}]},
                                           "feedback":{"COMPLETED":"ok","INCORRECT":"no"}}],
                            "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(ev, ev, ev));
        assertThat(codes(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)))
                .contains("UNREACHABLE_SOURCE");
    }

    /* ---------- fixture validation (phase-07 AC-9) ---------- */

    /**
     * Replaces every ${EVn} placeholder with a fresh UUID that the mocked
     * evidence repository reports as usable — validates fixture shape +
     * hidden-key-free authoring without a live DB.
     */
    private String fillFixture(String resource) throws Exception {
        String json = new String(getClass().getResourceAsStream(resource)
                .readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
        java.util.Set<String> evIds = new java.util.LinkedHashSet<>();
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("\\$\\{EV(\\d+)\\}").matcher(json);
        while (m.find()) evIds.add(m.group(1));
        java.util.Map<String, String> uuids = new java.util.HashMap<>();
        for (String n : evIds) uuids.put(n, UUID.randomUUID().toString());
        usableAllEvidence(uuids.values());
        String resolved = json;
        for (var e : uuids.entrySet()) {
            resolved = resolved.replace("${EV" + e.getKey() + "}", e.getValue());
        }
        return resolved;
    }

    private void usableAllEvidence(java.util.Collection<String> ids) {
        List<UUID> uuids = ids.stream().map(UUID::fromString).toList();
        when(evidences.findIdsByEventIdAndStatusIn(any(), anyCollection()))
                .thenReturn(uuids);
        when(assets.findActiveIds()).thenReturn(List.of());
    }

    @Test
    void bachDangV2Fixture_publishValid() throws Exception {
        JsonNode draft = tree(fillFixture("/lessons/bach-dang-938-v2.draft.json"));
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)).isEmpty();
    }

    @Test
    void haiBaTrungFixture_publishValid() throws Exception {
        JsonNode draft = tree(fillFixture("/lessons/hai-ba-trung-40.draft.json"));
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)).isEmpty();
    }
}
