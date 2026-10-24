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
                new SimpleActivityValidators.DragOrderValidator());
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

    /* ---------- stage graph: no false-positive cycles ---------- */

    @Test
    void graph_linearPath_noCycle() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb"]},
                           {"id":"sb","type":"DISCOVERY","nextStageIds":["sc"]},
                           {"id":"sc","type":"CONCLUSION","nextStageIds":[]}]}
                """);
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
    }

    @Test
    void graph_branchingSharedDestination_noCycle() throws Exception {
        // sa -> sb and sa -> sc, both converge on sd. Not a cycle.
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb","sc"]},
                           {"id":"sb","type":"DISCOVERY","nextStageIds":["sd"]},
                           {"id":"sc","type":"EVIDENCE","nextStageIds":["sd"]},
                           {"id":"sd","type":"CONCLUSION","nextStageIds":[]}]}
                """);
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
    }

    @Test
    void graph_diamondDag_noCycle() throws Exception {
        // Classic diamond: sa -> {sb, sc} -> sd. Revisit of sd is via BLACK node.
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb","sc"]},
                           {"id":"sb","type":"DISCOVERY","nextStageIds":["sd"]},
                           {"id":"sc","type":"REASONING","nextStageIds":["sd"]},
                           {"id":"sd","type":"CONCLUSION","nextStageIds":[]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).doesNotContain("CIRCULAR_TRANSITION");
    }

    @Test
    void graph_selfLoop_flagged() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sa"]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).contains("CIRCULAR_TRANSITION");
    }

    @Test
    void graph_multiStageCycle_flagged() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb"]},
                           {"id":"sb","type":"DISCOVERY","nextStageIds":["sc"]},
                           {"id":"sc","type":"REASONING","nextStageIds":["sd"]},
                           {"id":"sd","type":"VERIFICATION","nextStageIds":["sb"]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).contains("CIRCULAR_TRANSITION");
    }

    @Test
    void graph_disconnectedCycleInSecondComponent_flagged() throws Exception {
        // Component 1 is a clean DAG; component 2 loops. DFS outer loop must
        // still walk the second component and find the cycle.
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb"]},
                           {"id":"sb","type":"CONCLUSION","nextStageIds":[]},
                           {"id":"xa","type":"EVIDENCE","nextStageIds":["xb"]},
                           {"id":"xb","type":"REASONING","nextStageIds":["xa"]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).contains("CIRCULAR_TRANSITION");
    }

    @Test
    void graph_disconnectedDagComponents_noCycle() throws Exception {
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb"]},
                           {"id":"sb","type":"CONCLUSION","nextStageIds":[]},
                           {"id":"xa","type":"EVIDENCE","nextStageIds":["xb"]},
                           {"id":"xb","type":"REASONING","nextStageIds":[]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(codes(errors)).doesNotContain("CIRCULAR_TRANSITION");
    }

    /* ---------- publish level: schemaVersion + reachable terminal ---------- */

    @Test
    void publishLevel_missingSchemaVersion_flagged() throws Exception {
        // Structurally complete draft minus schemaVersion: SAVE ok, PUBLISH rejects.
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"REASONING","required":true,
                            "activities":[{"id":"r1","type":"READ","required":false,
                                           "config":{"text":"x"}},
                                          {"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                                           "config":{"question":"q","options":[{"id":"o1"},{"id":"o2"}],
                                                     "correctOptionIds":["o1"]}}],
                            "nextStageIds":[]}]}
                """);
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(errors.stream().filter(e -> e.path().equals("schemaVersion"))
                .map(FieldError::code)).contains("MISSING_FIELD");
    }

    @Test
    void publishLevel_wrongSchemaVersion_flagged() throws Exception {
        JsonNode draft = tree("""
                {"schemaVersion":2,
                 "stages":[{"id":"sa","type":"CONTEXT","nextStageIds":[]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).contains("UNSUPPORTED_SCHEMA_VERSION");
    }

    @Test
    void publishLevel_terminalMustBeReachableFromEntry() throws Exception {
        // Entry sa loops with sb (no escape); sd is terminal but unreachable.
        // Cycle is caught by CIRCULAR_TRANSITION; terminal check must also fire
        // because no terminal is reachable FROM the entry stage.
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"CONTEXT","nextStageIds":["sb"]},
                           {"id":"sb","type":"DISCOVERY","nextStageIds":["sa"]},
                           {"id":"sd","type":"CONCLUSION","nextStageIds":[]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).contains("NO_TERMINAL_STAGE");
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
                {"schemaVersion":1,
                 "stages":[{"id":"ev","type":"EVIDENCE","required":true,
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
        // sb is terminal AND reachable from entry sa, so NO_TERMINAL_STAGE must
        // NOT fire even though the unreachable sc self-loops (that loop itself
        // is still reported as CIRCULAR_TRANSITION).
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(codes(errors)).doesNotContain("NO_TERMINAL_STAGE");
        assertThat(codes(errors)).contains("CIRCULAR_TRANSITION");
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

    @Test
    void completion_emptyObject_rejectedAtPublish_toleratedAtSave() throws Exception {
        // Runtime treats `completion:{}` as DEFAULT_ALL_REQUIRED (absent
        // config), so publishing it is a no-op or a mistake — rejected at
        // PUBLISH; SAVE stays tolerant while the author is still composing.
        JsonNode draft = tree("""
                {"stages":[{"id":"sa","type":"EVIDENCE","required":true,
                            "activities":[{"id":"ev","type":"MULTIPLE_CHOICE","required":true,
                                           "config":{"question":"q","options":[{"id":"o1"},{"id":"o2"}],
                                                     "correctOptionIds":["o1"]}}],
                            "nextStageIds":[]}],
                 "completion":{}}
                """);
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(errors).anyMatch(e -> e.code().equals("EMPTY_COMPLETION")
                && e.path().equals("completion"));
    }

    @Test
    void requiredActivityInOptionalStage_rejectedAtPublish() throws Exception {
        // required:true inside a required:false stage can never gate
        // progress/completion (stage flag wins) — contradictory authoring,
        // rejected at PUBLISH, tolerated at SAVE.
        JsonNode draft = tree("""
                {"schemaVersion":1,
                 "stages":[
                  {"id":"sa","type":"EVIDENCE","required":true,
                   "activities":[{"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                                   "config":{"question":"q","options":[{"id":"o1"},{"id":"o2"}],
                                             "correctOptionIds":["o1"]}}],
                   "nextStageIds":["ref"]},
                  {"id":"ref","type":"REFLECTION","required":false,
                   "activities":[{"id":"c1","type":"READ","required":true,
                                   "config":{"text":"x"}}],
                   "nextStageIds":[]}]}
                """);
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(errors).anyMatch(e -> e.code().equals("REQUIRED_IN_OPTIONAL_STAGE")
                && e.path().equals("stages[id=ref].activities[0].required"));
    }

    @Test
    void optionalStage_fullyOptional_publishesFine() throws Exception {
        // Same shape without the contradictory flag -> publishes clean:
        // optional stage carries only optional activities.
        JsonNode draft = tree("""
                {"schemaVersion":1,
                 "stages":[
                  {"id":"sa","type":"EVIDENCE","required":true,
                   "activities":[{"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                                   "config":{"question":"q","options":[{"id":"o1"},{"id":"o2"}],
                                             "correctOptionIds":["o1"]}}],
                   "nextStageIds":["ref"]},
                  {"id":"ref","type":"REFLECTION","required":false,
                   "activities":[{"id":"c1","type":"READ",
                                   "config":{"text":"x"}}],
                   "nextStageIds":[]}]}
                """);
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH)).isEmpty();
    }

    /* ---------- ANIM-01: READ config.animationKey ---------- */

    private JsonNode readDraft(String config) throws Exception {
        return tree("""
                {"stages":[{"id":"s1","type":"CONTEXT",
                            "activities":[{"id":"r1","type":"READ","config":%s}],
                            "nextStageIds":[]}]}
                """.formatted(config));
    }

    @Test
    void read_validAnimationKey_accepted() throws Exception {
        JsonNode draft = readDraft(
                "{\"text\":\"x\",\"animationKey\":\"bach_dang_938_tide_v1\"}");
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
        // PUBLISH-level: no error may point at animationKey (other draft-level
        // rules like schemaVersion/NO_REQUIRED_ACTIVITY are out of scope here).
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH))
                .noneMatch(e -> e.path().endsWith("config.animationKey"));
    }

    @Test
    void read_missingAnimationKey_accepted() throws Exception {
        // animationKey is optional — plain READ stays untouched.
        JsonNode draft = readDraft("{\"text\":\"x\"}");
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE)).isEmpty();
        assertThat(validator.validate(draft, EVENT, ValidationLevel.PUBLISH))
                .noneMatch(e -> e.path().endsWith("config.animationKey"));
    }

    @Test
    void read_nonTextualAnimationKey_rejected() throws Exception {
        JsonNode draft = readDraft("{\"text\":\"x\",\"animationKey\":42}");
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_TYPE")
                && e.path().endsWith("config.animationKey"));
    }

    @Test
    void read_blankOrUnsafeAnimationKey_rejected() throws Exception {
        for (String bad : new String[] {"", "   ", "Bach_Dang", "bach dang",
                "bach-dang", "bach_dang.js", "../etc", "bach__dang"}) {
            JsonNode draft = readDraft(
                    "{\"text\":\"x\",\"animationKey\":\"%s\"}".formatted(bad));
            List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
            assertThat(errors)
                    .as("animationKey '%s' should be rejected", bad)
                    .anyMatch(e -> e.code().equals("INVALID_ID")
                            && e.path().endsWith("config.animationKey"));
        }
    }

    @Test
    void read_oversizedAnimationKey_rejected() throws Exception {
        // 90 chars of valid characters but beyond the 80-char bound.
        String longKey = "a".repeat(89) + "_b";
        JsonNode draft = readDraft(
                "{\"text\":\"x\",\"animationKey\":\"%s\"}".formatted(longKey));
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_ID")
                && e.path().endsWith("config.animationKey"));
    }

    /* ---------- ANIM-02: READ config.animationSceneId/VersionId ---------- */

    private JsonNode readPublishableDraft(String config) throws Exception {
        // A PUBLISH-clean draft: required stage with a required non-READ
        // activity, plus the READ carrying the animation config under test.
        return tree("""
                {"schemaVersion":1,
                 "stages":[{"id":"s1","type":"CONTEXT","required":true,
                            "activities":[{"id":"r1","type":"READ","config":%s},
                                          {"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                                           "config":{"question":"q",
                                                     "options":[{"id":"o1"},{"id":"o2"}],
                                                     "correctOptionIds":["o1"]}}],
                            "nextStageIds":[]}]}
                """.formatted(config));
    }

    @Test
    void read_sceneVersionIdNotUsable_flaggedAtPublish() throws Exception {
        UUID missingVersion = UUID.randomUUID();
        when(sceneVersions.findIdAndSceneId()).thenReturn(List.of());
        when(sceneVersions.findDistinctSceneIds()).thenReturn(List.of());
        JsonNode draft = readPublishableDraft(
                "{\"text\":\"x\",\"animationSceneVersionId\":\"%s\"}"
                        .formatted(missingVersion));
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(errors).anyMatch(e ->
                e.code().equals("ANIMATION_SCENE_VERSION_NOT_FOUND")
                        && e.path().endsWith("config.animationSceneVersionId"));
    }

    @Test
    void read_sceneVersionPinnedToOtherScene_mismatch() throws Exception {
        UUID sceneA = UUID.randomUUID();
        UUID sceneB = UUID.randomUUID();
        UUID versionOfB = UUID.randomUUID();
        when(sceneVersions.findIdAndSceneId())
                .thenReturn(List.<Object[]>of(new Object[]{versionOfB, sceneB}));
        when(sceneVersions.findDistinctSceneIds()).thenReturn(List.of(sceneA, sceneB));
        JsonNode draft = readPublishableDraft(
                ("{\"text\":\"x\",\"animationSceneId\":\"%s\","
                        + "\"animationSceneVersionId\":\"%s\"}")
                        .formatted(sceneA, versionOfB));
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(errors).anyMatch(e ->
                e.code().equals("ANIMATION_SCENE_VERSION_MISMATCH")
                        && e.path().endsWith("config.animationSceneVersionId"));
    }

    @Test
    void read_sceneVersionPinnedToSameScene_accepted() throws Exception {
        UUID sceneA = UUID.randomUUID();
        UUID versionOfA = UUID.randomUUID();
        when(sceneVersions.findIdAndSceneId())
                .thenReturn(List.<Object[]>of(new Object[]{versionOfA, sceneA}));
        when(sceneVersions.findDistinctSceneIds()).thenReturn(List.of(sceneA));
        JsonNode draft = readPublishableDraft(
                ("{\"text\":\"x\",\"animationSceneId\":\"%s\","
                        + "\"animationSceneVersionId\":\"%s\"}")
                        .formatted(sceneA, versionOfA));
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(errors).noneMatch(e -> e.path().contains("animationScene"));
    }

    @Test
    void read_sceneIdWithoutVersion_requiresPublishedScene() throws Exception {
        UUID sceneA = UUID.randomUUID();
        // sceneA has no published version -> ANIMATION_SCENE_NOT_PUBLISHED.
        when(sceneVersions.findIdAndSceneId()).thenReturn(List.of());
        when(sceneVersions.findDistinctSceneIds()).thenReturn(List.of());
        JsonNode draft = readPublishableDraft(
                "{\"text\":\"x\",\"animationSceneId\":\"%s\"}".formatted(sceneA));
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(errors).anyMatch(e ->
                e.code().equals("ANIMATION_SCENE_NOT_PUBLISHED")
                        && e.path().endsWith("config.animationSceneId"));

        // With a published version the scene ref alone is fine.
        when(sceneVersions.findDistinctSceneIds()).thenReturn(List.of(sceneA));
        List<FieldError> ok = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(ok).noneMatch(e -> e.path().contains("animationScene"));
    }

    @Test
    void read_animationKeyPlusSceneRef_mutuallyExclusive() throws Exception {
        UUID sceneA = UUID.randomUUID();
        when(sceneVersions.findIdAndSceneId()).thenReturn(List.of());
        when(sceneVersions.findDistinctSceneIds()).thenReturn(List.of(sceneA));
        JsonNode draft = readPublishableDraft(
                ("{\"text\":\"x\",\"animationKey\":\"bach_dang_938_tide_v1\","
                        + "\"animationSceneId\":\"%s\"}").formatted(sceneA));
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.PUBLISH);
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_CONFIG")
                && e.path().endsWith("config"));
    }

    @Test
    void read_playbackModeWhitelist() throws Exception {
        JsonNode draft = readDraft(
                "{\"text\":\"x\",\"playbackMode\":\"SMOOTH\"}");
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_VALUE")
                && e.path().endsWith("config.playbackMode"));
        for (String mode : new String[]{"AUTO", "STEPPED", "INTERACTIVE"}) {
            JsonNode ok = readDraft(
                    "{\"text\":\"x\",\"playbackMode\":\"%s\"}".formatted(mode));
            assertThat(validator.validate(ok, EVENT, ValidationLevel.SAVE))
                    .noneMatch(e -> e.path().endsWith("config.playbackMode"));
        }
    }

    @Test
    void read_sceneRefIdsNotUuid_rejected() throws Exception {
        JsonNode draft = readDraft(
                "{\"text\":\"x\",\"animationSceneId\":\"not-a-uuid\","
                        + "\"animationSceneVersionId\":42}");
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_ID")
                && e.path().endsWith("config.animationSceneId"));
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_ID")
                && e.path().endsWith("config.animationSceneVersionId"));
    }

    @Test
    void activityIds_uniqueAcrossStages_notJustPerStage() throws Exception {
        // Same activity id in two different stages — the runtime indexes
        // activities by id alone, so cross-stage collision must be rejected.
        JsonNode draft = tree("""
                {"stages":[
                  {"id":"sa","type":"CONTEXT",
                   "activities":[{"id":"xa","type":"READ"}],
                   "nextStageIds":["sb"]},
                  {"id":"sb","type":"EVIDENCE",
                   "activities":[{"id":"xa","type":"READ"}],
                   "nextStageIds":[]}]}
                """);
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(errors).anyMatch(e -> e.code().equals("DUPLICATE_ID")
                && e.path().equals("stages[1].activities[0].id"));
    }

    /* ---------- TASK-0020 final: bounded retry-budget validation ---------- */

    private JsonNode evidenceSelectDraft(String config) throws Exception {
        return tree("""
                {"stages":[{"id":"ev","type":"EVIDENCE","required":true,
                            "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                           "config":%s}],
                            "nextStageIds":[]}]}
                """.formatted(config));
    }

    private JsonNode verificationDraft(String config) throws Exception {
        return tree("""
                {"stages":[{"id":"ev","type":"EVIDENCE","required":true,
                            "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                           "config":{"visibleEvidenceIds":["e1"]}}],
                            "nextStageIds":["vf"]},
                           {"id":"vf","type":"VERIFICATION","required":true,
                            "activities":[{"id":"v1","type":"VERIFICATION","required":true,
                                           "config":%s}],
                            "nextStageIds":[]}]}
                """.formatted(config));
    }

    @Test
    void evidenceSelect_boundedInt_outOfRange_rejected() throws Exception {
        // TASK-0020 FIX 2: maxAttempts [1,10], remedialAttempts [0,5].
        JsonNode draft = evidenceSelectDraft(
                "{\"visibleEvidenceIds\":[\"e1\"],\"graded\":true,"
                        + "\"acceptedEvidenceIds\":[\"e1\"],"
                        + "\"maxAttempts\":0,\"remedialAttempts\":9}");
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_VALUE")
                && e.path().endsWith("config.maxAttempts"));
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_VALUE")
                && e.path().endsWith("config.remedialAttempts"));

        JsonNode ok = evidenceSelectDraft(
                "{\"visibleEvidenceIds\":[\"e1\"],\"graded\":true,"
                        + "\"acceptedEvidenceIds\":[\"e1\"],"
                        + "\"maxAttempts\":3,\"remedialAttempts\":2}");
        assertThat(validator.validate(ok, EVENT, ValidationLevel.SAVE))
                .noneMatch(e -> e.path().contains("maxAttempts")
                        || e.path().contains("remedialAttempts"));
    }

    @Test
    void evidenceSelect_boundedInt_nonInteger_rejected() throws Exception {
        // "3" textual or 1.5 decimal are not executable budgets.
        JsonNode draft = evidenceSelectDraft(
                "{\"visibleEvidenceIds\":[\"e1\"],\"graded\":true,"
                        + "\"acceptedEvidenceIds\":[\"e1\"],"
                        + "\"maxAttempts\":\"three\",\"remedialAttempts\":1.5}");
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_TYPE")
                && e.path().endsWith("config.maxAttempts"));
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_TYPE")
                && e.path().endsWith("config.remedialAttempts"));
    }

    @Test
    void evidenceSelect_boundedInt_absent_defaultsPreserved() throws Exception {
        // Legacy drafts without the fields validate clean — defaults apply.
        JsonNode draft = evidenceSelectDraft(
                "{\"visibleEvidenceIds\":[\"e1\"],\"graded\":true,"
                        + "\"acceptedEvidenceIds\":[\"e1\"]}");
        assertThat(validator.validate(draft, EVENT, ValidationLevel.SAVE))
                .noneMatch(e -> e.path().contains("maxAttempts")
                        || e.path().contains("remedialAttempts"));
    }

    @Test
    void verification_boundedInt_outOfRange_rejected() throws Exception {
        // TASK-0020 FIX 2: verification maxAttempts [1,20], absent = unbounded.
        JsonNode draft = verificationDraft("{\"maxAttempts\":0}");
        List<FieldError> errors = validator.validate(draft, EVENT, ValidationLevel.SAVE);
        assertThat(errors).anyMatch(e -> e.code().equals("INVALID_VALUE")
                && e.path().endsWith("config.maxAttempts"));

        JsonNode ok = verificationDraft("{\"maxAttempts\":5}");
        assertThat(validator.validate(ok, EVENT, ValidationLevel.SAVE))
                .noneMatch(e -> e.path().contains("maxAttempts"));

        JsonNode absent = verificationDraft("{}");
        assertThat(validator.validate(absent, EVENT, ValidationLevel.SAVE))
                .noneMatch(e -> e.path().contains("maxAttempts"));
    }
}
