package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.island.domain.IslandSlot;

/**
 * Catalog ô đất của layout đảo (V32) — read-only reference data.
 */
public interface IslandSlotRepository extends JpaRepository<IslandSlot, UUID> {

    /** Toàn bộ slot của một layout, theo thứ tự hiển thị. */
    List<IslandSlot> findByLayoutCodeOrderBySlotIndex(String layoutCode);
}
