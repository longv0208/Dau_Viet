package com.dauviet.reward.application;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.infrastructure.persistence.UserEvidenceRepository;
import com.dauviet.common.api.PageResponse;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonVersionRepository;
import com.dauviet.reward.api.dto.CatalogItemResponse;
import com.dauviet.reward.api.dto.InventoryItemResponse;
import com.dauviet.reward.api.dto.RewardSummaryResponse;
import com.dauviet.reward.api.dto.RewardTransactionResponse;
import com.dauviet.reward.domain.ItemCatalog;
import com.dauviet.reward.domain.ItemUnlockRule;
import com.dauviet.reward.domain.RewardTransaction;
import com.dauviet.reward.domain.UserInventoryItem;
import com.dauviet.reward.infrastructure.persistence.ItemCatalogRepository;
import com.dauviet.reward.infrastructure.persistence.ItemUnlockRuleRepository;
import com.dauviet.reward.infrastructure.persistence.RewardTransactionRepository;
import com.dauviet.reward.infrastructure.persistence.UserInventoryRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Bề mặt đọc phần thưởng/vật phẩm của learner hiện tại (TASK-0023).
 * Read-only — ghi chỉ từ RewardGrantService/ItemUnlockService trong
 * transaction runtime. Identity luôn từ JWT ở controller.
 */
@Service
public class RewardService {

    private final RewardTransactionRepository rewards;
    private final UserInventoryRepository inventory;
    private final ItemCatalogRepository items;
    private final ItemUnlockRuleRepository rules;
    private final LearnerAttemptRepository attempts;
    private final LessonVersionRepository versions;
    private final LessonRepository lessons;
    private final UserEvidenceRepository userEvidence;
    private final ObjectMapper mapper;

    public RewardService(RewardTransactionRepository rewards,
                         UserInventoryRepository inventory,
                         ItemCatalogRepository items,
                         ItemUnlockRuleRepository rules,
                         LearnerAttemptRepository attempts,
                         LessonVersionRepository versions,
                         LessonRepository lessons,
                         UserEvidenceRepository userEvidence,
                         ObjectMapper mapper) {
        this.rewards = rewards;
        this.inventory = inventory;
        this.items = items;
        this.rules = rules;
        this.attempts = attempts;
        this.versions = versions;
        this.lessons = lessons;
        this.userEvidence = userEvidence;
        this.mapper = mapper;
    }

    /** Tổng EXP / Điểm Lịch sử + số liệu phụ trợ cho màn hình hành trình. */
    @Transactional(readOnly = true)
    public RewardSummaryResponse summary(UUID userId) {
        return new RewardSummaryResponse(
                rewards.sumAmount(userId, RewardTransaction.TYPE_EXP),
                rewards.sumAmount(userId,
                        RewardTransaction.TYPE_HISTORY_POINTS),
                attempts.countDistinctCompletedLessons(userId),
                inventory.findByUserIdOrderByAcquiredAtDesc(userId).size());
    }

    /** Lịch sử bút toán — mới nhất trước; lessonId resolve qua attempt. */
    @Transactional(readOnly = true)
    public PageResponse<RewardTransactionResponse> transactions(
            UUID userId, Pageable pageable) {
        Page<RewardTransaction> page =
                rewards.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        Map<UUID, UUID> lessonByAttempt = resolveLessons(
                page.getContent().stream()
                        .map(RewardTransaction::getLearnerAttemptId)
                        .collect(Collectors.toSet()));
        return PageResponse.from(page.map(t -> new RewardTransactionResponse(
                t.getId(), t.getRewardType(), t.getAmount(), t.getReason(),
                lessonByAttempt.get(t.getLearnerAttemptId()),
                t.getCreatedAt())));
    }

