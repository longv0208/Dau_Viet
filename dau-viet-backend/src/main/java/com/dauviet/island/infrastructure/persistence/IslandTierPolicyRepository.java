package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.dauviet.island.domain.IslandTierPolicy;

/**
 * Truy cập island_tier_policies (V32, V38) — read-only; admin thay config
 * bằng migration/CMS sau.
 *
 * <p>Cơ chế active version: config_version cao nhất có ít nhất một row active
 * là version đang hiệu lực. Không trộn rows từ nhiều config_version — một
 * thời điểm chỉ có một bộ policy tier được dùng để xét eligibility.
 */
public interface IslandTierPolicyRepository
        extends JpaRepository<IslandTierPolicy, UUID> {

    /**
     * Tất cả tier của config_version active cao nhất, sort theo tier ASC.
     * Subquery MAX(config_version) đảm bảo không trộn nhiều version.
     */
    @Query("""
            SELECT p FROM IslandTierPolicy p
            WHERE p.active = true
              AND p.configVersion = (
                  SELECT MAX(p2.configVersion)
                  FROM IslandTierPolicy p2
                  WHERE p2.active = true
              )
            ORDER BY p.tier ASC
            """)
    List<IslandTierPolicy> findActivePolicies();
}
