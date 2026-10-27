package com.dauviet.shop.application;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.island.domain.IslandShopItem;
import com.dauviet.island.infrastructure.persistence.IslandShopItemRepository;
import com.dauviet.reward.domain.ItemCatalog;
import com.dauviet.reward.infrastructure.persistence.ItemCatalogRepository;
import com.dauviet.shop.api.dto.AdminIslandShopDtos.AdminShopOfferResponse;
import com.dauviet.shop.api.dto.AdminIslandShopDtos.CreateShopOfferRequest;
import com.dauviet.shop.api.dto.AdminIslandShopDtos.UpdateShopOfferRequest;

/**
 * Dịch vụ quản trị Cửa hàng Đảo Di Sản (ISLAND-05 Part C).
 * Giữ tách biệt rõ:
 * - ItemCatalog: định nghĩa vật phẩm
 * - IslandShopItem: chính sách thương mại (giá Điểm Sử Ký, bật/tắt bán, thứ tự)
 * - UserInventory: quyền sở hữu của người học (không bao giờ thu hồi khi tắt bán/gỡ offer)
 */
@Service
public class AdminIslandShopService {

    private final IslandShopItemRepository shopItems;
    private final ItemCatalogRepository catalog;

    public AdminIslandShopService(IslandShopItemRepository shopItems,
                                  ItemCatalogRepository catalog) {
        this.shopItems = shopItems;
        this.catalog = catalog;
    }

    @Transactional(readOnly = true)
    public List<AdminShopOfferResponse> listOffers() {
        List<IslandShopItem> offers = shopItems.findAllOrdered();
        Map<UUID, ItemCatalog> itemsById = catalog.findAllById(
                offers.stream().map(IslandShopItem::getItemId).toList())
                .stream()
                .collect(Collectors.toMap(ItemCatalog::getId, Function.identity()));
        return offers.stream()
                .map(offer -> {
                    ItemCatalog item = itemsById.get(offer.getItemId());
                    if (item == null) return null;
                    return toResponse(offer, item);
                })
                .filter(java.util.Objects::nonNull)
                .toList();
    }

    @Transactional(readOnly = true)
    public AdminShopOfferResponse getOffer(UUID itemId) {
        IslandShopItem offer = shopItems.findByItemId(itemId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Island shop offer not found for item: " + itemId));
        ItemCatalog item = catalog.findById(itemId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Catalog item not found: " + itemId));
        return toResponse(offer, item);
    }

    @Transactional
    public AdminShopOfferResponse createOffer(CreateShopOfferRequest req) {
        UUID itemId = req.itemId();
        ItemCatalog item = catalog.findById(itemId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Catalog item not found: " + itemId));
        if (shopItems.findByItemId(itemId).isPresent()) {
            throw new IllegalArgumentException(
                    "Vật phẩm '" + item.getCode() + "' đã có trong Cửa hàng Đảo Di Sản.");
        }
        validateCatalogEligibility(item, Boolean.TRUE.equals(req.active()));
        validatePricePoints(req.pricePoints());

        int sortOrder = req.sortOrder() != null
                ? req.sortOrder()
                : nextSortOrder();
        boolean active = req.active() != null ? req.active() : true;

        IslandShopItem created = IslandShopItem.create(
                itemId, req.pricePoints(), active, sortOrder);
        shopItems.saveAndFlush(created);
        return toResponse(created, item);
    }

    @Transactional
    public AdminShopOfferResponse updateOffer(UUID itemId,
                                              UpdateShopOfferRequest req) {
        IslandShopItem offer = shopItems.findByItemId(itemId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Island shop offer not found for item: " + itemId));
        ItemCatalog item = catalog.findById(itemId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Catalog item not found: " + itemId));

        boolean nextActive = req.active() != null ? req.active() : offer.isActive();
        validateCatalogEligibility(item, nextActive);

        Long nextPrice = offer.getPricePoints();
        if (Boolean.TRUE.equals(req.clearPrice())) {
            nextPrice = null;
        } else if (req.pricePoints() != null) {
            validatePricePoints(req.pricePoints());
            nextPrice = req.pricePoints();
        }

        int nextSortOrder = req.sortOrder() != null
                ? req.sortOrder()
                : offer.getSortOrder();

        offer.updateOffer(nextPrice, nextActive, nextSortOrder);
        shopItems.saveAndFlush(offer);
        return toResponse(offer, item);
    }

    @Transactional
    public void removeOffer(UUID itemId) {
        IslandShopItem offer = shopItems.findByItemId(itemId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Island shop offer not found for item: " + itemId));
        shopItems.delete(offer);
        shopItems.flush();
    }

    private void validateCatalogEligibility(ItemCatalog item, boolean offerActive) {
        if (!item.isPlaceable()) {
            throw new IllegalArgumentException(
                    "Chỉ vật phẩm có thể đặt lên Đảo Di Sản (placeable=true) mới được đưa vào Cửa hàng Đảo Di Sản V1.");
        }
        if (ItemCatalog.TYPE_DIGITAL_EDITION.equalsIgnoreCase(item.getItemType())
                || ItemCatalog.TYPE_COMMEMORATIVE_BADGE.equalsIgnoreCase(item.getItemType())) {
            throw new IllegalArgumentException(
                    "Loại vật phẩm " + item.getItemType() + " không thuộc danh mục bán tại Cửa hàng Đảo Di Sản V1.");
        }
        if (offerActive && !item.isActive()) {
            throw new IllegalArgumentException(
                    "Không thể mở bán vật phẩm '" + item.getCode() + "' khi vật phẩm đang bị ẩn trong Catalog.");
        }
    }

    private void validatePricePoints(Long pricePoints) {
        if (pricePoints != null && pricePoints <= 0) {
            throw new IllegalArgumentException(
                    "Giá Điểm Sử Ký phải là số nguyên dương (> 0) hoặc để trống (chưa mở bán).");
        }
    }

    private int nextSortOrder() {
        return shopItems.findAllOrdered().stream()
                .mapToInt(IslandShopItem::getSortOrder)
                .max()
                .orElse(0) + 10;
    }

    private AdminShopOfferResponse toResponse(IslandShopItem offer,
                                              ItemCatalog item) {
        boolean purchasable = offer.isForSale()
                && item.isActive()
                && item.isPlaceable();
        return new AdminShopOfferResponse(
                item.getId(),
                item.getCode(),
                item.getName(),
                item.getDescription(),
                item.getCategory(),
                item.getItemType(),
                item.getRarity(),
                item.getAssetId(),
                item.getRenderKey(),
                item.isPlaceable(),
                item.isActive(),
                offer.getPricePoints(),
                offer.isActive(),
                purchasable,
                offer.getSortOrder()
        );
    }
}
