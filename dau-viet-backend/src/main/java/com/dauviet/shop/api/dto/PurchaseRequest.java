package com.dauviet.shop.api.dto;

import java.util.UUID;

import jakarta.validation.constraints.NotNull;

/** POST /api/v1/me/shop/purchases body. */
public record PurchaseRequest(
        @NotNull UUID itemId
) {
}
