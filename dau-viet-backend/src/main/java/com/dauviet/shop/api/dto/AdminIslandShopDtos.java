package com.dauviet.shop.api.dto;

import java.util.UUID;

import jakarta.validation.constraints.NotNull;

/**
 * DTOs quản trị Cửa hàng Đảo Di Sản (ISLAND-05 Part C).
 */
public final class AdminIslandShopDtos {

    private AdminIslandShopDtos() {}

    public record AdminShopOfferResponse(
            UUID itemId,
            String code,
            String name,
            String description,
            String category,
            String itemType,
            String rarity,
            UUID assetId,
            String renderKey,
            boolean placeable,
            boolean catalogActive,
            Long pricePoints,
            boolean active,
            boolean purchasable,
            int sortOrder
    ) {}

    public record CreateShopOfferRequest(
            @NotNull UUID itemId,
            Long pricePoints,
            Boolean active,
            Integer sortOrder
    ) {}

    public record UpdateShopOfferRequest(
            Long pricePoints,
            Boolean clearPrice,
            Boolean active,
            Integer sortOrder
    ) {}
}
