package com.dauviet.reward.application;

import java.util.List;
import java.util.UUID;

/**
 * AST typed của điều kiện mở khóa vật phẩm (GAME-05 §2.5 contract).
 * Leaf | All(children) | Any(children) — không arbitrary nesting sâu hơn
 * depth limit của parser; không rule-reference (tránh vòng lặp).
 *
 * Evaluator pattern-matching trên các subtype; mỗi leaf giữ nguyên
 * params đã parse (eventId/lessonId/evidenceIds/threshold/level) để
 * per-branch status trả current/required cho client.
 */
public sealed interface ItemCondition {

    /** Hợp đồng leaf phẳng — params đã validate kiểu (không validate tồn tại). */
    record Leaf(LeafType type,
                UUID eventId,
                UUID lessonId,
                List<UUID> evidenceIds,
                Integer threshold,
                Integer level) implements ItemCondition {
    }

    /** AND: mọi con phải satisfied. */
    record All(List<ItemCondition> children) implements ItemCondition {
    }

    /** OR: ít nhất một con satisfied. */
    record Any(List<ItemCondition> children) implements ItemCondition {
    }

    /** Loại điều kiện hợp lệ — LEVEL_AT_LEAST parse được nhưng V1 không
     * đánh giá (evaluator trả unsupported, không bao giờ satisfied). */
    enum LeafType {
        LESSON_COMPLETED,
        COLLECTION_COUNT,
        LESSON_COUNT,
        EVENT_COMPLETED,
        EVENT_MASTERED,
        LESSON_MASTERED,
        EVENT_EVIDENCE_COUNT,
        SPECIFIC_EVIDENCE_SET,
        TOTAL_EVENTS_COMPLETED,
        TOTAL_EVENTS_MASTERED,
        LEVEL_AT_LEAST
    }
}
