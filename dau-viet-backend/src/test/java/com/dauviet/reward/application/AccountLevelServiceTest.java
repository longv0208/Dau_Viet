package com.dauviet.reward.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.lang.reflect.Field;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.dauviet.reward.domain.AccountLevelThreshold;
import com.dauviet.reward.domain.RewardTransaction;
import com.dauviet.reward.infrastructure.persistence.AccountLevelThresholdRepository;
import com.dauviet.reward.infrastructure.persistence.RewardTransactionRepository;

/**
 * Unit test AccountLevelService (ISLAND-01).
 * Bảng ngưỡng: L1=0, L2=500, L3=1200, L4=2100, L5=3200.
 * Không dùng Spring context, không DB.
 */
class AccountLevelServiceTest {

    private RewardTransactionRepository rewards;
    private AccountLevelThresholdRepository thresholds;
    private AccountLevelService service;

    /** Các ngưỡng theo business rules ISLAND-01. */
    private static final List<AccountLevelThreshold> ACTIVE_THRESHOLDS =
            List.of(
                    threshold(1,    0),
                    threshold(2,  500),
                    threshold(3, 1200),
                    threshold(4, 2100),
                    threshold(5, 3200));

    @BeforeEach
    void setUp() {
        rewards = mock(RewardTransactionRepository.class);
        thresholds = mock(AccountLevelThresholdRepository.class);
        when(thresholds.findActiveLevels()).thenReturn(ACTIVE_THRESHOLDS);
        service = new AccountLevelService(rewards, thresholds);
    }

    @Test
    void level1_whenZeroExp() {
        assertThat(service.levelForExp(0)).isEqualTo(1);
    }

    @Test
    void level1_when499Exp() {
        assertThat(service.levelForExp(499)).isEqualTo(1);
    }

    @Test
    void level2_whenExactly500Exp() {
        assertThat(service.levelForExp(500)).isEqualTo(2);
    }

    @Test
    void level2_when1199Exp() {
        assertThat(service.levelForExp(1199)).isEqualTo(2);
    }

    @Test
    void level3_whenExactly1200Exp() {
        assertThat(service.levelForExp(1200)).isEqualTo(3);
    }

    @Test
    void level4_whenExactly2100Exp() {
        assertThat(service.levelForExp(2100)).isEqualTo(4);
    }

    @Test
    void level5_whenExactly3200Exp() {
        assertThat(service.levelForExp(3200)).isEqualTo(5);
    }

    @Test
    void level5_whenExpBeyondMaxThreshold() {
        // EXP lớn hơn ngưỡng Level 5 → giữ level 5 (không tự tạo level 6).
        assertThat(service.levelForExp(99_999)).isEqualTo(5);
    }

    @Test
    void fallbackLevel1_whenNoActiveThresholds() {
        when(thresholds.findActiveLevels()).thenReturn(List.of());
        assertThat(service.levelForExp(500)).isEqualTo(1);
    }

    @Test
    void totalExp_delegatesToRepository() {
        UUID userId = UUID.randomUUID();
        when(rewards.sumAmount(userId, RewardTransaction.TYPE_EXP))
                .thenReturn(1500L);
        assertThat(service.totalExp(userId)).isEqualTo(1500L);
    }

    @Test
    void minExpForLevel_returnsCorrectThreshold() {
        assertThat(service.minExpForLevel(1)).isEqualTo(0L);
        assertThat(service.minExpForLevel(2)).isEqualTo(500L);
        assertThat(service.minExpForLevel(3)).isEqualTo(1200L);
        assertThat(service.minExpForLevel(5)).isEqualTo(3200L);
    }

    @Test
    void minExpForLevel_returnsNegative1_whenLevelNotInConfig() {
        // Level 6 chưa có cấu hình → -1
        assertThat(service.minExpForLevel(6)).isEqualTo(-1L);
    }

    /* ---------- helpers ---------- */

    private static AccountLevelThreshold threshold(int level, long minExp) {
        try {
            AccountLevelThreshold t = new AccountLevelThreshold();
            setField(t, "id", UUID.randomUUID());
            setField(t, "configVersion", 1);
            setField(t, "level", level);
            setField(t, "minExp", minExp);
            setField(t, "active", true);
            return t;
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private static void setField(Object obj, String name, Object value)
            throws Exception {
        Field f = AccountLevelThreshold.class.getDeclaredField(name);
        f.setAccessible(true);
        f.set(obj, value);
    }
}
