package com.dauviet.island.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.island.api.dto.IslandPlacementRequest;
import com.dauviet.island.api.dto.IslandResponse;
import com.dauviet.island.domain.IslandExceptions;
import com.dauviet.island.domain.IslandSlot;
import com.dauviet.island.domain.IslandTierPolicy;
import com.dauviet.island.domain.UserIsland;
import com.dauviet.island.domain.UserIslandPlacement;
import com.dauviet.island.infrastructure.persistence.IslandSlotRepository;
import com.dauviet.island.infrastructure.persistence.IslandTierPolicyRepository;
import com.dauviet.island.infrastructure.persistence.UserIslandPlacementRepository;
import com.dauviet.island.infrastructure.persistence.UserIslandRepository;
import com.dauviet.reward.domain.ItemCatalog;
import com.dauviet.reward.infrastructure.persistence.ItemCatalogRepository;
import com.dauviet.reward.infrastructure.persistence.UserInventoryRepository;

/**
 * Đảo Di Sản (ISLAND-BE-01): state đọc, upgrade, đặt/gỡ decor.
 *
 * <p>Lazy-create đảo tier 1 lần đầu đọc/ghi (UserIslandRepository
 * .insertIgnore). Mọi write lock user_islands trước (PESSIMISTIC_WRITE) —
 * serialize toàn bộ mutation đảo của một user; placement kiểm tra
 * SLOT_LOCKED/SLOT_OCCUPIED/ITEM_* bên trong lock, không race hai thiết bị.
 *
 * <p>expectedRevision: client gửi user_islands.row_version đã đọc; lệch
 * → 409 STALE_ISLAND_REVISION — hai thiết bị ghi tuần tự phát hiện lệch
 * nhau, client reload rồi retry.
 *
 * <p>Tier eligibility: đếm user_event_progress milestone EVENT_COMPLETED —
 * chỉ sự kiện THẬT hoàn thành, không lesson đơn lẻ (task ISLAND-BE-01).
 * Upgrade user-initiated, KHÔNG auto-downgrade khi policy sau đổi
 * (tier mới chỉ áp dụng khi user chủ động nâng lại).
 *
 * <p>Lock-order: user_islands → (wallet_accounts khi mua — ShopService)
 * → user_inventory. Service này không chạm wallet; ShopService gọi
 * riêng và tự lock.
 */
@Service
public class IslandService {

    private static final Logger log =
            LoggerFactory.getLogger(IslandService.class);

    private final UserIslandRepository islands;
    private final IslandSlotRepository slots;
    private final UserIslandPlacementRepository placements;
    private final IslandTierPolicyRepository policies;
    private final UserInventoryRepository inventory;
    private final ItemCatalogRepository catalog;
    private final UserEventProgressRepository eventProgress;
    private final Clock clock;
    private final boolean enabled;

    public IslandService(UserIslandRepository islands,
                         IslandSlotRepository slots,
                         UserIslandPlacementRepository placements,
                         IslandTierPolicyRepository policies,
                         UserInventoryRepository inventory,
                         ItemCatalogRepository catalog,
                         UserEventProgressRepository eventProgress,
                         Clock clock,
                         @Value("${dauviet.island.enabled:true}")
                         boolean enabled) {
        this.islands = islands;
        this.slots = slots;
        this.placements = placements;
        this.policies = policies;
        this.inventory = inventory;
        this.catalog = catalog;
        this.eventProgress = eventProgress;
        this.clock = clock;
        this.enabled = enabled;
    }

    /* ---------- GET /me/island ---------- */

    /** Trạng thái đảo đầy đủ: tier, slots locked/unlocked, placements. */
    @Transactional
    public IslandResponse islandOf(UUID userId) {
        requireEnabled();
        Instant now = Instant.now(clock);
        UserIsland island = ensureIsland(userId, now);
        List<IslandSlot> layout = slots.findByLayoutCodeOrderBySlotIndex(
                island.getLayoutCode());
        List<UserIslandPlacement> placed = placements.findByUserId(userId);
        Map<UUID, UserIslandPlacement> bySlot = placed.stream()
                .collect(Collectors.toMap(UserIslandPlacement::getSlotId,
                        Function.identity()));
        Map<UUID, ItemCatalog> items = catalogOf(placed.stream()
                .map(UserIslandPlacement::getItemId).toList());
        long eventsCompleted = completedEvents(userId);
        List<IslandTierPolicy> activePolicies = policies.findActivePolicies();
        Integer nextTier = nextTierOf(island.getTier(), activePolicies);
        return buildResponse(island, layout, bySlot, items, eventsCompleted,
                activePolicies, nextTier, now);
    }

