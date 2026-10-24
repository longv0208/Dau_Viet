package com.dauviet.reward.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Điều kiện mở khóa một vật phẩm (TASK-0023). Ba loại:
 * LESSON_COMPLETED — hoàn thành đúng `lessonId`; COLLECTION_COUNT — sưu
 * tầm đủ `threshold` evidence khác nhau; LESSON_COUNT — hoàn thành đủ
 * `threshold` bài khác nhau. Rule chỉ đánh giá lúc complete()/collect;
 * tắt rule KHÔNG revoke vật phẩm đã cấp (user_inventory là append-only).
 */
@Entity
@Table(name = "item_unlock_rule")
public class ItemUnlockRule {

    public static final String TYPE_LESSON_COMPLETED = "LESSON_COMPLETED";
    public static final String TYPE_COLLECTION_COUNT = "COLLECTION_COUNT";
    public static final String TYPE_LESSON_COUNT = "LESSON_COUNT";
    /** Discriminator cho mọi rule AST v2 — rule_type cột KHÔNG phải leaf
     * type trong condition_json (leaf type nằm trong AST). */
    public static final String TYPE_RULE_V2 = "RULE_V2";

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "item_id", nullable = false, updatable = false)
    private UUID itemId;

    @Column(name = "rule_type", nullable = false, updatable = false)
    private String ruleType;

    @Column(name = "lesson_id", updatable = false)
    private UUID lessonId;

    @Column(name = "threshold", updatable = false)
    private Integer threshold;

    /**
     * GAME-05 V24 + FINAL FIX-3: SCHEMA VERSION của rule — 1 = payload V1
     * (3 cột phẳng), 2 = payload AST trong condition_json. Đây là "kiểu
     * dữ liệu", KHÔNG phải thứ tự publish — một item có thể đi V1 → V2 →
     * V1 (admin dùng API tương thích) mà schema version vẫn đúng mô tả
     * payload, không bị ép tăng. Số thứ tự publish nằm ở {@link #revision}.
     */
    @Column(name = "rule_version", nullable = false, updatable = false)
    private int ruleVersion = 1;

    /**
     * FINAL FIX-3: revision của policy MỖI ITEM — monotonic, không giảm,
     * không reuse trong cùng item. Mọi publish (V1 lẫn V2) đều lấy
     * max(revision hiện có)+1 nên hai publish khác nhau luôn phân biệt
     * được trong provenance (user_inventory.unlock_rule_version giờ ghi
     * revision). rule_version chỉ mô tả SCHEMA payload, revision mới là
     * thứ tự publish thật.
     */
    @Column(name = "revision", nullable = false, updatable = false)
    private int revision = 1;

    /** AST serialized (jsonb); v2 bắt buộc, v1 chứa bản normalize tương đương. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "condition_json", updatable = false,
            columnDefinition = "jsonb")
    private String conditionJson;

    /** Metadata tự do (jsonb) — audit flag 'needs-mapping'/'valid-global'… */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "rule_metadata", columnDefinition = "jsonb")
    private String ruleMetadata;

    @Column(name = "active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public ItemUnlockRule() {
    }

    public static ItemUnlockRule lessonCompleted(UUID itemId, UUID lessonId,
                                                 int revision) {
        ItemUnlockRule r = base(itemId, TYPE_LESSON_COMPLETED);
        r.lessonId = lessonId;
        r.revision = revision;
        r.conditionJson = "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\""
                + lessonId + "\"}";
        return r;
    }

    public static ItemUnlockRule counted(UUID itemId, String ruleType,
                                         int threshold, int revision) {
        ItemUnlockRule r = base(itemId, ruleType);
        r.threshold = threshold;
        r.revision = revision;
        r.conditionJson = "{\"type\":\"" + ruleType
                + "\",\"threshold\":" + threshold + "}";
        return r;
    }

    /**
     * Rule v2: AST đã parse+validate ở service — chỉ lưu canonical JSON.
     * ruleVersion=2 (schema AST); `revision` = thứ tự publish per-item
     * (FINAL FIX-3): service tính max(revision hiện có)+1 khi thay rule.
     */
    public static ItemUnlockRule v2(UUID itemId, String ruleType,
                                    String conditionJson,
                                    String ruleMetadata,
                                    int revision) {
        ItemUnlockRule r = base(itemId, ruleType);
        r.ruleVersion = 2;
        r.revision = revision;
        r.conditionJson = conditionJson;
        r.ruleMetadata = ruleMetadata;
        return r;
    }

    private static ItemUnlockRule base(UUID itemId, String ruleType) {
        ItemUnlockRule r = new ItemUnlockRule();
        r.id = UUID.randomUUID();
        r.itemId = itemId;
        r.ruleType = ruleType;
        r.createdAt = Instant.now();
        return r;
    }

    public UUID getId() { return id; }
    public UUID getItemId() { return itemId; }
    public String getRuleType() { return ruleType; }
    public UUID getLessonId() { return lessonId; }
    public Integer getThreshold() { return threshold; }
    public int getRuleVersion() { return ruleVersion; }
    public int getRevision() { return revision; }
    public String getConditionJson() { return conditionJson; }
    public String getRuleMetadata() { return ruleMetadata; }
    public boolean isActive() { return active; }
    public Instant getCreatedAt() { return createdAt; }

    public void setActive(boolean active) { this.active = active; }

    /**
     * 'needs-mapping' trong rule_metadata.audit (seed audit V24): rule V1
     * đếm global cho item event-specific — chờ admin publish rule v2
     * event-scoped. Grant path + catalog read path dùng CHUNG hàm này
     * (FIX-1) nên trạng thái UNCONFIGURED khớp với quyết định chặn grant.
     * Metadata hỏng/không parse được → false: không chặn grant hợp lệ.
     */
    public static boolean isNeedsMapping(String ruleMetadata) {
        return "needs-mapping".equals(auditOf(ruleMetadata));
    }

    private static String auditOf(String ruleMetadata) {
        if (ruleMetadata == null || ruleMetadata.isBlank()) return null;
        try {
            JsonNode node = new ObjectMapper().readTree(ruleMetadata);
            return node.path("audit").asText(null);
        } catch (Exception e) {
            return null;
        }
    }

    /* ---------- FINAL FIX-2: item-level event scope từ audit trail ---------- */

    /**
     * Leaf được coi là "event-scoped" khi nó tham chiếu eventId (điều kiện
     * gắn sự kiện lịch sử cụ thể). LESSON_COMPLETED/LESSON_MASTERED là
     * lesson-scoped — bài học đã gắn event ở tầng lesson, không tính ở đây
     * để rule "hoàn thành bài X" vẫn hợp lệ cho item global. Danh sách này
     * theo GRAMMAR (LeafType), không theo mã item — không hard-code
     * Bạch Đằng/Hai Bà Trưng.
     */
    public static boolean isEventScopedLeaf(com.dauviet.reward.application
            .ItemCondition.LeafType type) {
        return switch (type) {
            case EVENT_COMPLETED, EVENT_MASTERED, EVENT_EVIDENCE_COUNT,
                 SPECIFIC_EVIDENCE_SET, TOTAL_EVENTS_COMPLETED,
                 TOTAL_EVENTS_MASTERED -> true;
            default -> false;
        };
    }

    /**
     * Scope đã duyệt của một ITEM — kết luận từ LỊCH SỬ rule của item
     * (audit trail), không phải chỉ rule đang active:
     *  - UNRESOLVED: từng có rule flag 'needs-mapping' mà chưa có rule v2
     *    event-scoped nào được publish sau đó → chặn grant mới (global
     *    bypass cũng chặn) cho tới khi admin định nghĩa event minh định.
     *  - EVENT_SCOPED: đã có rule v2 event-scoped → chỉ chấp nhận rule
     *    event-scoped (một rule global mới sẽ làm mất ý nghĩa sự kiện).
     *  - GLOBAL: chưa từng flagged / không gắn event → rule global bình
     *    thường được phép.
     *
     * Kết luận này lấy từ DỮ LIỆU (rule_metadata + AST eventId của các rule
     * đã publish) — không phải danh sách code item, nên item event-specific
     * tạo sau cũng tự bảo vệ khi rule đầu của nó event-scoped.
     */
    public enum ItemScope { UNRESOLVED, EVENT_SCOPED, GLOBAL }
}
