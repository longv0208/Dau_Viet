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

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

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

    @PersistenceContext
    private EntityManager em;

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

    /**
     * TASK-0023 P1 — Reconciliation tường minh (admin-initiated): duyệt
     * mọi rule ACTIVE và cấp item cho learner đã đạt điều kiện theo
     * tiến độ lịch sử hiện có, mà không cần họ tương tác lại.
     *
     * - Chỉ cấp item ACTIVE; learner chưa đủ điều kiện không được cấp.
     * - ON CONFLICT (user_id, item_id) DO NOTHING → idempotent, gọi lại
     *   bao nhiêu lần cũng không nhân đôi, không đụng ownership cũ.
     * - acquisition_source = 'ADMIN_GRANT' — không nguỵ trang là unlock
     *   do attempt mới; source_attempt_id = NULL cho counted rules,
     *   trỏ một attempt COMPLETED thật của learner cho LESSON_COMPLETED
     *   (metadata truy vết, không phải "attempt kích hoạt mới").
     * - KHÔNG ghi reward_transactions (EXP/History Points) — reconcile
     *   chỉ bù inventory, không thưởng lại.
     *
     * Set-based per (rule → eligible users), an toàn với catalog nhỏ.
     *
     * @return số row user_inventory THỰC SỰ insert (không tính đã sở hữu)
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public int reconcileUnlocks() {
        List<ItemUnlockRule> active = rules.findActiveRules();
        if (active.isEmpty()) return 0;
        Map<UUID, ItemCatalog> catalog = items.findAllById(
                active.stream().map(ItemUnlockRule::getItemId).toList())
                .stream().collect(Collectors.toMap(
                        ItemCatalog::getId, Function.identity()));
        int granted = 0;
        for (ItemUnlockRule rule : active) {
            ItemCatalog item = catalog.get(rule.getItemId());
            // Item không active (hoặc đã xoá) → không cấp mới.
            if (item == null || !item.isActive()) continue;
            granted += switch (rule.getRuleType()) {
                case ItemUnlockRule.TYPE_LESSON_COMPLETED ->
                        grantLessonCompletedBacklog(rule);
                case ItemUnlockRule.TYPE_COLLECTION_COUNT ->
                        grantCountedBacklog(rule, "user_evidence", "evidence_id");
                case ItemUnlockRule.TYPE_LESSON_COUNT ->
                        grantCountedBacklog(rule, "learner_attempts la"
                              + " join lesson_versions lv"
                              + " on la.lesson_version_id = lv.id"
                              + " and la.status = 'COMPLETED'",
                              "lv.lesson_id");
                default -> 0;
            };
        }
        if (granted > 0) {
            log.info("inventory reconcile granted rows={}", granted);
        }
        return granted;
    }

    /**
     * LESSON_COMPLETED: learner có ít nhất một attempt COMPLETED trỏ
     * vào lesson rule trỏ (bất kỳ version — republish không mất tính).
     * Lấy attempt COMPLETED bất kỳ làm source_attempt_id để result
     * screen có thể truy vết; source_lesson_id = rule.lesson_id.
     */
    private int grantLessonCompletedBacklog(ItemUnlockRule rule) {
        return em.createNativeQuery("""
                INSERT INTO user_inventory
                    (id, user_id, item_id, acquired_at, acquisition_source,
                     source_lesson_id, source_attempt_id)
                SELECT gen_random_uuid(), x.user_id, :itemId, now(),
                       'ADMIN_GRANT', :lessonId, x.attempt_id
                FROM (
                    SELECT DISTINCT ON (la.user_id)
                           la.user_id, la.id AS attempt_id
                    FROM learner_attempts la
                    JOIN lesson_versions lv ON la.lesson_version_id = lv.id
                    WHERE lv.lesson_id = :lessonId AND la.status = 'COMPLETED'
                    ORDER BY la.user_id, la.completed_at ASC
                ) x
                ON CONFLICT (user_id, item_id) DO NOTHING
                """)
                .setParameter("itemId", rule.getItemId())
                .setParameter("lessonId", rule.getLessonId())
                .executeUpdate();
    }

    /**
     * COLLECTION_COUNT / LESSON_COUNT: learner đạt ngưỡng trên bảng đếm
     * tương ứng. `countSource` là FROM-clause sinh (user_id, key):
     * - user_evidence(user_id, evidence_id) → COUNT(DISTINCT evidence_id)
     * - learner_attempts×lesson_versions COMPLETED → COUNT(DISTINCT lesson_id)
     * source_attempt_id = NULL, source_lesson_id = NULL — không gắn sai
     * vào một attempt cụ thể vì đây là điều kiện tích luỹ.
     */
    private int grantCountedBacklog(ItemUnlockRule rule, String countSource,
                                    String distinctKey) {
        String sql = """
                INSERT INTO user_inventory
                    (id, user_id, item_id, acquired_at, acquisition_source,
                     source_lesson_id, source_attempt_id)
                SELECT gen_random_uuid(), agg.user_id, :itemId, now(),
                       'ADMIN_GRANT', NULL, NULL
                FROM (
                    SELECT user_id, COUNT(DISTINCT %s) AS n
                    FROM %s
                    GROUP BY user_id
                    HAVING COUNT(DISTINCT %s) >= :threshold
                ) agg
                ON CONFLICT (user_id, item_id) DO NOTHING
                """.formatted(distinctKey, countSource, distinctKey);
        return em.createNativeQuery(sql)
                .setParameter("itemId", rule.getItemId())
                .setParameter("threshold", rule.getThreshold())
                .executeUpdate();
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