    /* ---------- POST /me/island/upgrade ---------- */

    /**
     * Nâng cấp lên tier kế tiếp đủ điều kiện (user-initiated, không tự
     * động). required_completed_events tính từ user_event_progress —
     * chỉ EVENT_COMPLETED thật, không mastery, không lesson.
     *
     * @return IslandResponse mới sau upgrade
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public IslandResponse upgrade(UUID userId, Long expectedRevision) {
        requireEnabled();
        Instant now = Instant.now(clock);
        UserIsland island = lockIsland(userId, now);
        checkRevision(island, expectedRevision);
        List<IslandTierPolicy> activePolicies = policies.findActivePolicies();
        Integer nextTier = nextTierOf(island.getTier(), activePolicies);
        if (nextTier == null) {
            // Đã ở tier tối đa theo config hiện tại — không phải lỗi nghiệp
            // vụ mà trạng thái; trả 422 để client biết không còn gì để nâng.
            throw new IslandExceptions.IslandUpgradeNotEligibleException(
                    island.getTier() + 1, -1, completedEvents(userId));
        }
        int required = requiredEventsFor(nextTier, activePolicies);
        long eventsCompleted = completedEvents(userId);
        if (eventsCompleted < required) {
            throw new IslandExceptions.IslandUpgradeNotEligibleException(
                    nextTier, required, eventsCompleted);
        }
        island.upgradeTo(nextTier, now);
        islands.save(island);
        log.info("island upgraded user={} tier={} events={}",
                userId, nextTier, eventsCompleted);
        return islandOf(userId);
    }

    /* ---------- PUT /me/island/placements/{slotId} ---------- */

    /**
     * Đặt vật phẩm vào ô đất. Kiểm tra theo thứ tự: slot tồn tại → đảo đủ
     * tier → item tồn tại trong catalog → user sở hữu → item placeable →
     * slot trống → item chưa đặt chỗ khác → insert.
     *
     * @return IslandResponse mới sau đặt
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public IslandResponse placeItem(UUID userId, UUID slotId,
                                    IslandPlacementRequest req) {
        requireEnabled();
        Instant now = Instant.now(clock);
        UserIsland island = lockIsland(userId, now);
        checkRevision(island, req.expectedRevision());
        IslandSlot slot = slots.findById(slotId)
                .orElseThrow(() ->
                        new IslandExceptions.SlotNotFoundException(slotId));
        if (slot.getTierRequired() > island.getTier()) {
            throw new IslandExceptions.SlotLockedException(
                    slot.getTierRequired(), island.getTier());
        }
        ItemCatalog item = catalog.findById(req.itemId())
                .orElseThrow(() ->
                        new IslandExceptions.ItemNotOwnedException(
                                req.itemId()));
        if (!inventory.existsByUserIdAndItemId(userId, req.itemId())) {
            throw new IslandExceptions.ItemNotOwnedException(req.itemId());
        }
        if (!item.isPlaceable()) {
            throw new IslandExceptions.ItemNotPlaceableException(req.itemId());
        }
        if (placements.findByUserIdAndSlotId(userId, slotId).isPresent()) {
            throw new IslandExceptions.SlotOccupiedException(slotId);
        }
        if (placements.findByUserIdAndItemId(userId, req.itemId()).isPresent()) {
            throw new IslandExceptions.ItemAlreadyOwnedException(req.itemId());
        }
        placements.insertIgnore(userId, slotId, req.itemId());
        log.info("island placement user={} slot={} item={}",
                userId, slotId, req.itemId());
        return islandOf(userId);
    }

    /* ---------- DELETE /me/island/placements/{slotId} ---------- */

    /** Gỡ vật phẩm khỏi ô đất; slot trống → no-op 204. */
    @Transactional(propagation = Propagation.REQUIRED)
    public IslandResponse removePlacement(UUID userId, UUID slotId,
                                          Long expectedRevision) {
        requireEnabled();
        Instant now = Instant.now(clock);
        UserIsland island = lockIsland(userId, now);
        checkRevision(island, expectedRevision);
        int removed = placements.deleteByUserIdAndSlotId(userId, slotId);
        if (removed > 0) {
            log.info("island placement removed user={} slot={}",
                    userId, slotId);
        }
        return islandOf(userId);
    }