    /** Vật phẩm đã sở hữu — mới nhất trước, kèm metadata catalog. */
    @Transactional(readOnly = true)
    public List<InventoryItemResponse> inventoryList(UUID userId) {
        List<UserInventoryItem> owned =
                inventory.findByUserIdOrderByAcquiredAtDesc(userId);
        Map<UUID, ItemCatalog> catalog = catalogOf(
                owned.stream().map(UserInventoryItem::getItemId).toList());
        return owned.stream().map(o -> {
            ItemCatalog item = catalog.get(o.getItemId());
            return new InventoryItemResponse(
                    o.getItemId(),
                    item == null ? null : item.getCode(),
                    item == null ? null : item.getName(),
                    item == null ? "" : item.getDescription(),
                    item == null ? null : item.getCategory(),
                    item == null ? null : item.getItemType(),
                    item == null ? null : item.getRarity(),
                    item == null ? null : item.getAssetId(),
                    o.getAcquiredAt(), o.getAcquisitionSource(),
                    o.getSourceLessonId());
        }).toList();
    }

    /**
     * Catalog cho learner = union item đang active + item learner đã sở
     * hữu (dedupe theo item id, sort theo code). Item admin tắt sau khi
     * learner đã sở hữu vẫn hiển thị với owned=true — ownership không bao
     * giờ bị thu hồi; item inactive không sở hữu vẫn ẩn.
     */
    @Transactional(readOnly = true)
    public List<CatalogItemResponse> catalog(UUID userId) {
        List<ItemCatalog> active = items.findByActiveTrueOrderByCodeAsc();
        List<UserInventoryItem> owned =
                inventory.findByUserIdOrderByAcquiredAtDesc(userId);
        Map<UUID, UserInventoryItem> ownedByItem = owned.stream()
                .collect(Collectors.toMap(UserInventoryItem::getItemId,
                        java.util.function.Function.identity()));
        // Union: active ∪ owned-inactive, dedupe theo itemId.
        Map<UUID, ItemCatalog> union = new java.util.LinkedHashMap<>();
        for (ItemCatalog i : active) union.put(i.getId(), i);
        for (UserInventoryItem o : owned) {
            union.computeIfAbsent(o.getItemId(),
                    id -> items.findById(id).orElse(null));
        }
        List<ItemCatalog> all = union.values().stream()
                .filter(java.util.Objects::nonNull)
                .sorted(java.util.Comparator.comparing(ItemCatalog::getCode))
                .toList();
        long collected = userEvidence.countDistinctEvidence(userId);
        long lessonsDone = attempts.countDistinctCompletedLessons(userId);
        Map<UUID, String> lessonTitles = lessonTitlesOf(
                all.stream()
                        .map(i -> rules.findByItemIdAndActiveTrue(i.getId())
                                .map(ItemUnlockRule::getLessonId).orElse(null))
                        .filter(java.util.Objects::nonNull)
                        .collect(Collectors.toSet()));
        return all.stream().map(i -> {
            UserInventoryItem ownedRow = ownedByItem.get(i.getId());
            return new CatalogItemResponse(
                    i.getId(), i.getCode(), i.getName(), i.getDescription(),
                    i.getCategory(), i.getItemType(), i.getRarity(),
                    i.getAssetId(), parse(i.getSourceMetadata()),
                    ownedRow != null,
                    ownedRow == null ? null : ownedRow.getAcquiredAt(),
                    requirement(i, lessonTitles, collected, lessonsDone));
        }).toList();
    }

    /**
     * Vật phẩm một attempt đã kích hoạt — enrich GET /attempts/{id}/result
     * (additive, không thay shape hiện tại).
     */
    @Transactional(readOnly = true)
    public List<InventoryItemResponse> itemsUnlockedByAttempt(UUID attemptId) {
        // Chỉ tính unlock THỜI GIAN THỰC: row ADMIN_GRANT ghi bởi reconcile
        // sau này trỏ source_attempt_id về một attempt đã hoàn thành trước
        // — không được coi là "vừa mở khóa trong lượt học đó".
        List<UserInventoryItem> rows =
                inventory.findRealtimeUnlocksByAttempt(attemptId);
        Map<UUID, ItemCatalog> catalog = catalogOf(
                rows.stream().map(UserInventoryItem::getItemId).toList());
        return rows.stream().map(o -> {
            ItemCatalog item = catalog.get(o.getItemId());
            return new InventoryItemResponse(
                    o.getItemId(),
                    item == null ? null : item.getCode(),
                    item == null ? null : item.getName(),
                    item == null ? "" : item.getDescription(),
                    item == null ? null : item.getCategory(),
                    item == null ? null : item.getItemType(),
                    item == null ? null : item.getRarity(),
                    item == null ? null : item.getAssetId(),
                    o.getAcquiredAt(), o.getAcquisitionSource(),
                    o.getSourceLessonId());
        }).toList();
    }

