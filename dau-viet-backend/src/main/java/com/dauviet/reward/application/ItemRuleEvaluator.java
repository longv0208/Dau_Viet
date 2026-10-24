package com.dauviet.reward.application;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.dauviet.collection.domain.UserEventProgress;
import com.dauviet.reward.application.ItemCondition.Leaf;
import com.dauviet.reward.application.ItemCondition.LeafType;

/**
 * Đánh giá typed AST của {@link ItemCondition} trên trạng thái learner
 * (GAME-05). Thuần đọc — KHÔNG ghi DB; recorder/service chịu trách nhiệm
 * grant. Trả {@link Evaluation} gồm satisfied + cây status từng nhánh để
 * API trả current/required + mô tả cho Flutter (không một progress bar
 * tổng hợp gây hiểu nhầm).
 *
 * Ngữ nghĩa leaf:
 *  - LESSON_COMPLETED: learner có attempt COMPLETED trên lesson (mọi version).
 *  - COLLECTION_COUNT: COUNT(DISTINCT evidence_id) toàn cục ≥ threshold —
 *    GIỮ semantics global của V1 (D2 gap report: không âm thầm đổi rule đã
 *    publish; rule event-scoped dùng EVENT_EVIDENCE_COUNT).
 *  - LESSON_COUNT: số lesson khác nhau đã COMPLETED ≥ threshold.
 *  - EVENT_COMPLETED / EVENT_MASTERED: milestone đã ghi trong
 *    user_event_progress — ledger GAME-04, KHÔNG recompute từ lesson.
 *  - EVENT_EVIDENCE_COUNT: COUNT(DISTINCT evidence_id) THUỘC event khai báo.
 *  - SPECIFIC_EVIDENCE_SET: mọi evidenceIds ⊆ tập learner đã collect (và
 *    thuộc eventId khai báo — validator đã chặn sai-event khi publish).
 *  - TOTAL_EVENTS_COMPLETED / TOTAL_EVENTS_MASTERED: COUNT(DISTINCT
 *    event_id) trên ledger theo milestone.
 *  - LESSON_MASTERED: best knowledgeScore trên lesson ≥ threshold.
 *  - LEVEL_AT_LEAST: parse/DTO được nhưng CHƯA đánh giá (GAME-07) —
 *    status UNSUPPORTED, không bao giờ satisfied.
 */
@Component
public class ItemRuleEvaluator {

    /** Một node trong cây status trả về cho client. */
    public record ConditionStatus(
            /** LEAF | ALL | ANY */
            String node,
            LeafType type,
            UUID eventId,
            UUID lessonId,
            List<UUID> evidenceIds,
            Integer threshold,
            /** tiến độ hiện tại của leaf (null khi không áp dụng/boolean) */
            Long current,
            /** giá trị cần đạt của leaf (threshold hoặc kích thước set) */
            Long required,
            boolean satisfied,
            /** SATISFIED | PENDING | UNSUPPORTED — UNSUPPORTED cho leaf
             * chưa đánh giá được (LEVEL_AT_LEAST…), không bao giờ coi là
             * đạt bất kể current. */
            String status,
            /** Mô tả tiếng Việt phục vụ hiển thị; server-authored để client
             * không phải dịch ngược rule. */
            String description,
            List<ConditionStatus> children) {
    }

    public record Evaluation(boolean satisfied,
                             ConditionStatus root) {
    }

    public Evaluation evaluate(ItemCondition condition,
                               ItemRuleEvaluationContext ctx) {
        ConditionStatus root = node(condition, ctx);
        return new Evaluation(root.satisfied(), root);
    }

    /** Chỉ cần biết có đạt không (grant path) — vẫn trả root để log/debug. */
    public boolean satisfied(ItemCondition condition,
                             ItemRuleEvaluationContext ctx) {
        return evaluate(condition, ctx).satisfied();
    }

    private ConditionStatus node(ItemCondition c,
                                 ItemRuleEvaluationContext ctx) {
        return switch (c) {
            case ItemCondition.All a -> {
                List<ConditionStatus> kids = a.children().stream()
                        .map(ch -> node(ch, ctx)).toList();
                boolean sat = kids.stream().allMatch(ConditionStatus::satisfied);
                yield new ConditionStatus("ALL", null, null, null, null,
                        null, null, null, sat, sat ? "SATISFIED" : "PENDING",
                        "Hoàn thành tất cả điều kiện sau", kids);
            }
            case ItemCondition.Any a -> {
                List<ConditionStatus> kids = a.children().stream()
                        .map(ch -> node(ch, ctx)).toList();
                boolean sat = kids.stream().anyMatch(ConditionStatus::satisfied);
                yield new ConditionStatus("ANY", null, null, null, null,
                        null, null, null, sat, sat ? "SATISFIED" : "PENDING",
                        "Hoàn thành một trong các điều kiện sau", kids);
            }
            case Leaf l -> leaf(l, ctx);
        };
    }