    /* ---------- internals ---------- */

    private void requireEnabled() {
        if (!enabled) throw new IslandExceptions.FeatureDisabledException();
    }

    /** Lazy-create đảo tier 1 rồi đọc lại (race: insertIgnore trả 0 → row
     *  của kẻ thắng commit-visible trong tx này). */
    private UserIsland ensureIsland(UUID userId, Instant now) {
        islands.insertIgnore(userId, now);
        return islands.findById(userId)
                .orElseThrow(() -> new IllegalStateException(
                        "user_islands insert lost for " + userId));
    }

    /** Lock user_islands rồi lazy-create nếu chưa có (ghi trước, đọc sau). */
    private UserIsland lockIsland(UUID userId, Instant now) {
        islands.insertIgnore(userId, now);
        return islands.findForUpdate(userId)
                .orElseThrow(() -> new IllegalStateException(
                        "user_islands insert lost for " + userId));
    }

    /** expectedRevision null → không kiểm; lệch → 409 STALE_ISLAND_REVISION. */
    private void checkRevision(UserIsland island, Long expectedRevision) {
        if (expectedRevision != null
                && !expectedRevision.equals(island.getRowVersion())) {
            throw new IslandExceptions.StaleIslandRevisionException(
                    expectedRevision, island.getRowVersion());
        }
    }

    /** Số sự kiện THẬT đã EVENT_COMPLETED — nguồn eligibility duy nhất.
     *  Đếm DISTINCT event_id trên user_event_progress (GAME-05 đã có sẵn
     *  countDistinctEventsByMilestone — tái dùng, không thêm method mới). */
    private long completedEvents(UUID userId) {
        return eventProgress.countDistinctEventsByMilestone(userId,
                "EVENT_COMPLETED");
    }

    /** Tier kế tiếp trong config active; null = đã max. */
    private Integer nextTierOf(int currentTier,
                               List<IslandTierPolicy> policies) {
        return policies.stream()
                .map(IslandTierPolicy::getTier)
                .filter(t -> t > currentTier)
                .min(Integer::compareTo)
                .orElse(null);
    }

    private int requiredEventsFor(int tier, List<IslandTierPolicy> policies) {
        return policies.stream()
                .filter(p -> p.getTier() == tier)
                .map(IslandTierPolicy::getRequiredCompletedEvents)
                .findFirst()
                .orElse(Integer.MAX_VALUE);
    }

    private Map<UUID, ItemCatalog> catalogOf(List<UUID> itemIds) {
        if (itemIds.isEmpty()) return Map.of();
        return catalog.findAllById(itemIds).stream()
                .collect(Collectors.toMap(ItemCatalog::getId,
                        Function.identity()));
    }

    private IslandResponse buildResponse(UserIsland island,
            List<IslandSlot> layout,
            Map<UUID, UserIslandPlacement> bySlot,
            Map<UUID, ItemCatalog> items,
            long eventsCompleted,
            List<IslandTierPolicy> activePolicies,
            Integer nextTier,
            Instant now) {
        List<IslandResponse.SlotView> slotViews = layout.stream()
                .map(s -> {
                    UserIslandPlacement p = bySlot.get(s.getId());
                    ItemCatalog placed = p == null ? null
                            : items.get(p.getItemId());
                    return new IslandResponse.SlotView(
                            s.getId(), s.getSlotIndex(), s.getTierRequired(),
                            s.getTierRequired() <= island.getTier(),
                            s.getCoordX(), s.getCoordY(),
                            p == null ? null : p.getItemId(),
                            placed == null ? null : placed.getCode(),
                            placed == null ? null : placed.getRenderKey(),
                            p == null ? null : p.getPlacedAt());
                })
                .toList();
        int nextRequired = nextTier == null ? -1
                : requiredEventsFor(nextTier, activePolicies);
        int nextSlots = nextTier == null ? 0
                : slotCountFor(nextTier, activePolicies);
        boolean canUpgrade = nextTier != null
                && eventsCompleted >= nextRequired;
        return new IslandResponse(
                island.getTier(), island.getRowVersion(), eventsCompleted,
                nextTier, nextRequired, nextSlots, canUpgrade,
                island.getUpgradedAt(), slotViews, now);
    }

    private int slotCountFor(int tier, List<IslandTierPolicy> policies) {
        return policies.stream()
                .filter(p -> p.getTier() == tier)
                .map(IslandTierPolicy::getSlotCount)
                .findFirst()
                .orElse(0);
    }
}