    /**
     * Bút toán thưởng gắn attempt — cho result screen hiển thị EXP/điểm
     * vừa nhận (đã grant từ trước thì vẫn trả row gốc, không bịa).
     */
    @Transactional(readOnly = true)
    public List<RewardTransactionResponse> rewardsOfAttempt(UUID attemptId) {
        List<RewardTransaction> rows =
                rewards.findByLearnerAttemptId(attemptId);
        Map<UUID, UUID> lessonByAttempt = resolveLessons(
                rows.stream().map(RewardTransaction::getLearnerAttemptId)
                        .collect(Collectors.toSet()));
        return rows.stream().map(t -> new RewardTransactionResponse(
                t.getId(), t.getRewardType(), t.getAmount(), t.getReason(),
                lessonByAttempt.get(t.getLearnerAttemptId()),
                t.getCreatedAt())).toList();
    }

    /* ---------- internals ---------- */

    private CatalogItemResponse.Requirement requirement(
            ItemCatalog item, Map<UUID, String> lessonTitles,
            long collected, long lessonsDone) {
        return rules.findByItemIdAndActiveTrue(item.getId())
                .map(r -> switch (r.getRuleType()) {
                    case ItemUnlockRule.TYPE_LESSON_COMPLETED ->
                            new CatalogItemResponse.Requirement(
                                    r.getRuleType(), r.getLessonId(),
                                    lessonTitles.get(r.getLessonId()),
                                    null, null);
                    case ItemUnlockRule.TYPE_COLLECTION_COUNT ->
                            new CatalogItemResponse.Requirement(
                                    r.getRuleType(), null, null,
                                    r.getThreshold(), collected);
                    case ItemUnlockRule.TYPE_LESSON_COUNT ->
                            new CatalogItemResponse.Requirement(
                                    r.getRuleType(), null, null,
                                    r.getThreshold(), lessonsDone);
                    default -> (CatalogItemResponse.Requirement) null;
                })
                .orElse(null);
    }

    private Map<UUID, UUID> resolveLessons(Set<UUID> attemptIds) {
        if (attemptIds.isEmpty()) return Map.of();
        Map<UUID, UUID> versionByAttempt = new HashMap<>();
        attempts.findAllById(attemptIds).forEach(a ->
                versionByAttempt.put(a.getId(), a.getLessonVersionId()));
        Map<UUID, UUID> lessonByVersion = new HashMap<>();
        versions.findAllById(versionByAttempt.values()).forEach(v ->
                lessonByVersion.put(v.getId(), v.getLessonId()));
        Map<UUID, UUID> out = new HashMap<>();
        versionByAttempt.forEach((attempt, version) ->
                out.put(attempt, lessonByVersion.get(version)));
        return out;
    }

    private Map<UUID, ItemCatalog> catalogOf(List<UUID> itemIds) {
        if (itemIds.isEmpty()) return Map.of();
        return items.findAllById(itemIds).stream()
                .collect(Collectors.toMap(ItemCatalog::getId,
                        java.util.function.Function.identity()));
    }

    private Map<UUID, String> lessonTitlesOf(Set<UUID> lessonIds) {
        if (lessonIds.isEmpty()) return Map.of();
        return lessons.findAllById(lessonIds).stream()
                .collect(Collectors.toMap(Lesson::getId, Lesson::getTitle));
    }

    private JsonNode parse(String json) {
        if (json == null || json.isBlank()) return null;
        try {
            return mapper.readTree(json);
        } catch (Exception e) {
            return null; // metadata chỉ phục vụ hiển thị
        }
    }
}
