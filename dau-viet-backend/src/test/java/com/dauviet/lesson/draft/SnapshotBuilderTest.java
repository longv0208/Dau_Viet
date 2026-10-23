package com.dauviet.lesson.draft;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.dauviet.animation.domain.AnimationSceneVersion;
import com.dauviet.animation.infrastructure.persistence
        .AnimationSceneVersionRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonTemplate;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.dauviet.lesson.infrastructure.persistence.EvidenceRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Unit tests for {@link SnapshotBuilder} — repositories mocked, no DB.
 * FIX-P0: draft.stages is a JSON ARRAY (ArrayNode). The previous code cast
 * {@code draft.path("stages").deepCopy()} to {@link ObjectNode}, which
 * compiled via the generic signature but would throw ClassCastException at
 * publish time for every valid lesson. These tests prove the builder now
 * handles an ArrayNode end-to-end and embeds the animation manifest.
 */
class SnapshotBuilderTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final UUID LESSON_ID = UUID.randomUUID();
    private static final UUID SCENE_VERSION_ID = UUID.randomUUID();
    private static final UUID SCENE_ID = UUID.randomUUID();

    private EvidenceRepository evidences;
    private AssetRepository assets;
    private AnimationSceneVersionRepository sceneVersions;
    private SnapshotBuilder builder;

    @BeforeEach
    void setUp() {
        evidences = mock(EvidenceRepository.class);
        assets = mock(AssetRepository.class);
        sceneVersions = mock(AnimationSceneVersionRepository.class);
        builder = new SnapshotBuilder(evidences, assets, MAPPER, sceneVersions);
        when(evidences.findAllById(org.mockito.ArgumentMatchers.anyCollection()))
                .thenReturn(List.of());
        when(assets.findAllById(org.mockito.ArgumentMatchers.anyCollection()))
                .thenReturn(List.of());
    }

    private Lesson lesson() {
        Lesson l = new Lesson();
        l.setId(LESSON_ID);
        l.setTitle("Trận Bạch Đằng");
        l.setCentralQuestion("Vì sao cọc ngầm thắng thuyền lớn?");
        l.setObjectivesJson("[\"Hiểu thủy triều\"]");
        return l;
    }

    private LessonTemplate template() {
        return LessonTemplate.create(
                UUID.randomUUID(), "HISTORY_INQUIRY", "Sử",
                "Template", 1, "{}");
    }

    /** Manifest tối thiểu được lưu trong animation_scene_versions.snapshot_json. */
    private String sceneSnapshotJson() {
        return """
                {
                  "schemaVersion": 1,
                  "rendererCode": "RIVER_TIDE",
                  "rendererVersion": 1,
                  "title": "Bãi cọc Bạch Đằng",
                  "river": {"stakes": [{"id": "s1", "x": 0.5, "length": 0.2}]},
                  "initialState": {"waterLevel": 0.3},
                  "steps": [
                    {"id": "st1", "title": "Triều lên", "durationMs": 900,
                     "targetState": {"waterLevel": 0.9}}
                  ],
                  "disclaimer": "Minh họa schematic."
                }
                """;
    }

    private AnimationSceneVersion sceneVersion() {
        AnimationSceneVersion v = new AnimationSceneVersion();
        v.setId(SCENE_VERSION_ID);
        v.setSceneId(SCENE_ID);
        v.setVersionNo(2);
        v.setSchemaVersion(1);
        v.setRendererCode("RIVER_TIDE");
        v.setRendererVersion(1);
        v.setSnapshotJson(sceneSnapshotJson());
        return v;
    }

    /** Draft 2-stage hợp lệ: CONTEXT(READ + animationSceneVersionId) → VERIFICATION(MULTIPLE_CHOICE). */
    private JsonNode validDraft() throws Exception {
        String draft = """
                {
                  "schemaVersion": 1,
                  "completion": {"requireAllRequiredStages": true},
                  "stages": [
                    {
                      "id": "ctx", "type": "CONTEXT", "required": true,
                      "nextStageIds": ["verify"],
                      "activities": [
                        {"id": "read1", "type": "READ", "required": false,
                         "config": {
                           "text": "Đọc về trận Bạch Đằng.",
                           "animationSceneVersionId": "%s"
                         }}
                      ]
                    },
                    {
                      "id": "verify", "type": "VERIFICATION", "required": true,
                      "nextStageIds": [],
                      "activities": [
                        {"id": "mc1", "type": "MULTIPLE_CHOICE", "required": true,
                         "config": {
                           "question": "Vì sao thuyền Nguyên mắc cọc?",
                           "options": [
                             {"id": "o1", "label": "Triều rút"},
                             {"id": "o2", "label": "Gió lớn"}
                           ],
                           "correctOptionIds": ["o1"]
                         }}
                      ]
                    }
                  ]
                }
                """.formatted(SCENE_VERSION_ID);
        return MAPPER.readTree(draft);
    }

    @Test
    void build_embedsAnimationManifestIntoReadActivity() throws Exception {
        when(sceneVersions.findById(SCENE_VERSION_ID))
                .thenReturn(Optional.of(sceneVersion()));
        JsonNode draft = validDraft();
        String draftBefore = MAPPER.writeValueAsString(draft);

        ObjectNode snapshot = builder.build(lesson(), draft, template());

        // Snapshot stages vẫn là array, giữ thứ tự.
        JsonNode stages = snapshot.get("stages");
        assertThat(stages).isNotNull();
        assertThat(stages.isArray()).isTrue();
        assertThat(stages).isInstanceOf(ArrayNode.class);
        assertThat(stages).hasSize(2);
        assertThat(stages.get(0).get("id").asText()).isEqualTo("ctx");
        assertThat(stages.get(1).get("id").asText()).isEqualTo("verify");

        // READ activity trong CONTEXT đã được embed animationManifest.
        JsonNode readCfg = stages.get(0).get("activities").get(0).get("config");
        JsonNode anim = readCfg.get("animationManifest");
        assertThat(anim).isNotNull();
        assertThat(anim.get("sceneVersionId").asText())
                .isEqualTo(SCENE_VERSION_ID.toString());
        assertThat(anim.get("versionNo").asInt()).isEqualTo(2);
        assertThat(anim.get("rendererCode").asText()).isEqualTo("RIVER_TIDE");
        assertThat(anim.get("rendererVersion").asInt()).isEqualTo(1);
        assertThat(anim.get("manifest").get("schemaVersion").asInt()).isEqualTo(1);
        assertThat(anim.get("manifest").get("title").asText())
                .isEqualTo("Bãi cọc Bạch Đằng");

        // MULTIPLE_CHOICE trong VERIFICATION không bị đụng vào.
        JsonNode mcCfg = stages.get(1).get("activities").get(0).get("config");
        assertThat(mcCfg.get("animationManifest")).isNull();
        assertThat(mcCfg.get("correctOptionIds").get(0).asText()).isEqualTo("o1");

        // Draft gốc KHÔNG bị mutate (snapshot độc lập immutable).
        assertThat(MAPPER.writeValueAsString(draft)).isEqualTo(draftBefore);

        // completion + schemaVersion của snapshot được copy đúng.
        assertThat(snapshot.get("schemaVersion").asInt())
                .isEqualTo(DraftSchema.CURRENT_VERSION);
        assertThat(snapshot.get("completion").get("requireAllRequiredStages")
                .asBoolean()).isTrue();
    }

    @Test
    void build_resolvesLatestSceneVersion_whenOnlySceneIdGiven() throws Exception {
        // Draft pin bằng animationSceneId (không phải versionId) → builder
        // phải pin CURRENT published version tại publish time.
        AnimationSceneVersion latest = sceneVersion();
        when(sceneVersions.findTopBySceneIdOrderByVersionNoDesc(SCENE_ID))
                .thenReturn(Optional.of(latest));
        when(sceneVersions.findById(SCENE_VERSION_ID))
                .thenReturn(Optional.of(latest));

        String draft = """
                {
                  "schemaVersion": 1,
                  "stages": [
                    {"id": "ctx", "type": "CONTEXT", "required": true,
                     "nextStageIds": [],
                     "activities": [
                       {"id": "r1", "type": "READ", "required": false,
                        "config": {"text": "x", "animationSceneId": "%s"}}
                     ]}
                  ]
                }
                """.formatted(SCENE_ID);
        ObjectNode snapshot = builder.build(lesson(),
                MAPPER.readTree(draft), template());
        JsonNode anim = snapshot.get("stages").get(0).get("activities").get(0)
                .get("config").get("animationManifest");
        assertThat(anim).isNotNull();
        assertThat(anim.get("sceneVersionId").asText())
                .isEqualTo(SCENE_VERSION_ID.toString());
        assertThat(anim.get("versionNo").asInt()).isEqualTo(2);
    }

    @Test
    void build_throwsControlledError_whenStagesNotArray() throws Exception {
        JsonNode draft = MAPPER.readTree(
                """
                {"schemaVersion":1,"stages":{"ctx":{}}}
                """);
        assertThatThrownBy(() -> builder.build(lesson(), draft, template()))
                .isInstanceOf(DraftValidationException.class)
                .satisfies(e -> {
                    DraftValidationException dve = (DraftValidationException) e;
                    assertThat(dve.getErrors()).isNotEmpty();
                    assertThat(dve.getErrors().get(0).code())
                            .isEqualTo("STAGES_NOT_ARRAY");
                });
    }

    @Test
    void build_throwsControlledError_whenStagesMissing() throws Exception {
        JsonNode draft = MAPPER.readTree("{\"schemaVersion\":1}");
        assertThatThrownBy(() -> builder.build(lesson(), draft, template()))
                .isInstanceOf(DraftValidationException.class);
    }
}
