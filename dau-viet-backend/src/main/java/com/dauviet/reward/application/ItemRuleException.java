package com.dauviet.reward.application;

/**
 * Lỗi cấu hình rule (GAME-05): condition malformed, type không hỗ trợ,
 * tham chiếu sai trạng thái… Controller map sang 400 — KHÔNG bao giờ 500
 * cho dữ liệu rule xấu (ITEM-06: validation chặn trước publish).
 */
public class ItemRuleException extends RuntimeException {

    public ItemRuleException(String message) {
        super(message);
    }
}
