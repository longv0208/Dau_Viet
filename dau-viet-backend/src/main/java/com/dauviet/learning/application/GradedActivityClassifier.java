package com.dauviet.learning.application;

import org.springframework.stereotype.Component;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.lesson.draft.ActivityType;
import com.fasterxml.jackson.databind.JsonNode;

/**
 * Bộ phân loại "activity có chấm điểm" TẬP TRUNG (GAME-02 §7.1): quyết định
 * (a) activity nào có thể tiêu Thể lực, và (b) verdict nào thực sự bị phạt.
 * Tách khỏi LearnerAttemptService để cả energy gate/penalty lẫn
 * knowledgeScore (GAME-04) dùng chung một nguồn — không hard-code bản sao
 * thứ hai của bảng loại.
 *
 * <p>Hai lớp (trùng contract §4 DV-GAME-TC-001):
 *  - graded theo contract: MULTIPLE_CHOICE, MATCHING, DRAG_ORDER, CER_CHOICE
 *    — handler luôn phát verdict đúng/sai;
 *  - graded opt-in: EVIDENCE_SELECT, REASONING_CONNECT khi config.graded:true
 *    — flag biến đánh giá của chúng thành phán quyết đúng/sai.
 *
 * <p>KHÔNG suy rộng: graded:true trên type ngoài danh sách (READ, VERIFICATION,
 * HYPOTHESIS_CHOICE, CER, REFLECTION_PROMPT, EXPLORE_MAP, VIEW_IMAGE) KHÔNG
 * được tự động coi là có thể phạt — bảng loại trừ đóng băng theo baseline
 * §6.2 và handler của chúng không phát verdict INCORRECT theo nghĩa "trả lời
 * sai câu kiến thức".
 */
@Component
public class GradedActivityClassifier {

    /**
     * Activity này có đường dẫn đánh giá đúng/sai thật không (có thể mất
     * Thể lực). Input là activity node trong pinned snapshot.
     */
    public boolean isGraded(JsonNode activity) {
        if (activity == null) return false;
        String type = activity.path("type").asText("");
        if (ActivityType.MULTIPLE_CHOICE.name().equals(type)
                || ActivityType.MATCHING.name().equals(type)
                || ActivityType.DRAG_ORDER.name().equals(type)
                || ActivityType.CER_CHOICE.name().equals(type)) {
            return true;
        }
        if (ActivityType.EVIDENCE_SELECT.name().equals(type)
                || ActivityType.REASONING_CONNECT.name().equals(type)) {
            JsonNode config = activity.get("config");
            return config != null && config.path("graded").asBoolean(false);
        }
        return false;
    }

    /**
     * Verdict phạt được: graded + outcome INCORRECT (§4 contract). PARTIAL,
     * CONTRADICTED, SUPPORTED, IN_PROGRESS, COMPLETED — đều không phạt.
     * Exhausted-completed với outcome INCORRECT vẫn phạt đúng một lần
     * (completed ≠ correct).
     */
    public boolean penalizableIncorrect(JsonNode activity, ActivityResult result) {
        return result != null
                && ActivityResult.INCORRECT.equals(result.outcome())
                && isGraded(activity);
    }
}
