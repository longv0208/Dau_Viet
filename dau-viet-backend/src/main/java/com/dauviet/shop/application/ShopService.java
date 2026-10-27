package com.dauviet.shop.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.island.domain.IslandExceptions;
import com.dauviet.island.domain.IslandShopItem;
import com.dauviet.island.infrastructure.persistence.IslandShopItemRepository;
import com.dauviet.learning.application.IdempotencyService;
import com.dauviet.reward.domain.ItemCatalog;
import com.dauviet.reward.infrastructure.persistence.ItemCatalogRepository;
import com.dauviet.reward.infrastructure.persistence.UserInventoryRepository;
import com.dauviet.shop.api.dto.PurchaseRequest;
import com.dauviet.shop.api.dto.PurchaseResponse;
import com.dauviet.shop.api.dto.ShopItemResponse;
import com.dauviet.wallet.application.WalletService;

/**
 * Shop Đảo Di Sản (ISLAND-BE-01): listing + purchase flow.
 *
 * <p>Purchase flow (POINT-05/06/07, ITEM-07 atomic):
 * <pre>
 *   idempotency.execute(userId, "SHOP_PURCHASE", key, fingerprint, () -> {
 *     check ITEM_NOT_FOR_SALE / ITEM_ALREADY_OWNED (trước khi khóa ví);
 *     WalletService.debit(...)          ← lock wallet_accounts (FOR UPDATE)
 *     inventory.insertIgnoreV2(...)     ← SHOP_PURCHASE, UNIQUE(user,item)
 *     return response với balanceAfter
 *   })
 * </pre>
 *
 * <p>Mọi bước trong CÙNG một transaction: debit throw → rollback cả ownership
 * insert lẫn ledger row. cause_key = 'PURCHASE:' + idempotencyKey — một key
 * = một giao dịch duy nhất dù retry.
 *
 * <p>Lock-order: caller không giữ user_islands lock; WalletService tự
 * lock wallet_accounts → user_inventory qua insertIgnore (không cần lock).
 * Nếu về sau IslandService.placeItem gọi trong cùng tx thì lock đảo trước
 * (đảo → ví → inventory), một thứ tự duy nhất.
 *
 * <p>Feature flag dauviet.shop.enabled=false → GET listing vẫn 200,
 * POST purchase → 503 FEATURE_DISABLED.
 */
@Service
public class ShopService {

    private static final Logger log =
            LoggerFactory.getLogger(ShopService.class);

    /** Operation name trên idempotency_records. */
    static final String OP_SHOP_PURCHASE = "SHOP_PURCHASE";

    private final IslandShopItemRepository shopItems;
    private final ItemCatalogRepository catalog;
    private final UserInventoryRepository inventory;
    private final WalletService wallet;
    private final IdempotencyService idempotency;
    private final Clock clock;
    private final boolean enabled;

    public ShopService(IslandShopItemRepository shopItems,
                       ItemCatalogRepository catalog,
                       UserInventoryRepository inventory,
                       WalletService wallet,
                       IdempotencyService idempotency,
                       Clock clock,
                       @Value("${dauviet.shop.enabled:true}") boolean enabled) {
        this.shopItems = shopItems;
        this.catalog = catalog;
        this.inventory = inventory;
        this.wallet = wallet;
        this.idempotency = idempotency;
        this.clock = clock;
        this.enabled = enabled;
    }

    /* ---------- GET /shop/items ---------- */

    /** Listing shop: chỉ item có row island_shop_items (active + catalog join). */
    @Transactional(readOnly = true)
    public List<ShopItemResponse> items() {
        List<IslandShopItem> offers = shopItems.findAllActiveOrdered();
        Map<UUID, ItemCatalog> items = catalog.findAllById(
                offers.stream().map(IslandShopItem::getItemId).toList())
                .stream().collect(Collectors.toMap(ItemCatalog::getId,
                        Function.identity()));
        return offers.stream()
                .map(offer -> {
                    ItemCatalog item = items.get(offer.getItemId());
                    if (item == null || !item.isActive()) return null;
                    return new ShopItemResponse(
                            item.getId(), item.getCode(), item.getName(),
                            item.getDescription(), item.getCategory(),
                            item.getItemType(), item.getRarity(),
                            item.getAssetId(), item.getRenderKey(),
                            offer.getPricePoints(),
                            offer.isForSale() && item.isActive() && item.isPlaceable());
                })
                .filter(java.util.Objects::nonNull)
                .toList();
    }

