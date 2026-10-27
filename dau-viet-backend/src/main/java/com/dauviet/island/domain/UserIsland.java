package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Đảo Di Sản của một learner (V32). Một row/user, lazy-create lần đầu đọc/
 * ghi — tier mặc định 1, KHÔNG tự nâng khi event hoàn thành, KHÔNG tự hạ
 * khi island_tier_policies đổi (policy copy-on-write).
 * row_version phục vụ expectedRevision trên PUT/DELETE placements —
 * optimistic lock chống hai thiết bị ghi placement đồng thời.
 */
@Entity
@Table(name = "user_islands")
public class UserIsland {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "tier", nullable = false)
    private int tier = 1;

    @Column(name = "layout_code", nullable = false)
    private String layoutCode = "heritage-v1";

    /**
     * FK → island_layout_versions.id (V43). Lưu version layout được dùng
     * khi tạo đảo — user bị pin vào version này (layout published immutable).
     * Nullable vì row cũ tạo trước V43 được backfill bằng migration.
     */
    @Column(name = "layout_version_id")
    private java.util.UUID layoutVersionId;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    @Column(name = "upgraded_at")
    private Instant upgradedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public UserIsland() {
    }

    /** Đảo mới: tier 1 mặc định, chưa upgrade lần nào. */
    public static UserIsland create(UUID userId, Instant now) {
        UserIsland i = new UserIsland();
        i.userId = userId;
        i.tier = 1;
        i.layoutCode = "heritage-v1";
        i.createdAt = now;
        i.updatedAt = now;
        return i;
    }

    /**
     * Đảo mới với layout version cụ thể (V44). Dùng khi IslandLayoutService
     * đã xác định default published version.
     */
    public static UserIsland create(UUID userId, Instant now,
                                    UUID layoutVersionId) {
        UserIsland i = create(userId, now);
        i.layoutVersionId = layoutVersionId;
        return i;
    }

    public void pinLayoutVersion(UUID layoutVersionId, String layoutCode, Instant now) {
        this.layoutVersionId = layoutVersionId;
        if (layoutCode != null && !layoutCode.isBlank()) {
            this.layoutCode = layoutCode;
        }
        this.updatedAt = now;
    }

    /**
     * Nâng lên tier mới. Caller (service) đã kiểm tra eligibility +
     * newTier > current; method chỉ ghi nhận — không auto-downgrade.
     */
    public void upgradeTo(int newTier, Instant now) {
        this.tier = newTier;
        this.upgradedAt = now;
        this.updatedAt = now;
    }

    /**
     * Cập nhật updatedAt để JPA @Version tăng row_version sau khi save.
     * Dùng sau place/remove placement thành công — placement không thay đổi
     * UserIsland trực tiếp, nhưng revision phải tăng để client detect conflict.
     */
    public void touch(Instant now) {
        this.updatedAt = now;
    }

    public UUID getUserId() { return userId; }
    public int getTier() { return tier; }
    public String getLayoutCode() { return layoutCode; }
    public Long getRowVersion() { return rowVersion; }
    public java.util.UUID getLayoutVersionId() { return layoutVersionId; }
    public Instant getUpgradedAt() { return upgradedAt; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
