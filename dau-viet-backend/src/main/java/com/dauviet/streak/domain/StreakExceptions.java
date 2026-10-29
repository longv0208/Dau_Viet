package com.dauviet.streak.domain;

/**
 * Domain exceptions của module Chuỗi Ngày Học (STREAK-02, V51). Mapped
 * sang HTTP ở GlobalExceptionHandler — tách khỏi IslandExceptions để
 * streak không lệ thuộc module đảo/shop.
 */
public final class StreakExceptions {

    private StreakExceptions() {
    }

    /** 422 — user đã tích trữ đủ MAX_SHIELDS, không mua thêm được. */
    public static class ShieldAtMaxCapacityException extends RuntimeException {
        private final int shieldCount;
        private final int maxShields;

        public ShieldAtMaxCapacityException(int shieldCount, int maxShields) {
            super("shield at max capacity: " + shieldCount + "/" + maxShields);
            this.shieldCount = shieldCount;
            this.maxShields = maxShields;
        }

        public int getShieldCount() { return shieldCount; }
        public int getMaxShields() { return maxShields; }
    }
}
