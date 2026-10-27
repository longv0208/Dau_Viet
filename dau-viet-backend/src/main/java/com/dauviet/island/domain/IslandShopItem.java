package com.dauviet.island.domain;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Chính sách bán của một item trong shop Đảo (V32, ISLAND-05). Tách khỏi item_catalog:
 * catalog là content, đây là commerce — giá/cờ bán thay đổi độc lập item
 * rule. pricePoints NULL = chỉ trưng bày (catalog-only) → API trả
 * ITEM_NOT_FOR_SALE khi cố mua; item không có row ở đây = không bán.
 */
@Entity
@Table(name = "island_shop_items")
public class IslandShopItem {

    @Id
    @Column(name = "item_id", nullable = false, updatable = false)
    private UUID itemId;

    /** Giá bằng Điểm Sử Ký; null = không bán (display-only). */
    @Column(name = "price_points")
    private Long pricePoints;

    @Column(name = "active", nullable = false)
    private boolean active = true;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    public IslandShopItem() {
    }

    public static IslandShopItem create(UUID itemId, Long pricePoints,
                                        boolean active, int sortOrder) {
        IslandShopItem s = new IslandShopItem();
        s.itemId = itemId;
        s.pricePoints = pricePoints;
        s.active = active;
        s.sortOrder = sortOrder;
        return s;
    }

    public void updateOffer(Long pricePoints, Boolean active, Integer sortOrder) {
        this.pricePoints = pricePoints;
        if (active != null) {
            this.active = active;
        }
        if (sortOrder != null) {
            this.sortOrder = sortOrder;
        }
    }

    public void setPricePoints(Long pricePoints) { this.pricePoints = pricePoints; }
    public void setActive(boolean active) { this.active = active; }
    public void setSortOrder(int sortOrder) { this.sortOrder = sortOrder; }

    public UUID getItemId() { return itemId; }
    public Long getPricePoints() { return pricePoints; }
    public boolean isActive() { return active; }
    public int getSortOrder() { return sortOrder; }

    /** Item này hiện có bán không (active + có giá nguyên dương). */
    public boolean isForSale() {
        return active && pricePoints != null && pricePoints > 0;
    }
}
