package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Lớp scene của layout (V44). Flutter đọc danh sách theo render_order ASC
 * để xếp lớp canvas: water background → island base → ambient overlay → items.
 */
@Entity
@Table(name = "island_scene_layers")
public class IslandSceneLayer {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "layout_version_id", nullable = false, updatable = false)
    private UUID layoutVersionId;

    @Column(name = "layer_key", nullable = false)
    private String layerKey;

    @Column(name = "layer_type", nullable = false)
    private String layerType;

    @Column(name = "render_order", nullable = false)
    private int renderOrder;

    @Column(name = "asset_ref")
    private String assetRef;

    /** JSON string: {minTier, maxTier} — null = luôn hiện. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "visibility_rule_json", columnDefinition = "jsonb")
    private String visibilityRuleJson;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public IslandSceneLayer() {
    }

    public static IslandSceneLayer create(UUID id, UUID layoutVersionId,
                                          String layerKey, String layerType,
                                          int renderOrder, String assetRef,
                                          String visibilityRuleJson, Instant now) {
        IslandSceneLayer l = new IslandSceneLayer();
        l.id = id;
        l.layoutVersionId = layoutVersionId;
        l.layerKey = layerKey;
        l.layerType = layerType;
        l.renderOrder = renderOrder;
        l.assetRef = assetRef;
        l.visibilityRuleJson = visibilityRuleJson;
        l.createdAt = now;
        return l;
    }

    public void update(String layerKey, String layerType, int renderOrder,
                       String assetRef, String visibilityRuleJson) {
        this.layerKey = layerKey;
        this.layerType = layerType;
        this.renderOrder = renderOrder;
        this.assetRef = assetRef;
        this.visibilityRuleJson = visibilityRuleJson;
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
