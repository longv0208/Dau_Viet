package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Mô tả chủ đề layout đảo (V43). Một definition có thể có nhiều version.
 * layout_key là định danh stable được dùng từ code (heritage-village, …).
 * Immutable sau khi có version PUBLISHED: không sửa canvas_width/height hay
 * theme_key — tạo definition mới nếu cần thay đổi cơ bản.
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

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public IslandLayoutDefinition() {
    }

    public UUID getId() { return id; }
    public String getLayoutKey() { return layoutKey; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public double getCanvasWidth() { return canvasWidth; }
    public double getCanvasHeight() { return canvasHeight; }
    public String getThemeKey() { return themeKey; }
    public Instant getCreatedAt() { return createdAt; }
}
