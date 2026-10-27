package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.dauviet.island.domain.IslandShopItem;

/**
 * Chính sách bán của shop Đảo (V32) — read-only cho learner API.
 */
public interface IslandShopItemRepository
        extends JpaRepository<IslandShopItem, UUID> {

    /** Toàn bộ SKU đang bán/trưng bày, theo sort_order. */
    List<IslandShopItem> findByActiveTrueOrderBySortOrder();

    /** Lookup theo item — Optional.empty = không có row = ITEM_NOT_FOR_SALE. */
    Optional<IslandShopItem> findByItemId(UUID itemId);

    /**
     * Các SKU đang bán thực sự (active + có giá) — shop listing chỉ trả
     * đủ điều kiện mua; item price NULL vẫn list để client hiển thị
     * "sắp mở bán" nhưng nút mua disabled.
     */
    @Query("SELECT s FROM IslandShopItem s WHERE s.active = true "
         + "ORDER BY s.sortOrder ASC")
    List<IslandShopItem> findAllActiveOrdered();

    @Query("SELECT s FROM IslandShopItem s ORDER BY s.sortOrder ASC")
    List<IslandShopItem> findAllOrdered();
}
