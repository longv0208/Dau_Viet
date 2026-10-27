package com.dauviet.shop.api.dto;

import java.util.UUID;

/**
 * GET /api/v1/shop/items — một SKU trong shop Đảo.
 * purchasable=false → giá null (chưa mở bán) hoặc active=false (ẩn — client
 * vẫn nhận được item nhưng nút mua disabled).
 */
public record ShopItemResponse(
        UUID itemId,
        String code,
        String name,
        String description,
        String category,
        String itemType,
        String rarity,
        UUID assetId,
        String renderKey,
        Long pricePoints,
        boolean purchasable
) {
}
