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
 * Truy cập user_islands (V32 + V44). Lazy-create đi qua {@link #insertIgnoreWithVersion} —
 * PK user_id + ON CONFLICT chặn duplicate khi hai request đầu đồng thời.
 * Mọi đường ghi serialize trên {@link #findForUpdate} (FOR UPDATE).
 */
public interface UserIslandRepository extends JpaRepository<UserIsland, UUID> {

    /**
     * Tạo đảo tier 1 cho user mới cùng layout_version_id đã pin nguyên tử;
     * đã có → 0. Không bao giờ tạo row với layout_version_id = null.
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_islands (user_id, tier, layout_code, layout_version_id,
                                      row_version, created_at, updated_at)
            VALUES (:userId, 1, :layoutCode, :layoutVersionId, 0, :now, :now)
            ON CONFLICT (user_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnoreWithVersion(@Param("userId") UUID userId,
                                @Param("layoutCode") String layoutCode,
                                @Param("layoutVersionId") UUID layoutVersionId,
                                @Param("now") java.time.Instant now);

    /** Pessimistic lock — bắt buộc cho upgrade + mọi thao tác placement. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT i FROM UserIsland i WHERE i.userId = :userId")
    Optional<UserIsland> findForUpdate(@Param("userId") UUID userId);
}