    private ConditionStatus leaf(Leaf l, ItemRuleEvaluationContext ctx) {
        return switch (l.type()) {
            case LESSON_COMPLETED -> {
                boolean sat = ctx.lessonCompleted(l.lessonId());
                yield leafStatus(l, sat,
                        sat ? 1L : 0L, 1L,
                        "Hoàn thành bài học yêu cầu");
            }
            case COLLECTION_COUNT -> {
                long cur = ctx.globalEvidenceCount();
                boolean sat = cur >= l.threshold();
                yield leafStatus(l, sat, cur, (long) l.threshold(),
                        "Sưu tầm đủ " + l.threshold() + " bằng chứng");
            }
            case LESSON_COUNT -> {
                long cur = ctx.completedLessonCount();
                boolean sat = cur >= l.threshold();
                yield leafStatus(l, sat, cur, (long) l.threshold(),
                        "Hoàn thành đủ " + l.threshold() + " bài học");
            }
            case EVENT_COMPLETED -> {
                boolean sat = ctx.milestone(l.eventId(),
                        UserEventProgress.Milestone.EVENT_COMPLETED.name());
                yield leafStatus(l, sat, sat ? 1L : 0L, 1L,
                        "Hoàn thành sự kiện yêu cầu");
            }
            case EVENT_MASTERED -> {
                boolean sat = ctx.milestone(l.eventId(),
                        UserEventProgress.Milestone.EVENT_MASTERED.name());
                yield leafStatus(l, sat, sat ? 1L : 0L, 1L,
                        "Đạt thành thạo sự kiện yêu cầu");
            }
            case EVENT_EVIDENCE_COUNT -> {
                long cur = ctx.evidenceCountForEvent(l.eventId());
                boolean sat = cur >= l.threshold();
                yield leafStatus(l, sat, cur, (long) l.threshold(),
                        "Sưu tầm đủ " + l.threshold()
                                + " bằng chứng của sự kiện");
            }
            case SPECIFIC_EVIDENCE_SET -> {
                var owned = ctx.collectedEvidenceIds();
                long cur = l.evidenceIds().stream().filter(owned::contains)
                        .count();
                boolean sat = owned.containsAll(l.evidenceIds());
                yield leafStatus(l, sat, cur, (long) l.evidenceIds().size(),
                        "Sưu tầm đủ bộ bằng chứng chỉ định");
            }
            case TOTAL_EVENTS_COMPLETED -> {
                long cur = ctx.totalMilestone(
                        UserEventProgress.Milestone.EVENT_COMPLETED.name());
                boolean sat = cur >= l.threshold();
                yield leafStatus(l, sat, cur, (long) l.threshold(),
                        "Hoàn thành đủ " + l.threshold() + " sự kiện");
            }
            case TOTAL_EVENTS_MASTERED -> {
                long cur = ctx.totalMilestone(
                        UserEventProgress.Milestone.EVENT_MASTERED.name());
                boolean sat = cur >= l.threshold();
                yield leafStatus(l, sat, cur, (long) l.threshold(),
                        "Đạt thành thạo đủ " + l.threshold() + " sự kiện");
            }
            case LESSON_MASTERED -> {
                var best = ctx.bestScore(l.lessonId());
                boolean sat = ctx.lessonMastered(l.lessonId(), l.threshold());
                yield leafStatus(l, sat,
                        best == null ? 0L : best.longValue(),
                        (long) l.threshold(),
                        "Đạt điểm hiểu biết tối thiểu " + l.threshold()
                                + " ở bài học");
            }
            case LEVEL_AT_LEAST ->
                    // Parse được nhưng GAME-07 mới đánh giá — không bao giờ
                    // satisfied; validator cũng chặn publish nên đây là
                    // backstop cho rule lưu từ trước.
                    new ConditionStatus("LEAF", l.type(), l.eventId(),
                            l.lessonId(), l.evidenceIds(), l.threshold(),
                            null, l.level() == null ? null
                                    : (long) l.level(),
                            false, "UNSUPPORTED",
                            "Điều kiện cấp độ chưa được hỗ trợ", List.of());
        };
    }

    private ConditionStatus leafStatus(Leaf l, boolean satisfied,
                                       Long current, Long required,
                                       String description) {
        return new ConditionStatus("LEAF", l.type(), l.eventId(),
                l.lessonId(), l.evidenceIds(), l.threshold(), current,
                required, satisfied,
                satisfied ? "SATISFIED" : "PENDING", description,
                List.of());
    }
}
