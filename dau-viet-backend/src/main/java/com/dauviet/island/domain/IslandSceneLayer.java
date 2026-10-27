package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Lớp scene của layout (V43). Flutter đọc danh sách theo render_order ASC
 * để xếp lớp canvas: water background → island base → ambient overlay → items.
 * layer_type xác định loại renderer phía client (STATIC_IMAGE, ANIMATED_WATER, …).
 * asset_ref là đường dẫn tương đối asset (nullable: layer dùng code renderer).
 * visibility_rule_json (nullable): điều kiện hiển thị {minTier, maxTier} — null = luôn hiện.
 */
@Entity
@Table(name = "island_scene_layers")
public class IslandSceneLayer {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "layout_version_id", nullable = false, updatable = false)
    private UUID layoutVersionId;

    @Column(name = "layer_key", nullable = false, updatable = false)
    private String layerKey;

    @Column(name = "layer_type", nullable = false, updatable = false)
    private String layerType;

    @Column(name = "render_order", nullable = false)
    private int renderOrder;

    @Column(name = "asset_ref")
    private String assetRef;

    /** JSON string: {minTier, maxTier} — null = luôn hiện. */
    @Column(name = "visibility_rule_json", columnDefinition = "jsonb")
    private String visibilityRuleJson;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public IslandSceneLayer() {
    }

    public UUID getId() { return id; }
    public UUID getLayoutVersionId() { return layoutVersionId; }
    public String getLayerKey() { return layerKey; }
    public String getLayerType() { return layerType; }
    public int getRenderOrder() { return renderOrder; }
    public String getAssetRef() { return assetRef; }
    public String getVisibilityRuleJson() { return visibilityRuleJson; }
    public Instant getCreatedAt() { return createdAt; }
}
