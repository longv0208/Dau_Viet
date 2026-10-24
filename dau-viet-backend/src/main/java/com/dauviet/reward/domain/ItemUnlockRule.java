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
     * GAME-05 V24 + FIX-4: revision của policy MỖI ITEM — 1 = rule legacy
     * V1 hoặc publish v2 đầu tiên của item vốn có rule v1; mỗi lần admin
     * publish rule mới, revision = max(existing)+1 nên hai publish khác
     * nhau luôn phân biệt được (provenance user_inventory.unlock_rule_
     * version truy vết đúng revision đã cấp). AST format luôn là v2 —
     * "schema" của grammar không cần cột riêng (parser chỉ có một ngữ
     * pháp; khi format đổi sẽ là cột/cấu trúc mới, không reuse số này).
     */
    @Column(name = "rule_version", nullable = false, updatable = false)
    private int ruleVersion = 1;

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

    public static ItemUnlockRule lessonCompleted(UUID itemId, UUID lessonId) {
        ItemUnlockRule r = base(itemId, TYPE_LESSON_COMPLETED);
        r.lessonId = lessonId;
        r.conditionJson = "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\""
                + lessonId + "\"}";
        return r;
    }

    public static ItemUnlockRule counted(UUID itemId, String ruleType,
                                         int threshold) {
        ItemUnlockRule r = base(itemId, ruleType);
        r.threshold = threshold;
        r.conditionJson = "{\"type\":\"" + ruleType
                + "\",\"threshold\":" + threshold + "}";
        return r;
    }

    /**
     * Rule v2: AST đã parse+validate ở service — chỉ lưu canonical JSON.
     * `revision` = rule_version mới (per-item, FIX-4): service tính
     * max(revision hiện có)+1 khi thay rule; truyền 1 cho publish đầu.
     */
    public static ItemUnlockRule v2(UUID itemId, String ruleType,
                                    String conditionJson,
                                    String ruleMetadata,
                                    int revision) {
        ItemUnlockRule r = base(itemId, ruleType);
        r.ruleVersion = revision;
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
        if (ruleMetadata == null || ruleMetadata.isBlank()) return false;
        try {
            JsonNode node = new ObjectMapper().readTree(ruleMetadata);
            return "needs-mapping".equals(node.path("audit").asText());
        } catch (Exception e) {
            return false;
        }
    }
}
