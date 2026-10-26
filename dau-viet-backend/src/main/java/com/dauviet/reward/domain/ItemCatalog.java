package com.dauviet.reward.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Một vật phẩm trong catalog phần thưởng (TASK-0023). Luôn là mô hình /
 * phiên bản số / huy hiệu kỷ niệm phục vụ học tập — KHÔNG phải cổ vật
 * thật; `sourceMetadata` chỉ trỏ tham chiếu tới hiện vật/di tích được đề
 * cập, không bịa provenance.
 */
@Entity
@Table(name = "item_catalog")
public class ItemCatalog {

    public static final String TYPE_HISTORICAL_REPLICA = "HISTORICAL_REPLICA";
    public static final String TYPE_DIGITAL_EDITION = "DIGITAL_EDITION";
    public static final String TYPE_COMMEMORATIVE_BADGE = "COMMEMORATIVE_BADGE";
    /** V32: vật phẩm trang trí Đảo Di Sản — mua được, placeable được cấu hình. */
    public static final String TYPE_DECOR = "DECOR";

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "code", nullable = false, updatable = false)
    private String code;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "description", nullable = false)
    private String description = "";

    @Column(name = "category", nullable = false)
    private String category;

    @Column(name = "item_type", nullable = false)
    private String itemType;

    @Column(name = "rarity", nullable = false)
    private String rarity = "COMMON";

    @Column(name = "asset_id")
    private UUID assetId;

    /** V32: item có đặt được lên đảo không (decor/cosmetic placeable). */
    @Column(name = "placeable", nullable = false)
    private boolean placeable = false;

    /** V32: khóa renderer client (ví dụ "decor.cay_da") — null = không render. */
    @Column(name = "render_key", length = 80)
    private String renderKey;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "source_metadata", columnDefinition = "jsonb")
    private String sourceMetadata;

    @Column(name = "active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public ItemCatalog() {
    }

    public static ItemCatalog create(String code, String name, String category,
                                     String itemType) {
        ItemCatalog i = new ItemCatalog();
        i.id = UUID.randomUUID();
        i.code = code;
        i.name = name;
        i.category = category;
        i.itemType = itemType;
        i.createdAt = Instant.now();
        i.updatedAt = i.createdAt;
        return i;
    }

    public UUID getId() { return id; }
    public String getCode() { return code; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public String getCategory() { return category; }
    public String getItemType() { return itemType; }
    public String getRarity() { return rarity; }
    public UUID getAssetId() { return assetId; }
    public String getSourceMetadata() { return sourceMetadata; }
    public boolean isActive() { return active; }
    public boolean isPlaceable() { return placeable; }
    public String getRenderKey() { return renderKey; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getRowVersion() { return rowVersion; }

    public void setName(String name) { this.name = name; touch(); }
    public void setDescription(String description) {
        this.description = description; touch();
    }
    public void setCategory(String category) { this.category = category; touch(); }
    public void setItemType(String itemType) { this.itemType = itemType; touch(); }
    public void setRarity(String rarity) { this.rarity = rarity; touch(); }
    public void setAssetId(UUID assetId) { this.assetId = assetId; touch(); }
    public void setPlaceable(boolean placeable) {
        this.placeable = placeable; touch();
    }
    public void setRenderKey(String renderKey) {
        this.renderKey = renderKey; touch();
    }
    public void setSourceMetadata(String sourceMetadata) {
        this.sourceMetadata = sourceMetadata; touch();
    }
    public void setActive(boolean active) { this.active = active; touch(); }

    private void touch() { this.updatedAt = Instant.now(); }
}
