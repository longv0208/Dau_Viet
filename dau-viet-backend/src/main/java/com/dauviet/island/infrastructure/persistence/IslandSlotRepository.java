package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.island.domain.IslandSlot;

/**
 * Catalog ô đất của layout đảo (V32 + V43) — read-only reference data.
 */
public interface IslandSlotRepository extends JpaRepository<IslandSlot, UUID> {

    /**
     * Toàn bộ slot của một layout (legacy query theo layout_code — tương thích
     * trước V43 backfill). Vẫn sử dụng trong IslandService.buildFullResponse
     * khi island chưa có layout_version_id.
     */
    List<IslandSlot> findByLayoutCodeOrderBySlotIndex(String layoutCode);

    /**
     * Toàn bộ slot của một layout version (V43), theo thứ tự hiển thị.
     * Dùng thay thế cho findByLayoutCode sau khi island có layout_version_id.
     */
    List<IslandSlot> findByLayoutVersionIdOrderBySlotIndex(UUID layoutVersionId);
}
