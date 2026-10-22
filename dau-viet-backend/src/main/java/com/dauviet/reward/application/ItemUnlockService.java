package com.dauviet.reward.application;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.infrastructure.persistence.UserEvidenceRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.reward.domain.ItemCatalog;
import com.dauviet.reward.domain.ItemUnlockRule;
import com.dauviet.reward.infrastructure.persistence.ItemCatalogRepository;
import com.dauviet.reward.infrastructure.persistence.ItemUnlockRuleRepository;
import com.dauviet.reward.infrastructure.persistence.UserInventoryRepository;

/**
 * Đánh giá điều kiện mở khóa vật phẩm (TASK-0023). Chạy TRONG transaction
 * của complete()/collect — vật phẩm cấp và dữ liệu kích hoạt commit/rollback
 * cùng nhau. Once-per-(user,item): ON CONFLICT DO NOTHING ở tầng DB, nên
 * evaluator không cần lock riêng; vật phẩm đã cấp không bao giờ bị thu
 * hồi khi rule thay đổi (user_inventory append-only).
 */
@Service
public class ItemUnlockService {

    private static final Logger log =
            LoggerFactory.getLogger(ItemUnlockService.class);

    private final ItemUnlockRuleRepository rules;
    private final ItemCatalogRepository items;
    private final UserInventoryRepository inventory;
    private final UserEvidenceRepository userEvidence;
    private final LearnerAttemptRepository attempts;

    public ItemUnlockService(ItemUnlockRuleRepository rules,
                             ItemCatalogRepository items,
                             UserInventoryRepository inventory,
                             UserEvidenceRepository userEvidence,
                             LearnerAttemptRepository attempts) {
        this.rules = rules;
        this.items = items;
        this.inventory = inventory;
        this.userEvidence = userEvidence;
        this.attempts = attempts;
    }

    /**
     * Đánh giá sau khi một attempt COMPLETED: rule LESSON_COMPLETED trỏ
     * đúng lesson này + mọi rule đếm (collection/lesson count thay đổi
     * sau mỗi completion). Gọi trong doComplete() sau grantFirstCompletion.
     *
     * @return item vừa được cấp trong lần đánh giá này (để enrich result)
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public List<ItemCatalog> evaluateAfterLessonCompletion(
            UUID userId, UUID lessonId, UUID attemptId) {
        List<ItemUnlockRule> candidates = new ArrayList<>(
                rules.findActiveLessonCompletedRules(lessonId));
        candidates.addAll(rules.findActiveCountedRules());
        return grantSatisfied(userId, candidates, lessonId, attemptId);
    }

    /**
     * Đánh giá sau khi EVIDENCE_SELECT collect được chấp nhận: chỉ cần
     * COLLECTION_COUNT (lesson count không đổi trong submit). Gọi trong
     * cùng transaction của submit, sau insertIgnore của recorder.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public List<ItemCatalog> evaluateAfterEvidenceCollected(
            UUID userId, UUID lessonId, UUID attemptId) {
        List<ItemUnlockRule> candidates = rules.findActiveCountedRules()
                .stream()
                .filter(r -> ItemUnlockRule.TYPE_COLLECTION_COUNT
                        .equals(r.getRuleType()))
                .toList();
        return grantSatisfied(userId, candidates, lessonId, attemptId);
    }

    /* ---------- internals ---------- */

    private List<ItemCatalog> grantSatisfied(UUID userId,
                                             List<ItemUnlockRule> candidates,
                                             UUID lessonId, UUID attemptId) {
        if (candidates.isEmpty()) return List.of();
        Map<UUID, ItemCatalog> catalog = items.findAllById(
                candidates.stream().map(ItemUnlockRule::getItemId).toList())
                .stream().collect(Collectors.toMap(
                        ItemCatalog::getId, Function.identity()));
        List<ItemCatalog> granted = new ArrayList<>();
        for (ItemUnlockRule rule : candidates) {
            ItemCatalog item = catalog.get(rule.getItemId());
            if (item == null || !item.isActive()) continue;
            if (!satisfied(userId, rule)) continue;
            int inserted = inventory.insertIgnore(userId, item.getId(),
                    rule.getRuleType(), lessonId, attemptId);
            if (inserted > 0) {
                granted.add(item);
                log.info("item unlocked user={} item={} rule={} lesson={}",
                        userId, item.getCode(), rule.getRuleType(), lessonId);
            }
        }
        return granted;
    }

    private boolean satisfied(UUID userId, ItemUnlockRule rule) {
        return switch (rule.getRuleType()) {
            case ItemUnlockRule.TYPE_LESSON_COMPLETED ->
                    // Được gọi đúng sau complete của lesson rule trỏ tới —
                    // rule.lessonId đã khớp ở query candidates.
                    true;
            case ItemUnlockRule.TYPE_COLLECTION_COUNT ->
                    userEvidence.countDistinctEvidence(userId)
                            >= rule.getThreshold();
            case ItemUnlockRule.TYPE_LESSON_COUNT ->
                    attempts.countDistinctCompletedLessons(userId)
                            >= rule.getThreshold();
            default -> false;
        };
    }
}
