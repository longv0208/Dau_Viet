package com.dauviet.learning.application;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Unit test bảng phân loại GAME-02 §7.1 — khóa chặt danh sách type có thể
 * bị phạt: graded:true trên type ngoài danh sách KHÔNG được suy rộng,
 * PARTIAL/CONTRADICTED/SUPPORTED không phạt, verdict null an toàn.
 */
class GradedActivityClassifierTest {

    private final GradedActivityClassifier c = new GradedActivityClassifier();
    private final ObjectMapper om = new ObjectMapper();

    private JsonNode act(String type, String configJson) throws Exception {
        return om.readTree("{\"id\":\"a1\",\"type\":\"" + type + "\","
                + (configJson == null ? "\"config\":{}" : "\"config\":" + configJson)
                + "}");
    }

    private ActivityResult res(String outcome) {
        return new ActivityResult(outcome, true, null, null);
    }

    @Test
    void contractGradedTypes_alwaysPenalizable() throws Exception {
        for (String t : new String[]{"MULTIPLE_CHOICE", "MATCHING",
                "DRAG_ORDER", "CER_CHOICE"}) {
            assertThat(c.isGraded(act(t, null))).as(t).isTrue();
            assertThat(c.penalizableIncorrect(act(t, null),
                    res(ActivityResult.INCORRECT))).as(t).isTrue();
        }
    }

    @Test
    void optInGraded_onlyWhenFlagged() throws Exception {
        JsonNode es = act("EVIDENCE_SELECT",
                "{\"graded\":true,\"acceptedEvidenceIds\":[\"e1\"]}");
        JsonNode rc = act("REASONING_CONNECT",
                "{\"graded\":true,\"expectedRelations\":"
                        + "[{\"from\":\"a\",\"relation\":\"r\",\"to\":\"b\"}]}");
        assertThat(c.isGraded(es)).isTrue();
        assertThat(c.isGraded(rc)).isTrue();
        assertThat(c.isGraded(act("EVIDENCE_SELECT", null))).isFalse();
        assertThat(c.isGraded(act("REASONING_CONNECT",
                "{\"graded\":false}"))).isFalse();
    }

    @Test
    void optInGraded_flagButNoAnswerKey_notGraded() throws Exception {
        // FIX 2: graded:true thiếu key chấm → handler đi nhánh ungraded →
        // không được gate/phạt (trước đây chỉ kiểm flag → gate nhầm).
        assertThat(c.isGraded(act("EVIDENCE_SELECT",
                "{\"graded\":true}"))).isFalse();
        assertThat(c.isGraded(act("EVIDENCE_SELECT",
                "{\"graded\":true,\"acceptedEvidenceIds\":[]}"))).isFalse();
        // REASONING_CONNECT graded nhưng không có set quan hệ nào hợp lệ.
        assertThat(c.isGraded(act("REASONING_CONNECT",
                "{\"graded\":true}"))).isFalse();
        assertThat(c.isGraded(act("REASONING_CONNECT",
                "{\"graded\":true,\"expectedRelations\":[]}"))).isFalse();
        // Set rỗng phần tử (thiếu trường) cũng không tính.
        assertThat(c.isGraded(act("REASONING_CONNECT",
                "{\"graded\":true,\"expectedRelations\":["
                        + "{\"from\":\"a\"}]}"))).isFalse();
        // acceptedRelationSets[] thay thế expectedRelations.
        assertThat(c.isGraded(act("REASONING_CONNECT",
                "{\"graded\":true,\"acceptedRelationSets\":["
                        + "[{\"from\":\"a\",\"relation\":\"r\",\"to\":\"b\"}]]}"
                ))).isTrue();
        // graded:true + acceptedEvidenceIds blank-string-only → không graded.
        assertThat(c.isGraded(act("EVIDENCE_SELECT",
                "{\"graded\":true,\"acceptedEvidenceIds\":[\"  \"]}")))
                .isFalse();
    }

    @Test
    void passiveTypes_neverGraded_evenWithGradedFlag() throws Exception {
        for (String t : new String[]{"READ", "VIEW_IMAGE", "EXPLORE_MAP",
                "HYPOTHESIS_CHOICE", "VERIFICATION", "CER",
                "REFLECTION_PROMPT"}) {
            // config.graded:true trên type không hỗ trợ chấm điểm KHÔNG
            // được tự động coi là penalizable (brief §7.1).
            assertThat(c.isGraded(act(t, "{\"graded\":true}")))
                    .as(t).isFalse();
            assertThat(c.isGraded(act(t, null))).as(t).isFalse();
        }
    }

    @Test
    void nonIncorrectOutcomes_neverPenalized() throws Exception {
        JsonNode mc = act("MULTIPLE_CHOICE", null);
        for (String o : new String[]{ActivityResult.COMPLETED,
                ActivityResult.PARTIAL, ActivityResult.CONTRADICTED,
                ActivityResult.SUPPORTED, ActivityResult.IN_PROGRESS}) {
            assertThat(c.penalizableIncorrect(mc, res(o)))
                    .as(o).isFalse();
        }
        assertThat(c.penalizableIncorrect(mc, null)).isFalse();
        // Incorrect trên activity KHÔNG graded (vd VERIFICATION không thể
        // phát INCORRECT, nhưng phòng contract mở rộng) — vẫn không phạt.
        assertThat(c.penalizableIncorrect(act("VERIFICATION", null),
                res(ActivityResult.INCORRECT))).isFalse();
    }
}
