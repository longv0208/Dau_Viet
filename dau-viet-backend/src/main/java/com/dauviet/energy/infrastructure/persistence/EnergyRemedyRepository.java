package com.dauviet.energy.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.energy.domain.EnergyRemedy;

/**
 * Truy cập energy_remedies (V49). Sort theo sort_order + created_at để
 * Admin và learner nhìn thấy cùng thứ tự danh mục.
 */
public interface EnergyRemedyRepository
        extends JpaRepository<EnergyRemedy, UUID> {

    /** Listing admin — gồm cả inactive để quản lý. */
    @Query("SELECT r FROM EnergyRemedy r ORDER BY r.sortOrder ASC, "
            + "r.createdAt ASC")
    List<EnergyRemedy> findAllOrdered();

    /** Listing learner — chỉ remedies đang active. */
    @Query("SELECT r FROM EnergyRemedy r WHERE r.active = true "
            + "ORDER BY r.sortOrder ASC, r.createdAt ASC")
    List<EnergyRemedy> findAllActiveOrdered();

    /** Tra cứu theo code (case-insensitive để input mobile không lệch). */
    @Query("SELECT r FROM EnergyRemedy r WHERE UPPER(r.code) = UPPER(:code)")
    Optional<EnergyRemedy> findByCode(@Param("code") String code);

    /** Tra cứu theo code + phải đang active — dùng trong refill flow. */
    @Query("SELECT r FROM EnergyRemedy r WHERE UPPER(r.code) = UPPER(:code) "
            + "AND r.active = true")
    Optional<EnergyRemedy> findActiveByCode(@Param("code") String code);

    boolean existsByCodeIgnoreCase(String code);
}
