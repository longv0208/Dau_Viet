package com.dauviet.reward.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Vật phẩm learner đã sở hữu (TASK-0023). Append-only: mỗi (user_id,
 * item_id) tối đa một row — vật phẩm không stack, không tiêu hao, không
 * revoke khi unlock rule thay đổi về sau. `sourceAttemptId` truy vết
 * attempt đã kích hoạt để GET /attempts/{id}/result liệt kê "vật phẩm
 * vừa mở khóa" chính xác, không phải suy từ acquired_at.
 */
@Entity
@Table(name = "user_inventory")
public class UserInventoryItem {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "item_id", nullable = false, updatable = false)
    private UUID itemId;

    @Column(name = "acquired_at", nullable = false, updatable = false)
    private Instant acquiredAt;

    @Column(name = "acquisition_source", nullable = false, updatable = false)
    private String acquisitionSource;

    @Column(name = "source_lesson_id", updatable = false)
    private UUID sourceLessonId;

    @Column(name = "source_attempt_id", updatable = false)
    private UUID sourceAttemptId;

    public UserInventoryItem() {
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public UUID getItemId() { return itemId; }
    public Instant getAcquiredAt() { return acquiredAt; }
    public String getAcquisitionSource() { return acquisitionSource; }
    public UUID getSourceLessonId() { return sourceLessonId; }
    public UUID getSourceAttemptId() { return sourceAttemptId; }
}
