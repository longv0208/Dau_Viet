package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.UserIslandPlacement;
import com.dauviet.island.domain.UserIslandPlacementId;

/**
 * Truy cập user_island_placements (V32). Ghi qua {@link #insertIgnore}
 * (PK (user,slot) + UNIQUE(user,item) là backstop); service kiểm tra
 * SLOT_OCCUPIED/ITEM_ALREADY_OWNED trước, race loser đọc lại trạng thái
 * thắng qua select sau lock user_islands.
 */
public interface UserIslandPlacementRepository
        extends JpaRepository<UserIslandPlacement, UserIslandPlacementId> {

    /** Tất cả placement của user — join slot để sort theo slot_index. */
    List<UserIslandPlacement> findByUserId(UUID userId);

    Optional<UserIslandPlacement> findByUserIdAndSlotId(UUID userId,
                                                      UUID slotId);

    Optional<UserIslandPlacement> findByUserIdAndItemId(UUID userId,
                                                      UUID itemId);

    /** Đặt vật phẩm; đã chiếm slot hoặc đã đặt item → 0. */
    @Modifying
    @Query(value = """
            INSERT INTO user_island_placements
                (user_id, slot_id, item_id, placed_at)
            VALUES (:userId, :slotId, :itemId, now())
            ON CONFLICT (user_id, slot_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("slotId") UUID slotId,
                     @Param("itemId") UUID itemId);

    /** Gỡ item khỏi slot; không có gì → 0. */
    @Modifying
    @Query(value = """
            DELETE FROM user_island_placements
            WHERE user_id = :userId AND slot_id = :slotId
            """, nativeQuery = true)
    int deleteByUserIdAndSlotId(@Param("userId") UUID userId,
                                @Param("slotId") UUID slotId);
}
