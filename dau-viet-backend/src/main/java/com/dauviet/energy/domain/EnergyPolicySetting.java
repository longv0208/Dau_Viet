package com.dauviet.energy.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Singleton row (id = 1) lưu chính sách Thể lực toàn hệ thống (V49).
 * Admin chỉnh qua {@code PUT /api/v1/admin/energy/settings}; runtime đọc
 * mỗi request để áp rule mới ngay lập tức — không cache trong service.
 *
 * <p>Khi chưa có row (unit test không chạy Flyway), EnergyService fallback
 * về {@link com.dauviet.energy.application.EnergyProperties}.
 */
@Entity
@Table(name = "energy_policy_settings")
public class EnergyPolicySetting {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private Short id;

    @Column(name = "enabled", nullable = false)
    private boolean enabled;

    @Column(name = "max_energy", nullable = false)
    private int maxEnergy;

    @Column(name = "incorrect_penalty", nullable = false)
    private int incorrectPenalty;

    @Column(name = "recovery_amount", nullable = false)
    private int recoveryAmount;

    @Column(name = "recovery_interval_seconds", nullable = false)
    private int recoveryIntervalSeconds;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "updated_by")
    private UUID updatedBy;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public EnergyPolicySetting() {
    }

    public Short getId() { return id; }
    public boolean isEnabled() { return enabled; }
    public int getMaxEnergy() { return maxEnergy; }
    public int getIncorrectPenalty() { return incorrectPenalty; }
    public int getRecoveryAmount() { return recoveryAmount; }
    public int getRecoveryIntervalSeconds() { return recoveryIntervalSeconds; }
    public Instant getUpdatedAt() { return updatedAt; }
    public UUID getUpdatedBy() { return updatedBy; }
    public Long getRowVersion() { return rowVersion; }

    /**
     * Cập nhật toàn bộ trường chính sách — dùng khi Admin PUT settings.
     * Validation ràng buộc đã thực thi ở CHECK constraint DB; service
     * nên kiểm lại cho error message rõ.
     */
    public void apply(boolean enabled, int maxEnergy, int incorrectPenalty,
                      int recoveryAmount, int recoveryIntervalSeconds,
                      Instant updatedAt, UUID updatedBy) {
        this.enabled = enabled;
        this.maxEnergy = maxEnergy;
        this.incorrectPenalty = incorrectPenalty;
        this.recoveryAmount = recoveryAmount;
        this.recoveryIntervalSeconds = recoveryIntervalSeconds;
        this.updatedAt = updatedAt;
        this.updatedBy = updatedBy;
    }
}
