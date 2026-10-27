package com.dauviet.island.application;

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
import com.dauviet.reward.application.AccountLevelService;
import com.dauviet.reward.domain.ItemCatalog;
import com.dauviet.reward.infrastructure.persistence.ItemCatalogRepository;
import com.dauviet.reward.infrastructure.persistence.UserInventoryRepository;

/**
 * Đảo Di Sản (ISLAND-BE-01, ISLAND-01, ISLAND-02): state đọc, upgrade,
 * đặt/gỡ decor.
 *
 * <p>Lazy-create đảo tier 1 lần đầu đọc/ghi (UserIslandRepository
 * .insertIgnore). Mọi write lock user_islands trước (PESSIMISTIC_WRITE) —
 * serialize toàn bộ mutation đảo của một user.
 *
 * <p>Tier eligibility (ISLAND-01+02): dựa theo Level tài khoản tính từ EXP.
 * Không dùng EVENT_COMPLETED. Nếu policy cho tier kế tiếp thiếu required_level
 * hoặc level_thresholds không hợp lệ → chặn nâng cấp an toàn.
 *
 * <p>Revision (ISLAND-02): mọi write thành công (place, remove khi có thay
 * đổi, upgrade) đều bumps row_version qua JPA @Version.
 * Place/remove tác động trực tiếp lên user_island_placements nhưng service
 * bump version bằng cách gọi islands.save(island) sau mỗi thao tác thành công.
 *
 * <p>Lock-order: user_islands → user_inventory. Service không chạm wallet.
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
    private final AccountLevelService levelService;
    private final Clock clock;
    private final boolean enabled;

    public IslandService(UserIslandRepository islands,
                         IslandSlotRepository slots,
                         UserIslandPlacementRepository placements,
                         IslandTierPolicyRepository policies,
                         UserInventoryRepository inventory,
                         ItemCatalogRepository catalog,
                         UserEventProgressRepository eventProgress,
                         AccountLevelService levelService,
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
        this.levelService = levelService;
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
        return buildFullResponse(island, userId, now);
    }

    /* ---------- POST /me/island/upgrade ---------- */

    /**
     * Nâng cấp lên tier kế tiếp đủ điều kiện (user-initiated, không tự
     * động). Eligibility kiểm tra theo Level tài khoản (ISLAND-01/02).
     * Nếu cấu hình Level hoặc Tier policy không hợp lệ → chặn an toàn.
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
            // Đã ở tier tối đa
            throw new IslandExceptions.IslandUpgradeNotEligibleException(
                    island.getTier() + 1, -1, completedEvents(userId));
        }
        // Lấy required_level từ policy — null là cấu hình chưa hợp lệ
        Integer requiredLevel = requiredLevelForStrict(nextTier, activePolicies);
        if (requiredLevel == null) {
            log.error("island upgrade blocked: island_tier_policies tier={} "
                    + "missing required_level in active config_version", nextTier);
            throw new IslandExceptions.IslandConfigurationInvalidException(nextTier);
        }
        // Kiểm tra Level tài khoản — từ chối nếu config Level không hợp lệ
        if (!levelService.hasValidConfiguration()) {
            log.error("island upgrade blocked: account_level_thresholds "
                    + "configuration invalid or missing");
            throw new IslandExceptions.IslandConfigurationInvalidException(nextTier);
        }
        long exp = levelService.totalExp(userId);
        int currentLevel = levelService.levelForExp(exp);
        if (currentLevel < requiredLevel) {
            long requiredExp = levelService.minExpForLevel(requiredLevel);
            // requiredExp = -1 nếu level không có trong bảng ngưỡng
            // → vẫn chặn vì currentLevel < requiredLevel đã là đủ
            throw new IslandExceptions.IslandUpgradeInsufficientLevelException(
                    nextTier, requiredLevel, currentLevel, exp,
                    requiredExp < 0 ? 0L : requiredExp);
        }
        island.upgradeTo(nextTier, now);
        islands.save(island); // bumps @Version (row_version)
        log.info("island upgraded user={} tier={} level={} exp={}",
                userId, nextTier, currentLevel, exp);
        return buildFullResponse(island, userId, now);
    }

    /* ---------- PUT /me/island/placements/{slotId} ---------- */

    /**
     * Đặt vật phẩm vào ô đất. Kiểm tra: slot tồn tại → layout đúng → đảo
     * đủ tier → item tồn tại → user sở hữu → placeable → slot trống →
     * item chưa đặt ở slot khác → insert → bump revision.
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
        // Bảo đảm slot thuộc layout hiện tại của user
        if (!slot.getLayoutCode().equals(island.getLayoutCode())) {
            throw new IslandExceptions.SlotNotFoundException(slotId);
        }
        if (slot.getTierRequired() > island.getTier()) {
            throw new IslandExceptions.SlotLockedException(
                    slot.getTierRequired(), island.getTier());
        }
        ItemCatalog item = catalog.findById(req.itemId())
                .orElseThrow(() ->
                        new IslandExceptions.ItemNotOwnedException(req.itemId()));
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
        // Bump revision — place thành công luôn tăng row_version
        island.touch(now);
        islands.save(island);
        log.info("island placement user={} slot={} item={}",
                userId, slotId, req.itemId());
        return buildFullResponse(island, userId, now);
    }

    /* ---------- DELETE /me/island/placements/{slotId} ---------- */

    /**
     * Gỡ vật phẩm khỏi ô đất. Bump revision chỉ khi có row thực sự bị xóa.
     * Slot trống → no-op, revision không thay đổi.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public IslandResponse removePlacement(UUID userId, UUID slotId,
                                          Long expectedRevision) {
        requireEnabled();
        Instant now = Instant.now(clock);
        UserIsland island = lockIsland(userId, now);
        checkRevision(island, expectedRevision);
        int removed = placements.deleteByUserIdAndSlotId(userId, slotId);
        if (removed > 0) {
            // Bump revision — remove thực sự làm thay đổi trạng thái đảo
            island.touch(now);
            islands.save(island);
            log.info("island placement removed user={} slot={}", userId, slotId);
        }
        return buildFullResponse(island, userId, now);
    }

    /* ---------- internals ---------- */

    private void requireEnabled() {
        if (!enabled) throw new IslandExceptions.FeatureDisabledException();
    }

    private UserIsland ensureIsland(UUID userId, Instant now) {
        islands.insertIgnore(userId, now);
        return islands.findById(userId)
                .orElseThrow(() -> new IllegalStateException(
                        "user_islands insert lost for " + userId));
    }

    private UserIsland lockIsland(UUID userId, Instant now) {
        islands.insertIgnore(userId, now);
        return islands.findForUpdate(userId)
                .orElseThrow(() -> new IllegalStateException(
                        "user_islands insert lost for " + userId));
    }

    private void checkRevision(UserIsland island, Long expectedRevision) {
        if (expectedRevision != null
                && !expectedRevision.equals(island.getRowVersion())) {
            throw new IslandExceptions.StaleIslandRevisionException(
                    expectedRevision, island.getRowVersion());
        }
    }

    private long completedEvents(UUID userId) {
        return eventProgress.countDistinctEventsByMilestone(userId,
                "EVENT_COMPLETED");
    }

    private Integer nextTierOf(int currentTier,
                               List<IslandTierPolicy> activePolicies) {
        return activePolicies.stream()
                .map(IslandTierPolicy::getTier)
                .filter(t -> t > currentTier)
                .min(Integer::compareTo)
                .orElse(null);
    }

    private int maxTierOf(List<IslandTierPolicy> activePolicies) {
        return activePolicies.stream()
                .mapToInt(IslandTierPolicy::getTier)
                .max()
                .orElse(1); // fallback an toàn nếu policy rỗng
    }

    /**
     * Level yêu cầu của tier theo policy. Trả null nếu required_level chưa
     * được set (cấu hình cũ hoặc cấu hình chưa hợp lệ). Không fallback sang
     * 1 — caller phải chặn upgrade khi nhận null.
     */
    private Integer requiredLevelForStrict(int tier,
                                           List<IslandTierPolicy> activePolicies) {
        return activePolicies.stream()
                .filter(p -> p.getTier() == tier)
                .map(IslandTierPolicy::getRequiredLevel)
                .findFirst()
                .orElse(null);
    }

    private int requiredEventsFor(int tier,
                                  List<IslandTierPolicy> activePolicies) {
        return activePolicies.stream()
                .filter(p -> p.getTier() == tier)
                .map(IslandTierPolicy::getRequiredCompletedEvents)
                .findFirst()
                .orElse(Integer.MAX_VALUE);
    }

    private int slotCountFor(int tier, List<IslandTierPolicy> activePolicies) {
        return activePolicies.stream()
                .filter(p -> p.getTier() == tier)
                .map(IslandTierPolicy::getSlotCount)
                .findFirst()
                .orElse(0);
    }

    private Map<UUID, ItemCatalog> catalogOf(List<UUID> itemIds) {
        if (itemIds.isEmpty()) return Map.of();
        return catalog.findAllById(itemIds).stream()
                .collect(Collectors.toMap(ItemCatalog::getId,
                        Function.identity()));
    }

    /**
     * Build full response sau bất kỳ thao tác nào — đọc lại state hiện tại
     * của island (bao gồm row_version đã flush sau save).
     */
    private IslandResponse buildFullResponse(UserIsland island, UUID userId,
                                             Instant now) {
        List<IslandSlot> layout = slots.findByLayoutCodeOrderBySlotIndex(
                island.getLayoutCode());
        List<UserIslandPlacement> placed = placements.findByUserId(userId);
        Map<UUID, UserIslandPlacement> bySlot = placed.stream()
                .collect(Collectors.toMap(UserIslandPlacement::getSlotId,
                        Function.identity()));
        Map<UUID, ItemCatalog> items = catalogOf(placed.stream()
                .map(UserIslandPlacement::getItemId).toList());
        long exp = levelService.totalExp(userId);
        int currentLevel = levelService.levelForExp(exp);
        long eventsCompleted = completedEvents(userId);
        List<IslandTierPolicy> activePolicies = policies.findActivePolicies();
        int maxTier = maxTierOf(activePolicies);
        Integer nextTier = nextTierOf(island.getTier(), activePolicies);
        return buildResponse(island, layout, bySlot, items,
                exp, currentLevel, eventsCompleted,
                activePolicies, nextTier, maxTier, now);
    }

    private IslandResponse buildResponse(UserIsland island,
            List<IslandSlot> layout,
            Map<UUID, UserIslandPlacement> bySlot,
            Map<UUID, ItemCatalog> items,
            long currentExp,
            int currentLevel,
            long eventsCompleted,
            List<IslandTierPolicy> activePolicies,
            Integer nextTier,
            int maxTier,
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

        int nextRequiredEvents = nextTier == null ? -1
                : requiredEventsFor(nextTier, activePolicies);
        int nextSlots = nextTier == null ? 0
                : slotCountFor(nextTier, activePolicies);

        // requiredLevel từ policy (null = cấu hình chưa set → canUpgrade=false)
        Integer nextTierRequiredLevel = nextTier == null ? null
                : requiredLevelForStrict(nextTier, activePolicies);
        Long nextTierRequiredExp = null;
        if (nextTierRequiredLevel != null) {
            long minExp = levelService.minExpForLevel(nextTierRequiredLevel);
            nextTierRequiredExp = minExp >= 0 ? minExp : null;
        }

        // canUpgrade: chỉ true khi có level config hợp lệ VÀ đủ level
        boolean canUpgrade = nextTier != null
                && nextTierRequiredLevel != null
                && levelService.hasValidConfiguration()
                && currentLevel >= nextTierRequiredLevel;

        return new IslandResponse(
                island.getTier(), maxTier, island.getRowVersion(),
                eventsCompleted,
                nextTier, nextRequiredEvents, nextSlots, canUpgrade,
                island.getUpgradedAt(), slotViews, now,
                currentExp, currentLevel, nextTierRequiredLevel,
                nextTierRequiredExp);
    }
}
