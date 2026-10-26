package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.dauviet.island.domain.IslandTierPolicy;

/**
 * Truy cập island_tier_policies (V32) — read-only; admin thay config bằng
 * migration/CMS sau (GAME-06 không nằm trong ISLAND-BE-01).
 */
public interface IslandTierPolicyRepository
        extends JpaRepository<IslandTierPolicy, UUID> {

    /** Tất cả tier của config version đang active, sort theo tier. */
    @Query("SELECT p FROM IslandTierPolicy p WHERE p.active = true "
         + "ORDER BY p.tier ASC")
    List<IslandTierPolicy> findActivePolicies();
}