    /* ---------- POST /me/shop/purchases ---------- */

    /**
     * Mua vật phẩm bằng Điểm Sử Ký — idempotent + atomic.
     *
     * @param userId         chủ ví (từ JWT)
     * @param req            itemId
     * @param idempotencyKey Idempotency-Key header — một key = một giao dịch
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public PurchaseResponse purchase(UUID userId, PurchaseRequest req,
                                     String idempotencyKey) {
        if (!enabled) throw new IslandExceptions.FeatureDisabledException();
        String fingerprint = "item=" + req.itemId();
        return idempotency.execute(userId, OP_SHOP_PURCHASE,
                idempotencyKey, fingerprint,
                () -> doPurchase(userId, req, idempotencyKey),
                PurchaseResponse.class);
    }

    /* ---------- internals ---------- */

    /**
     * Thân giao dịch mua — chạy trong tx của caller. Thứ tự:
     * 1. Tải offer + catalog → ITEM_NOT_FOR_SALE / ITEM_NOT_OWNED (404/422)
     * 2. Kiểm tra owned → ITEM_ALREADY_OWNED (409)
     * 3. WalletService.debit → INSUFFICIENT_FUNDS (409) hoặc commit
     * 4. user_inventory insertIgnoreV2 → 0 = race owned vừa commit → throw
     *    ITEM_ALREADY_OWNED để rollback debit (ISLAND-03 A2 fix).
     */
    private PurchaseResponse doPurchase(UUID userId, PurchaseRequest req,
                                        String idempotencyKey) {
        IslandShopItem offer = shopItems.findByItemId(req.itemId())
                .orElseThrow(() ->
                        new IslandExceptions.ItemNotForSaleException(
                                req.itemId()));
        ItemCatalog item = catalog.findById(req.itemId())
                .orElseThrow(() ->
                        new IslandExceptions.ItemNotForSaleException(
                                req.itemId()));
        if (!offer.isForSale() || !item.isActive() || !item.isPlaceable()) {
            throw new IslandExceptions.ItemNotForSaleException(req.itemId());
        }
        if (inventory.existsByUserIdAndItemId(userId, req.itemId())) {
            throw new IslandExceptions.ItemAlreadyOwnedException(req.itemId());
        }
        long price = offer.getPricePoints();
        String causeKey = "PURCHASE:" + idempotencyKey;
        long balanceAfter = wallet.debit(userId, price,
                com.dauviet.wallet.domain.WalletTransaction.REASON_SHOP_PURCHASE,
                causeKey, item.getId().toString());
        int granted = inventory.insertIgnoreV2(userId, item.getId(),
                "SHOP_PURCHASE", null, null, null, null, null, causeKey);
        if (granted == 0) {
            // UNIQUE(user,item) backstop: item vừa được grant trong tx khác
            // (race giữa check existsByUserIdAndItemId và insertIgnoreV2).
            // Ném exception để debit ở trên được rollback trong cùng transaction.
            // Idempotency layer ở tầng trên sẽ replay và trả ITEM_ALREADY_OWNED.
            log.warn("purchase grant conflict user={} item={} — rolling back debit",
                    userId, item.getCode());
            throw new IslandExceptions.ItemAlreadyOwnedException(item.getId());
        }
        log.info("purchase user={} item={} price={} balanceAfter={}",
                userId, item.getCode(), price, balanceAfter);
        return new PurchaseResponse(item.getId(), item.getCode(),
                item.getName(), price, balanceAfter,
                com.dauviet.wallet.domain.WalletAccount.CURRENCY_HISTORY_POINTS,
                Instant.now(clock));
    }
}
