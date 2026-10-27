package com.dauviet.island.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.UserIsland;

import jakarta.persistence.LockModeType;

/**
 * Truy cập user_islands (V32). Lazy-create đi qua {@link #insertIgnore} —
 * PK user_id + ON CONFLICT chặn duplicate khi hai request đầu đồng thời.
 * Mọi đường ghi serialize trên {@link #findForUpdate} (FOR UPDATE).
 */
public interface UserIslandRepository extends JpaRepository<UserIsland, UUID> {

    /** Tạo đảo tier 1 cho user mới; đã có → 0. */
    @Modifying
    @Query(value = """
            INSERT INTO user_islands (user_id, tier, layout_code, row_version,
                                      created_at, updated_at)
            VALUES (:userId, 1, 'heritage-v1', 0, :now, :now)
            ON CONFLICT (user_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("now") java.time.Instant now);

    /** Pessimistic lock — bắt buộc cho upgrade + mọi thao tác placement. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT i FROM UserIsland i WHERE i.userId = :userId")
    Optional<UserIsland> findForUpdate(@Param("userId") UUID userId);
}
