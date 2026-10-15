package com.dauviet.learning.snapshot;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

import com.dauviet.lesson.domain.SnapshotCorruptException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

class SnapshotModelTest {

    private static final ObjectMapper OM = new ObjectMapper();

    private static JsonNode json(String s) {
        try { return OM.readTree(s); } catch (Exception e) { throw new IllegalStateException(e); }
    }

    private static JsonNode publishableSnapshot() {
        // Mirrors AdminLessonPublishIT's publishableDraft shape after
        // SnapshotBuilder embeds evidence/assets.
        return json("""
                {"schemaVersion":1,"lessonId":"%s","title":"L","centralQuestion":"Q?",
                 "templateCode":"t",
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","config":{"text":"hi"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                    "config":{"visibleEvidenceIds":["e1"]}},
                                   {"id":"mc","type":"MULTIPLE_CHOICE",
                                    "config":{"options":[{"id":"o1"}],"correctOptionIds":["o1"]}}],
                    "requiredEvidenceIds":["e1"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true},
                 "evidence":[{"id":"e1","title":"EV","source":{"title":"src"}}],
                 "assets":[]}
                """.formatted(java.util.UUID.randomUUID()));
    }

    @Test
    void parsesPublishableSnapshot_indexesStagesAndActivities() {
        SnapshotModel m = SnapshotModel.parse(publishableSnapshot());
        assertThat(m.entryStageId()).isEqualTo("ctx");
        assertThat(m.stageById("ev")).isNotNull();
        assertThat(m.activityById("es")).isNotNull();
        assertThat(m.stageIdOf("mc")).isEqualTo("ev");
        assertThat(m.evidenceById("e1")).isNotNull();
        assertThat(m.evidenceIds()).containsExactly("e1");
        assertThat(m.completion().get("requireAllRequiredStages").asBoolean()).isTrue();
    }

    @Test
    void requiredActivities_filtersByRequiredFlag() {
        SnapshotModel m = SnapshotModel.parse(publishableSnapshot());
        // ctx stage: r1 has no required:true -> not required
        assertThat(m.requiredActivities("ctx")).isEmpty();
        assertThat(m.firstRequiredActivityId("ctx")).isNull();
        // ev stage: es required, mc not
        assertThat(m.requiredActivities("ev")).hasSize(1);
        assertThat(m.firstRequiredActivityId("ev")).isEqualTo("es");
        assertThat(m.activitiesOf("ev")).hasSize(2);
        assertThat(m.nextStageIds("ctx")).containsExactly("ev");
        assertThat(m.nextStageIds("ev")).isEmpty();
    }

    @Test
    void missingStages_throwsSnapshotCorrupt() {
        assertThatThrownBy(() -> SnapshotModel.parse(json("{\"evidence\":[]}")))
                .isInstanceOf(SnapshotCorruptException.class);
        assertThatThrownBy(() -> SnapshotModel.parse(json("{\"stages\":[]}")))
                .isInstanceOf(SnapshotCorruptException.class);
        assertThatThrownBy(() -> SnapshotModel.parse(json("[1,2]")))
                .isInstanceOf(SnapshotCorruptException.class);
    }

    @Test
    void duplicateActivityIdAcrossStages_throwsSnapshotCorrupt() {
        // Runtime indexes activities by id alone — a cross-stage collision
        // would silently shadow the earlier activity; reject at parse time.
        JsonNode snap = json("""
                {"stages":[
                  {"id":"a","type":"CONTEXT","activities":[
                    {"id":"xa","type":"READ"}],"nextStageIds":["b"]},
                  {"id":"b","type":"EVIDENCE","activities":[
                    {"id":"xa","type":"READ"}],"nextStageIds":[]}]}
                """);
        assertThatThrownBy(() -> SnapshotModel.parse(snap))
                .isInstanceOf(SnapshotCorruptException.class)
                .hasMessageContaining("duplicate activity id 'xa'");
    }

    @Test
    void activityMissingId_throwsSnapshotCorrupt() {
        assertThatThrownBy(() -> SnapshotModel.parse(json(
                "{\"stages\":[{\"id\":\"s\",\"activities\":[{\"type\":\"READ\"}]}]}")))
                .isInstanceOf(SnapshotCorruptException.class)
                .hasMessageContaining("missing id");
    }
}
