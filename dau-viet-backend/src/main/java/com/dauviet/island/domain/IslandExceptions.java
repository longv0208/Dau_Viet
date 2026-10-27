package com.dauviet.island.domain;

import java.util.UUID;

/**
 * Domain exceptions của module Đảo Di Sản — map sang ApiError code qua
 * GlobalExceptionHandler. Mỗi exception một class lồng nhau để handler
 * đăng ký rõ ràng theo type, giống {@link com.dauviet.animation.domain
 * .AnimationExceptions}.
 */
public final class IslandExceptions {

    private IslandExceptions() {
    }

    /** 409 — balance < price sau lock. */
    public static class InsufficientFundsException extends RuntimeException {
        private final long balance;
        private final long price;

        public InsufficientFundsException(long balance, long price) {
            super("insufficient funds: balance=" + balance + " price=" + price);
            this.balance = balance;
            this.price = price;
        }

        public long getBalance() { return balance; }
        public long getPrice() { return price; }
    }

    /** 403 — placement tham chiếu item không nằm trong user_inventory. */
    public static class ItemNotOwnedException extends RuntimeException {
        public ItemNotOwnedException(UUID itemId) {
            super("item not owned: " + itemId);
        }
    }

    /** 409 — mua item đã có trong inventory (non-stackable). */
    public static class ItemAlreadyOwnedException extends RuntimeException {
        public ItemAlreadyOwnedException(UUID itemId) {
            super("item already owned: " + itemId);
        }
    }

    /** 422 — item có placeable=false (badge/replica không phải decor). */
    public static class ItemNotPlaceableException extends RuntimeException {
        public ItemNotPlaceableException(UUID itemId) {
            super("item not placeable on island: " + itemId);
        }
    }

    /** 403 — slot yêu cầu tier cao hơn tier hiện tại của đảo. */
    public static class SlotLockedException extends RuntimeException {
        private final int tierRequired;
        private final int currentTier;

        public SlotLockedException(int tierRequired, int currentTier) {
            super("slot locked: requires tier " + tierRequired
                    + ", island tier " + currentTier);
            this.tierRequired = tierRequired;
            this.currentTier = currentTier;
        }

        public int getTierRequired() { return tierRequired; }
        public int getCurrentTier() { return currentTier; }
    }

    /** 409 — slot đã có vật phẩm khác; client DELETE trước hoặc dùng slot khác. */
    public static class SlotOccupiedException extends RuntimeException {
        public SlotOccupiedException(UUID slotId) {
            super("slot already occupied: " + slotId);
        }
    }

    /** 404 — slot_id không nằm trong catalog (hoặc sai layout). */
    public static class SlotNotFoundException extends RuntimeException {
        public SlotNotFoundException(UUID slotId) {
            super("island slot not found: " + slotId);
        }
    }

    /** 422 — upgrade nhưng required_completed_events chưa đạt. */
    public static class IslandUpgradeNotEligibleException
            extends RuntimeException {
        private final int targetTier;
        private final int requiredEvents;
        private final long currentEvents;

        public IslandUpgradeNotEligibleException(int targetTier,
                                                 int requiredEvents,
                                                 long currentEvents) {
            super("upgrade to tier " + targetTier + " requires "
                    + requiredEvents + " completed events, user has "
                    + currentEvents);
            this.targetTier = targetTier;
            this.requiredEvents = requiredEvents;
            this.currentEvents = currentEvents;
        }

        public int getTargetTier() { return targetTier; }
        public int getRequiredEvents() { return requiredEvents; }
        public long getCurrentEvents() { return currentEvents; }
    }

    /**
     * 422 — upgrade nhưng Level tài khoản chưa đủ (ISLAND-01).
     * Trả thông tin rõ ràng để client hiển thị: cần level bao nhiêu, đang
     * ở level mấy — không đề cập số sự kiện hoàn thành.
     */
    public static class IslandUpgradeInsufficientLevelException
            extends RuntimeException {
        private final int targetTier;
        private final int requiredLevel;
        private final int currentLevel;
        private final long currentExp;
        private final long requiredExp;

        public IslandUpgradeInsufficientLevelException(int targetTier,
                                                       int requiredLevel,
                                                       int currentLevel,
                                                       long currentExp,
                                                       long requiredExp) {
            super("upgrade to tier " + targetTier + " requires level "
                    + requiredLevel + ", user is level " + currentLevel
                    + " (" + currentExp + " EXP, need " + requiredExp + ")");
            this.targetTier = targetTier;
            this.requiredLevel = requiredLevel;
            this.currentLevel = currentLevel;
            this.currentExp = currentExp;
            this.requiredExp = requiredExp;
        }

        public int getTargetTier()    { return targetTier; }
        public int getRequiredLevel() { return requiredLevel; }
        public int getCurrentLevel()  { return currentLevel; }
        public long getCurrentExp()   { return currentExp; }
        public long getRequiredExp()  { return requiredExp; }
    }

    /** 409 — expectedRevision lệch row_version (hai thiết bị ghi đồng thời). */
    public static class StaleIslandRevisionException extends RuntimeException {
        private final long expected;
        private final long actual;

        public StaleIslandRevisionException(long expected, long actual) {
            super("stale island revision: expected=" + expected
                    + " actual=" + actual);
            this.expected = expected;
            this.actual = actual;
        }

        public long getExpected() { return expected; }
        public long getActual() { return actual; }
    }

    /** 422 — item không có row island_shop_items hoặc price NULL/active=false. */
    public static class ItemNotForSaleException extends RuntimeException {
        public ItemNotForSaleException(UUID itemId) {
            super("item not for sale: " + itemId);
        }
    }

    /** 503 — island feature bị tắt (dauviet.island.enabled=false). */
    public static class FeatureDisabledException extends RuntimeException {
        public FeatureDisabledException() {
            super("island feature is disabled");
        }
    }

    /**
     * 503 — island_tier_policies hoặc account_level_thresholds không hợp lệ
     * hoặc thiếu cấu hình cho tier được yêu cầu (ISLAND-02).
     * Trả 503 để phân biệt rõ với 422 (user chưa đủ điều kiện): đây là lỗi
     * cấu hình phía server, không phải lỗi người dùng.
     */
    public static class IslandConfigurationInvalidException extends RuntimeException {
        private final int targetTier;

        public IslandConfigurationInvalidException(int targetTier) {
            super("island configuration invalid for tier upgrade to " + targetTier);
            this.targetTier = targetTier;
        }

        public int getTargetTier() { return targetTier; }
    }
}
