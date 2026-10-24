package com.dauviet.learning.application;

import java.util.LinkedHashSet;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.lesson.draft.ActivityType;
import com.fasterxml.jackson.databind.JsonNode;

/**
 * Bộ phân loại "activity có chấm điểm" TẬP TRUNG (GAME-02 §7.1 + FIX 2):
 * quyết định (a) activity nào có thể tiêu Thể lực, và (b) verdict nào thực
 * sự bị phạt. Tách khỏi LearnerAttemptService để cả energy gate/penalty lẫn
 * knowledgeScore (GAME-04) dùng chung một nguồn — không hard-code bản sao
 * thứ hai của bảng loại.
 *
 * <p>Hai lớp (trùng contract §4 DV-GAME-TC-001):
 *  - graded theo contract: MULTIPLE_CHOICE, MATCHING, DRAG_ORDER, CER_CHOICE
 *    — handler luôn phát verdict đúng/sai;
 *  - graded opt-in: EVIDENCE_SELECT, REASONING_CONNECT khi config.graded:true
 *    VÀ handler thực sự có đáp án để chấm (FIX 2 — trước chỉ kiểm flag,
 *    nay phải kiểm cả điều kiện handler đồng ý vào evaluateGraded).
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
     * Activity này có đường dẫn đánh giá đúng/sai THỰC SỰ không (có thể mất
     * Thể lực). Input là activity node trong pinned snapshot.
     *
     * <p>Đồng bộ điều kiện của handler (FIX 2):
     *  - EVIDENCE_SELECT: graded:true VÀ acceptedEvidenceIds non-empty
     *    (SelectionHandlers: `graded = flag && !accepted.isEmpty()`).
     *  - REASONING_CONNECT: graded:true VÀ ít nhất một accepted relation set
     *    hợp lệ — expectedRelations ∪ acceptedRelationSets[], mỗi phần tử
     *    phải đủ from|relation|to (ReasoningHandlers.evaluateGraded).
     *  - Không cần kiểm key của contract-graded types: publish validation đã
     *    đảm bảo correctOptionIds/correctPairs/expectedOrder/acceptedCombos
     *    tồn tại; handler của chúng vẫn phát verdict dù config lạ.
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
        if (ActivityType.EVIDENCE_SELECT.name().equals(type)) {
            JsonNode config = activity.get("config");
            return config != null
                    && config.path("graded").asBoolean(false)
                    && hasNonEmptyIds(config.get("acceptedEvidenceIds"));
        }
        if (ActivityType.REASONING_CONNECT.name().equals(type)) {
            JsonNode config = activity.get("config");
            return config != null
                    && config.path("graded").asBoolean(false)
                    && !acceptedRelationSets(config).isEmpty();
        }
        return false;
    }

    /**
     * Verdict phạt được: graded + outcome INCORRECT (§4 contract). PARTIAL,
     * CONTRADICTED, SUPPORTED, IN_PROGRESS, COMPLETED — đều không phạt.
     * Exhausted-completed với outcome INCORRECT vẫn phạt đúng một lần
     * (completed ≠ correct). EVIDENCE_SELECT/REASONING_CONNECT/contract
     * graded đều emit INCORRECT khi hết lượt (bestMatch = 0 hoặc exhausted)
     * — đúng business rules: sai kiến thức có chấm điểm phải trừ energy kể
     * cả khi đã completed-for-progress.
     */
    public boolean penalizableIncorrect(JsonNode activity, ActivityResult result) {
        return result != null
                && ActivityResult.INCORRECT.equals(result.outcome())
                && isGraded(activity);
    }

    /* ---------- helpers đọc config an toàn ---------- */

    /** acceptedEvidenceIds là array có ít nhất một id dạng chuỗi non-blank. */
    private boolean hasNonEmptyIds(JsonNode array) {
        if (array == null || !array.isArray()) return false;
        for (JsonNode n : array) {
            if (n.isTextual() && !n.asText().isBlank()) return true;
        }
        return false;
    }

    /**
     * Mirror ReasoningHandlers.acceptedSets: canonical expectedRelations
     * cộng mọi acceptedRelationSets[] member — chỉ giữ set có ít nhất một
     * quan hệ đủ ba trường (from|relation|to).
     */
    private Set<String> acceptedRelationSets(JsonNode config) {
        Set<String> sets = new LinkedHashSet<>();
        addRelationSet(config.get("expectedRelations"), sets);
        JsonNode alts = config.get("acceptedRelationSets");
        if (alts != null && alts.isArray()) {
            for (JsonNode alt : alts) addRelationSet(alt, sets);
        }
        return sets;
    }

    private void addRelationSet(JsonNode array, Set<String> sink) {
        if (array == null || !array.isArray()) return;
        for (JsonNode rel : array) {
            String from = rel.path("from").asText(null);
            String to = rel.path("to").asText(null);
            String name = rel.path("relation").asText(null);
            if (from != null && to != null && name != null) {
                sink.add(from + "|" + name + "|" + to);
            }
        }
    }
}
