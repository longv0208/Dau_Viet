package com.dauviet.reward.domain;

import java.time.Instant;
import java.util.UUID;

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

    @Column(name = "active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public ItemUnlockRule() {
    }

    public static ItemUnlockRule lessonCompleted(UUID itemId, UUID lessonId) {
        ItemUnlockRule r = base(itemId, TYPE_LESSON_COMPLETED);
        r.lessonId = lessonId;
        return r;
    }

    public static ItemUnlockRule counted(UUID itemId, String ruleType,
                                         int threshold) {
        ItemUnlockRule r = base(itemId, ruleType);
        r.threshold = threshold;
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
    public boolean isActive() { return active; }
    public Instant getCreatedAt() { return createdAt; }

    public void setActive(boolean active) { this.active = active; }
}
