package com.dauviet.shop.api.dto;

import java.time.Instant;
import java.util.UUID;

/** Kết quả POST /api/v1/me/shop/purchases — thông tin vật phẩm + ví sau trừ. */
public record PurchaseResponse(
        UUID itemId,
        String code,
        String name,
        long pricePoints,
        long balanceAfter,
        String currency,
        Instant purchasedAt
) {
}
