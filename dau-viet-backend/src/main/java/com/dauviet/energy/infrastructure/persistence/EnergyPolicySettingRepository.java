package com.dauviet.energy.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.energy.domain.EnergyPolicySetting;

/**
 * Đọc/ghi singleton energy_policy_settings (V49). Runtime đọc mỗi request
 * (không cache) để admin PUT có hiệu lực ngay — 1 row, select rẻ.
 */
public interface EnergyPolicySettingRepository
        extends JpaRepository<EnergyPolicySetting, Short> {

    /** Singleton row id=1 — Optional khi unit test không có Flyway seed. */
    @Query("SELECT s FROM EnergyPolicySetting s WHERE s.id = 1")
    Optional<EnergyPolicySetting> findSingleton();

    /**
     * Ghi đè singleton (lazy-create nếu chưa có) — admin PUT settings.
     * Dùng save() khi row đã tồn tại; insertIgnore chỉ cho path
     * bootstrap khi DB trống.
     */
    @org.springframework.data.jpa.repository.Modifying
    @Query(value = """
            INSERT INTO energy_policy_settings
                (id, enabled, max_energy, incorrect_penalty, recovery_amount,
                 recovery_interval_seconds, updated_at, updated_by, row_version)
            VALUES (1, :enabled, :maxEnergy, :incorrectPenalty,
                    :recoveryAmount, :recoveryIntervalSeconds, now(),
                    :updatedBy, 0)
            ON CONFLICT (id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("enabled") boolean enabled,
                     @Param("maxEnergy") int maxEnergy,
                     @Param("incorrectPenalty") int incorrectPenalty,
                     @Param("recoveryAmount") int recoveryAmount,
                     @Param("recoveryIntervalSeconds") int recoveryIntervalSeconds,
                     @Param("updatedBy") UUID updatedBy);
}
