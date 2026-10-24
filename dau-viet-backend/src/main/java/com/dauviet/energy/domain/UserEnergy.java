package com.dauviet.energy.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Trạng thái Thể lực hiện tại của một learner (V21): đúng một dòng/user
 * (PK = user_id, lazy-create lần đầu cần energy). row_version giữ optimistic
 * lock phụ; đường ghi chính serialize qua pessimistic lock
 * (UserEnergyRepository.findForUpdate) + INSERT ON CONFLICT cho khởi tạo —
 * hai thiết bị cùng user không bao giờ lost update hay tạo 2 dòng.
 */
@Entity
@Table(name = "user_energy")
public class UserEnergy {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "current_energy", nullable = false)
    private int currentEnergy;

    @Column(name = "last_recovery_at", nullable = false)
    private Instant lastRecoveryAt;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public UserEnergy() {
    }

    public UUID getUserId() { return userId; }
    public int getCurrentEnergy() { return currentEnergy; }
    public Instant getLastRecoveryAt() { return lastRecoveryAt; }

    /** New-user state (ENGY-01): full energy, recovery clock bắt đầu ngay. */
    public static UserEnergy start(UUID userId, int maxEnergy, Instant now) {
        UserEnergy e = new UserEnergy();
        e.userId = userId;
        e.currentEnergy = maxEnergy;
        e.lastRecoveryAt = now;
        return e;
    }

    /** Cộng lượng Thể lực (đã tính sẵn, caller clamp max). */
    public void credit(int amount, Instant newRecoveryAnchor) {
        this.currentEnergy += amount;
        if (newRecoveryAnchor != null) {
            this.lastRecoveryAt = newRecoveryAnchor;
        }
    }

    /** Trừ lượng Thể lực; caller đảm bảo amount <= current (clamp trước). */
    public void debit(int amount, Instant recoveryAnchor) {
        this.currentEnergy -= amount;
        if (recoveryAnchor != null) {
            this.lastRecoveryAt = recoveryAnchor;
        }
    }
}
