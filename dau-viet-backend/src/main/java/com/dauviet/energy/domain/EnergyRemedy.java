package com.dauviet.energy.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Một vật phẩm / liệu pháp hồi phục Thể lực tại Viện Thái Y (V49).
 * Seed Phương án B có 4 row mặc định (NUOC_VOI / TRA_SEN / NAM_LINH_CHI /
 * SAM_NGOC_LINH); Admin CRUD qua {@code /api/v1/admin/energy/remedies}.
 *
 * <p>cooldown_seconds = 0 → không giới hạn tần suất; > 0 → mỗi user chỉ
 * refill remedy này tối đa 1 lần trong cửa sổ cooldown.
 */
@Entity
@Table(name = "energy_remedies")
public class EnergyRemedy {

    public static final String RARITY_COMMON = "COMMON";
    public static final String RARITY_UNCOMMON = "UNCOMMON";
    public static final String RARITY_RARE = "RARE";
    public static final String RARITY_EPIC = "EPIC";

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "code", nullable = false, updatable = false, length = 64)
    private String code;

    @Column(name = "title", nullable = false, length = 160)
    private String title;

    @Column(name = "description", nullable = false, columnDefinition = "text")
    private String description;

    @Column(name = "rarity", nullable = false, length = 24)
    private String rarity;

    @Column(name = "icon_key", nullable = false, length = 80)
    private String iconKey;

    @Column(name = "asset_id")
    private UUID assetId;

    @Column(name = "energy_gain", nullable = false)
    private int energyGain;

    @Column(name = "points_cost", nullable = false)
    private long pointsCost;

    @Column(name = "cooldown_seconds", nullable = false)
    private int cooldownSeconds;

    @Column(name = "active", nullable = false)
    private boolean active;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public EnergyRemedy() {
    }

    public UUID getId() { return id; }
    public String getCode() { return code; }
    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public String getRarity() { return rarity; }
    public String getIconKey() { return iconKey; }
    public UUID getAssetId() { return assetId; }
    public int getEnergyGain() { return energyGain; }
    public long getPointsCost() { return pointsCost; }
    public int getCooldownSeconds() { return cooldownSeconds; }
    public boolean isActive() { return active; }
    public int getSortOrder() { return sortOrder; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getRowVersion() { return rowVersion; }

    /** Tạo remedy mới — code được admin khai báo, service bảo đảm UNIQUE. */
    public static EnergyRemedy create(UUID id, String code, String title,
                                      String description, String rarity,
                                      String iconKey, UUID assetId,
                                      int energyGain, long pointsCost,
                                      int cooldownSeconds, boolean active,
                                      int sortOrder, Instant now) {
        EnergyRemedy r = new EnergyRemedy();
        r.id = id;
        r.code = code;
        r.title = title;
        r.description = description;
        r.rarity = rarity;
        r.iconKey = iconKey;
        r.assetId = assetId;
        r.energyGain = energyGain;
        r.pointsCost = pointsCost;
        r.cooldownSeconds = cooldownSeconds;
        r.active = active;
        r.sortOrder = sortOrder;
        r.createdAt = now;
        r.updatedAt = now;
        return r;
    }

    /**
     * Cập nhật remedy — KHÔNG đổi code (khóa ngoại trace trong
     * energy_transactions.reference_json). Caller truyền giá trị mới từ
     * request PUT/PATCH (đã merge với hiện trạng ở service).
     */
    public void apply(String title, String description, String rarity,
                      String iconKey, UUID assetId, int energyGain,
                      long pointsCost, int cooldownSeconds, boolean active,
                      int sortOrder, Instant now) {
        this.title = title;
        this.description = description;
        this.rarity = rarity;
        this.iconKey = iconKey;
        this.assetId = assetId;
        this.energyGain = energyGain;
        this.pointsCost = pointsCost;
        this.cooldownSeconds = cooldownSeconds;
        this.active = active;
        this.sortOrder = sortOrder;
        this.updatedAt = now;
    }
}
