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

/** Pure unit tests for draft validation — repositories mocked, no DB. */
class DraftValidatorTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final UUID EVENT = UUID.randomUUID();

    private EvidenceRepository evidences;
    private AssetRepository assets;
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
                new SimpleActivityValidators.DragOrderValidator());
        validator = new DraftValidator(impls, evidences, assets);
    }

    private JsonNode tree(String json) throws Exception {
        return MAPPER.readTree(json);
    }

    private Set<String> codes(List<FieldError> errors) {
        return errors.stream().map(FieldError::code).collect(Collectors.toSet());
    }

    @Test
    void saveLevel_toleratesIncompleteDraft() throws Exception {
        // Missing config entirely is fine at SAVE (author still typing).
        JsonNode draft = tree("""
                {"schemaVersion":1,
                 "stages":[{"id":"s1","type":"CONTEXT",
                            "activities":[{"id":"a1","type":"READ"}],
                            "nextStageIds":[]}]}
                """);
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
    }

    @Test
    void saveLevel_rejectsBadStructure() throws Exception {
        JsonNode draft = tree("""
                {"schemaVersion":2,"unknown":true,
                 "stages":[{"id":"BAD ID!","type":"NOPE"}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).contains(
                "UNSUPPORTED_SCHEMA_VERSION", "UNKNOWN_FIELD",
                "INVALID_ID", "UNKNOWN_STAGE_TYPE");
    }

    @Test
    void saveLevel_detectsCyclesAndUnknownTargets() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb"]},
                           {"id":"sb","type":"DISCOVERY","nextStageIds":["sa","ghost"]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).contains("CIRCULAR_TRANSITION", "UNKNOWN_STAGE_ID");
    }

    @Test
    void publishLevel_requiresStageAndConfig() throws Exception {
        // EVIDENCE_SELECT with no visibleEvidenceIds -> config error at PUBLISH
        // AND at SAVE (required-structure checks run at both levels).
        JsonNode draft = tree("""
                {"stages":[{"id":"ev","type":"EVIDENCE","required":true,
                            "activities":[{"id":"xa","type":"EVIDENCE_SELECT","required":true}],
                            "nextStageIds":[]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).contains("INVALID_CONFIG");
    }

    @Test
    void publishLevel_checksEvidenceRefsAgainstDb() throws Exception {
        UUID usable = UUID.randomUUID();
        UUID missing = UUID.randomUUID();
        // Publish-level context resolves evidence ids via findIdsByEventIdAndStatusIn —
        // only `usable` comes back so the other ref is unusable.
        when(evidences.findIdsByEventIdAndStatusIn(any(), anyCollection()))
                .thenReturn(List.of(usable));
        when(assets.findActiveIds()).thenReturn(List.of());

        JsonNode draft = tree("""
                {"stages":[{"id":"ev","type":"EVIDENCE","required":true,
                            "requiredEvidenceIds":["%s","%s"],
                            "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                           "config":{"visibleEvidenceIds":["%s"]}}],
                            "nextStageIds":[]}]}
                """.formatted(usable, missing, usable));
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        // The missing stage-level ref is the only failure.
        assertThat(errors).hasSize(1);
        assertThat(errors.get(0).code()).isEqualTo("EVIDENCE_NOT_FOUND");
        assertThat(errors.get(0).path()).contains("requiredEvidenceIds[1]");
    }

    @Test
    void publishLevel_missingTerminalStage_flagged() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb"]},
                           {"id":"sb","type":"DISCOVERY","nextStageIds":[]},
                           {"id":"sc","type":"REASONING","nextStageIds":["sc"]}]}
                """);
        // sb is terminal so NO_TERMINAL_STAGE must NOT fire even with the sc self-loop
        // (self-loop itself is caught separately by CIRCULAR_TRANSITION).
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).doesNotContain("NO_TERMINAL_STAGE");
        // Now remove terminal: sa->sb, sb->sa (a cycle, but also no terminal)
        JsonNode cyc = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb"]},
                           {"id":"sb","type":"DISCOVERY","nextStageIds":["sa"]}]}
                """);
        List<FieldError> errs = validator.validate(cyc, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errs)).contains("NO_TERMINAL_STAGE");
    }

    @Test
    void publishLevel_requiresInteractiveRequiredActivity() throws Exception {
        // All-READ draft → NO_REQUIRED_ACTIVITY at PUBLISH even though stages exist.
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","required":true,
                            "activities":[{"id":"r1","type":"READ","required":true}],
                            "nextStageIds":[]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).contains("NO_REQUIRED_ACTIVITY");
    }

    @Test
    void publishLevel_requireAllRequiredStagesWithoutRequired_flagged() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","required":true,
                            "activities":[{"id":"r1","type":"READ","required":false,
                                           "config":{"text":"x"}},
                                          {"id":"ev","type":"MULTIPLE_CHOICE","required":true,
                                           "config":{"question":"q","options":[{"id":"o1"},{"id":"o2"}],
                                                     "correctOptionIds":["o1"]}}],
                            "nextStageIds":[]},
                           {"id":"sb","type":"DISCOVERY","required":false,"nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """);
        // sa IS required and has a required non-READ activity → NO_REQUIRED_ACTIVITY won't fire,
        // but requireAllRequiredStages still fine because hasRequiredStage=true.
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).doesNotContain("INVALID_CONFIG");

        // No required stage at all + requireAllRequiredStages → flagged
        JsonNode noReq = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","required":false,
                            "activities":[{"id":"r1","type":"READ","required":true}],
                            "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """);
        List<FieldError> errs = validator.validate(noReq, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errs)).contains("INVALID_CONFIG");
    }

    @Test
    void stageActivityMismatch_flagged() throws Exception {
        // HYPOTHESIS_CHOICE inside an EVIDENCE stage is not allowed
        JsonNode draft = tree("""
                {"stages":[{"id":"ev","type":"EVIDENCE",
                            "activities":[{"id":"ha","type":"HYPOTHESIS_CHOICE"}]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).contains("STAGE_ACTIVITY_MISMATCH");
    }

    @Test
    void multipleChoice_publishNeedsAnswerKey() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"rs","type":"REASONING","required":true,
                            "activities":[{"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                                           "config":{"question":"Q?",
                                                     "options":[{"id":"o1"},{"id":"o2"}]}}],
                            "nextStageIds":[]}]}
                """);
        // No correctOptionIds/multiCorrect: SAVE ok, PUBLISH flags MISSING_FIELD.
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).contains("MISSING_FIELD");
    }

    @Test
    void completion_requiredStageIds_checked() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"sc","type":"CONTEXT"}],
                 "completion":{"requiredStageIds":["sc","ghost"]}}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).contains("UNKNOWN_STAGE_ID");
    }
}
