package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Mô tả chủ đề layout đảo (V44). Một definition có thể có nhiều version.
 * layout_key là định danh stable được dùng từ code (heritage-village, …).
 * Immutable về canvas_width/height sau khi đã có version PUBLISHED.
 */
@Entity
@Table(name = "island_layout_definitions")
public class IslandLayoutDefinition {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "layout_key", nullable = false, updatable = false)
    private String layoutKey;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "description")
    private String description;

    @Column(name = "canvas_width", nullable = false)
    private double canvasWidth;

    @Column(name = "canvas_height", nullable = false)
    private double canvasHeight;

    @Column(name = "theme_key")
    private String themeKey;

    @Column(name = "is_default", nullable = false)
    private boolean defaultLayout;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public IslandLayoutDefinition() {
    }

    public static IslandLayoutDefinition create(UUID id, String layoutKey,
                                                String name, String description,
                                                double canvasWidth, double canvasHeight,
                                                String themeKey, boolean defaultLayout,
                                                Instant now) {
        IslandLayoutDefinition d = new IslandLayoutDefinition();
        d.id = id;
        d.layoutKey = layoutKey;
        d.name = name;
        d.description = description;
        d.canvasWidth = canvasWidth;
        d.canvasHeight = canvasHeight;
        d.themeKey = themeKey;
        d.defaultLayout = defaultLayout;
        d.createdAt = now;
        d.updatedAt = now;
        return d;
    }

    public void updateMetadata(String name, String description,
                               Double canvasWidth, Double canvasHeight,
                               String themeKey, boolean allowCanvasChange,
                               Instant now) {
        if (name != null && !name.isBlank()) this.name = name.trim();
        if (description != null) this.description = description.trim();
        if (themeKey != null) this.themeKey = themeKey.trim();
        if (allowCanvasChange) {
            if (canvasWidth != null && canvasWidth > 0) this.canvasWidth = canvasWidth;
            if (canvasHeight != null && canvasHeight > 0) this.canvasHeight = canvasHeight;
        }
        this.updatedAt = now;
    }

    public void setDefaultLayout(boolean defaultLayout, Instant now) {
        this.defaultLayout = defaultLayout;
        this.updatedAt = now;
    }

    public UUID getId() { return id; }
    public String getLayoutKey() { return layoutKey; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public double getCanvasWidth() { return canvasWidth; }
    public double getCanvasHeight() { return canvasHeight; }
    public String getThemeKey() { return themeKey; }
    public boolean isDefaultLayout() { return defaultLayout; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
