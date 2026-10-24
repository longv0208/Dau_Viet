package com.dauviet.reward.application;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.collection.infrastructure.persistence.UserEvidenceRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;
import com.dauviet.reward.domain.ItemCatalog;
import com.dauviet.reward.domain.ItemUnlockRule;
import com.dauviet.reward.infrastructure.persistence.ItemCatalogRepository;
import com.dauviet.reward.infrastructure.persistence.ItemUnlockRuleRepository;
import com.dauviet.reward.infrastructure.persistence.UserInventoryRepository;

/**
 * Đánh giá + cấp vật phẩm (GAME-05 Rule Engine V2). Chạy TRONG transaction
 * của submit-collect / complete / event-milestone — vật phẩm cấp và dữ liệu
 * kích hoạt commit/rollback cùng nhau.
 *
 * Concurrency: per-user advisory lock (pg_advisory_xact_lock trên khoá
 * userId) tuần tự hoá hai submit-evidence/complete song song của cùng
 * learner — loser đánh giá lại trên trạng thái winner đã commit nên không
 * "bỏ lỡ" grant khi hai evidence liên tiếp đưa count qua ngưỡng. Lock
 * ordering: chỉ lấy khoá user-scope ở đây, khoá (user,event) của
 * EventMilestoneRecorder được lấy TRƯỚC trong doComplete (milestone trước
 * item) nên thứ tự nhất quán: attempt → event milestone → item.
 *
 * Once-per-(user,item): UNIQUE(user_id,item_id) + ON CONFLICT DO NOTHING
 * là backstop; vật phẩm đã cấp không bao giờ thu hồi khi rule đổi (rule
 * append-only — rule mới chỉ áp dụng cho grant mới, provenance cũ giữ
 * nguyên).
 */
@Service
public class ItemUnlockService {

    private static final Logger log =
            LoggerFactory.getLogger(ItemUnlockService.class);

    /** acquisition_source ghi cho grant realtime của evaluator v2. */
    static final String SOURCE_RULE_UNLOCK = "RULE_UNLOCK";
    /** acquisition_source ghi cho grant backfill reconcile (giữ semantics
     * ADMIN_GRANT cũ — test/dữ liệu V1 đã dựa vào nó). */
    static final String SOURCE_RECONCILE = "ADMIN_GRANT";

    private final ItemUnlockRuleRepository rules;
    private final ItemCatalogRepository items;
    private final UserInventoryRepository inventory;
    private final UserEvidenceRepository userEvidence;
    private final UserEventProgressRepository eventProgress;
    private final LearnerAttemptRepository attempts;
    private final LessonResultRepository lessonResults;
    private final ItemConditionParser parser;
    private final ItemRuleEvaluator evaluator;
    private final ObjectProvider<ItemUnlockService> selfProvider;

    @PersistenceContext
    private EntityManager em;

    public ItemUnlockService(ItemUnlockRuleRepository rules,
                             ItemCatalogRepository items,
                             UserInventoryRepository inventory,
                             UserEvidenceRepository userEvidence,
                             UserEventProgressRepository eventProgress,
                             LearnerAttemptRepository attempts,
                             LessonResultRepository lessonResults,
                             ItemConditionParser parser,
                             ItemRuleEvaluator evaluator,
                             ObjectProvider<ItemUnlockService> selfProvider) {
        this.rules = rules;
        this.items = items;
        this.inventory = inventory;
        this.userEvidence = userEvidence;
        this.eventProgress = eventProgress;
        this.attempts = attempts;
        this.lessonResults = lessonResults;
        this.parser = parser;
        this.evaluator = evaluator;
        this.selfProvider = selfProvider;
    }

    /**
     * Đánh giá sau khi EVIDENCE_SELECT collect được chấp nhận — trong cùng
     * tx của submit, sau insertIgnore của recorder. Chỉ leaf evidence-
     * scoped thay đổi, nhưng đánh giá mọi active rule có leaf evidence
     * (đơn giản + đúng: evaluator đọc lại count vừa flush).
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public List<ItemCatalog> evaluateAfterEvidenceCollected(
            UUID userId, UUID lessonId, UUID attemptId) {
        return evaluate(userId, lessonId, attemptId, null);
    }

    /**
     * Đánh giá sau khi attempt COMPLETED — gọi trong doComplete SAU
     * eventMilestones.recordIfEarned để leaf EVENT_* nhìn thấy milestone
     * vừa ghi trong cùng tx (đã sửa ordering bug V1).
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public List<ItemCatalog> evaluateAfterLessonCompletion(
            UUID userId, UUID lessonId, UUID attemptId) {
        return evaluate(userId, lessonId, attemptId, null);
    }

    /**
     * Đánh giá sau khi eventMilestones.recordIfEarned ghi milestone — cùng
     * tx doComplete, truyền eventId để log/source_event_id chính xác cho
     * rule event-scoped. Hiện gọi trong evaluateAfterLessonCompletion
     * (một điểm vào duy nhất sau milestone); giữ hàm riêng để trigger
     * milestone-only (ví dụ reconcile event) có entry point rõ ràng.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public List<ItemCatalog> evaluateAfterEventMilestone(
            UUID userId, UUID eventId) {
        return evaluate(userId, null, null, eventId);
    }

    /* ---------- core ---------- */

    /**
     * Đường đánh giá duy nhất: lock user → load active rules → build
     * context một lần → satisfied từng rule → insertIgnoreV2 với
     * provenance. Rule không parse được (dữ liệu cũ lệch grammar) bị
     * bỏ qua + log warn — không để một rule hỏng chặn cả grant cycle.
     */
    private List<ItemCatalog> evaluate(UUID userId, UUID lessonId,
                                       UUID attemptId, UUID eventId) {
        List<ItemUnlockRule> active = rules.findActiveRules();
        if (active.isEmpty()) return List.of();

        // Tuần tự hoá theo user: hai submit/complete song song không được
        // đánh giá đồng thời trên snapshot cũ — loser thấy ghi của winner
        // sau khi chờ lock (xact lock tự nhả khi tx kết thúc).
        em.createNativeQuery(
                "select pg_advisory_xact_lock(hashtextextended(:k, 0::bigint))")
                .setParameter("k", "item-unlock|" + userId)
                .getSingleResult();

        Map<UUID, ItemCatalog> catalog = items.findAllById(
                active.stream().map(ItemUnlockRule::getItemId).toList())
                .stream().collect(Collectors.toMap(
                        ItemCatalog::getId, Function.identity()));
        ItemRuleEvaluationContext ctx = new ItemRuleEvaluationContext(
                userId, userEvidence, eventProgress, attempts, lessonResults);

        List<ItemCatalog> granted = new ArrayList<>();
        for (ItemUnlockRule rule : active) {
            ItemCatalog item = catalog.get(rule.getItemId());
            if (item == null || !item.isActive()) continue;
            ItemCondition condition;
            try {
                condition = conditionOf(rule);
            } catch (ItemRuleException e) {
                // Rule trong DB lệch grammar (lỗi dữ liệu, không phải request
                // hiện tại) — bỏ qua item này thay vì làm hỏng cả submit.
                log.warn("item rule unparseable rule={} item={} err={}",
                        rule.getId(), item.getCode(), e.getMessage());
                continue;
            }
            // Seed audit: rule V1 đếm global cho item event-specific bị flag
            // needs-mapping → chặn grant MỚI tới khi admin publish rule v2
            // event-scoped minh định (không đoán eventId). Ownership cũ giữ.
            if (blockedByAudit(rule)) continue;
            if (!evaluator.satisfied(condition, ctx)) continue;
            int inserted = inventory.insertIgnoreV2(userId, item.getId(),
                    SOURCE_RULE_UNLOCK, lessonId, attemptId,
                    rule.getId(), rule.getRuleVersion(),
                    firstEventId(condition, eventId),
                    causeKey(rule, userId));
            if (inserted > 0) {
                granted.add(item);
                log.info("item unlocked user={} item={} rule={} v={}",
                        userId, item.getCode(), rule.getRuleType(),
                        rule.getRuleVersion());
            }
        }
        return granted;
    }

    /**
     * AST của rule: ưu tiên condition_json; khi null (row v1 ghi trực tiếp
     * bỏ qua normalize của V24, ví dụ test/seed thủ công) dựng AST tương
     * đương từ 3 cột phẳng — evaluator chỉ đọc AST, không nhánh rule_type.
     */
    private ItemCondition conditionOf(ItemUnlockRule rule) {
        String json = rule.getConditionJson();
        if (json == null || json.isBlank()) {
            json = legacyConditionJson(rule);
        }
        return parser.parse(json);
    }

    private String legacyConditionJson(ItemUnlockRule rule) {
        return switch (rule.getRuleType()) {
            case ItemUnlockRule.TYPE_LESSON_COMPLETED ->
                    "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\""
                            + rule.getLessonId() + "\"}";
            case ItemUnlockRule.TYPE_COLLECTION_COUNT,
                 ItemUnlockRule.TYPE_LESSON_COUNT ->
                    "{\"type\":\"" + rule.getRuleType()
                            + "\",\"threshold\":" + rule.getThreshold() + "}";
            default -> throw new ItemRuleException(
                    "rule has no condition and unknown ruleType: "
                            + rule.getRuleType());
        };
    }

    /**
     * 'needs-mapping' trong rule_metadata.audit = chờ rule v2 event-scoped.
     * Dùng CHUNG {@link ItemUnlockRule#isNeedsMapping} với catalog read
     * path (RewardService → status UNCONFIGURED) — grant path và read
     * path luôn đồng ý một rule có bị chặn hay không (FIX-1).
     */
    private boolean blockedByAudit(ItemUnlockRule rule) {
        return ItemUnlockRule.isNeedsMapping(rule.getRuleMetadata());
    }

    /** Event đầu tiên xuất hiện trong AST (provenance); null cho global. */
    private UUID firstEventId(ItemCondition c, UUID fallback) {
        UUID found = findEventId(c);
        return found != null ? found : fallback;
    }

    private UUID findEventId(ItemCondition c) {
        return switch (c) {
            case ItemCondition.Leaf l -> l.eventId();
            case ItemCondition.All a -> a.children().stream()
                    .map(this::findEventId).filter(java.util.Objects::nonNull)
                    .findFirst().orElse(null);
            case ItemCondition.Any a -> a.children().stream()
                    .map(this::findEventId).filter(java.util.Objects::nonNull)
                    .findFirst().orElse(null);
        };
    }

    /** cause_key ổn định theo (user,rule): retry/re-evaluate cùng rule không
     * ghi trùng; kết hợp UNIQUE(user,item) chặn double-grant. */
    private String causeKey(ItemUnlockRule rule, UUID userId) {
        return "item-rule|" + rule.getId() + "|" + userId;
    }

    /* ---------- reconcile / backfill ---------- */

    /**
     * Reconciliation tường minh (admin-initiated): đánh giá LẠI mọi rule
     * active bằng ĐÚNG evaluator realtime trên tập user ứng viên, rồi cấp
     * item còn thiếu. Idempotent — ON CONFLICT (user_id,item_id) +
     * cause_key; không ghi reward_transactions (không thưởng lại EXP/điểm).
     *
     * Candidate users: union các user có bất kỳ footprint liên quan
     * (user_evidence / completed attempts / user_event_progress) — KHÔNG
     * quét toàn bảng users. Với catalog nhỏ của MVP, tập này đủ chặt để
     * đánh giá per-user mà không N+1 (context cache per user).
     *
     * @return số row user_inventory THỰC SỰ insert
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public int reconcileUnlocks() {
        List<ParsedRule> evaluable = evaluableRules();
        if (evaluable.isEmpty()) return 0;
        int granted = 0;
        for (UUID userId : candidateUsers()) {
            granted += grantSatisfied(userId, evaluable);
        }
        if (granted > 0) {
            log.info("inventory reconcile granted rows={}", granted);
        }
        return granted;
    }

    /**
     * FIX-7: runner reconcile theo batch — vòng lặp keyset page trên
     * candidate users, mỗi trang một tx ngắn (REQUIRES_NEW trong
     * reconcileBatch), không giữ một tx xuyên suốt toàn bộ backfill.
     * Idempotent + an toàn re-run: chạy lại sau fail tiếp tục từ đầu mà
     * không double-grant (ON CONFLICT + cause_key). Trả số liệu tổng hợp
     * cho admin audit.
     *
     * @return {itemsGranted, usersScanned, batches}
     */
    public Map<String, Object> reconcileBatched(int batchSize) {
        int size = batchSize <= 0 ? 200 : Math.min(batchSize, 1000);
        int usersScanned = 0;
        int itemsGranted = 0;
        int batches = 0;
        UUID cursor = null;
        while (true) {
            List<UUID> page = candidateUsersPage(cursor, size);
            if (page.isEmpty()) break;
            itemsGranted += self().reconcileBatch(page);
            usersScanned += page.size();
            batches++;
            cursor = nextCandidateCursor(page);
            if (page.size() < size) break;
        }
        log.info("inventory reconcile batched users={} batches={} granted={}",
                usersScanned, batches, itemsGranted);
        return Map.of("itemsGranted", itemsGranted,
                "usersScanned", usersScanned, "batches", batches);
    }

    /**
     * Self-injection qua ObjectProvider — bắt buộc để lời gọi nội bộ
     * reconcileBatched → reconcileBatch đi QUA proxy và REQUIRES_NEW
     * thực sự mở tx mới (self-call trên `this` bỏ qua interceptor).
     */
    private ItemUnlockService self() {
        return selfProvider.getObject();
    }

    /**
     * FIX-7: đánh giá MỘT BATCH user (keyset page do runner tải) trong một
     * transaction ngắn — runner gọi với REQUIRES_NEW nên tx không giữ suốt
     * toàn bộ backfill. Cùng evaluator + cùng grant path với realtime và
     * reconcileUnlocks — single source, không nhánh semantics theo đường
     * chạy. Idempotent nhờ ON CONFLICT (user,item) + cause_key.
     *
     * @return số row user_inventory THỰC SỰ insert trong batch
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int reconcileBatch(java.util.Collection<UUID> userIds) {
        List<ParsedRule> evaluable = evaluableRules();
        if (evaluable.isEmpty()) return 0;
        int granted = 0;
        for (UUID userId : userIds) {
            granted += grantSatisfied(userId, evaluable);
        }
        return granted;
    }

    /**
     * Trang user ứng viên THEO KEYSET (FIX-7): keyset pagination bằng
     * `user_id > :after` — không OFFSET scan, không load toàn bộ id vào
     * bộ nhớ, mỗi trang là một query ngắn. UNION ba footprint rồi
     * DISTINCT + ORDER BY — an toàn re-run, deterministic.
     */
    @SuppressWarnings("unchecked")
    public List<UUID> candidateUsersPage(UUID after, int limit) {
        return em.createNativeQuery("""
                SELECT u.user_id FROM (
                    SELECT user_id FROM user_evidence
                    UNION
                    SELECT a.user_id FROM learner_attempts a
                    WHERE a.status = 'COMPLETED'
                    UNION
                    SELECT p.user_id FROM user_event_progress p
                ) u
                WHERE (CAST(:after AS uuid) IS NULL
                       OR u.user_id > CAST(:after AS uuid))
                ORDER BY u.user_id
                LIMIT :limit
                """)
                .setParameter("after", after)
                .setParameter("limit", limit)
                .getResultList();
    }

    /** Con trỏ keyset tiếp theo: user_id lớn nhất của trang vừa đọc. */
    public UUID nextCandidateCursor(List<UUID> page) {
        if (page.isEmpty()) return null;
        return page.get(page.size() - 1);
    }

    /** Lọc rule active còn đánh giá được (parse ok + không bị audit-flag). */
    private List<ParsedRule> evaluableRules() {
        List<ItemUnlockRule> active = rules.findActiveRules();
        if (active.isEmpty()) return List.of();
        Map<UUID, ItemCatalog> catalog = items.findAllById(
                active.stream().map(ItemUnlockRule::getItemId).toList())
                .stream().collect(Collectors.toMap(
                        ItemCatalog::getId, Function.identity()));
        List<ParsedRule> evaluable = new ArrayList<>();
        for (ItemUnlockRule rule : active) {
            ItemCatalog item = catalog.get(rule.getItemId());
            if (item == null || !item.isActive() || blockedByAudit(rule)) {
                continue;
            }
            try {
                evaluable.add(new ParsedRule(rule, item,
                        conditionOf(rule)));
            } catch (ItemRuleException e) {
                log.warn("reconcile skip unparseable rule={} err={}",
                        rule.getId(), e.getMessage());
            }
        }
        return evaluable;
    }

    /** Đánh giá + cấp item cho MỘT user trên bộ rule đã lọc sẵn. */
    private int grantSatisfied(UUID userId, List<ParsedRule> evaluable) {
        ItemRuleEvaluationContext ctx = new ItemRuleEvaluationContext(
                userId, userEvidence, eventProgress, attempts,
                lessonResults);
        int granted = 0;
        for (ParsedRule pr : evaluable) {
            if (!evaluator.satisfied(pr.condition(), ctx)) continue;
            // Provenance reconcile: rule trỏ một lesson cụ thể → ghi
            // source_lesson_id + một attempt COMPLETED của learner làm
            // metadata truy vết (không phải "attempt kích hoạt mới" —
            // acquisition_source ADMIN_GRANT đã phân biệt, và
            // findRealtimeUnlocksByAttempt loại ADMIN_GRANT khỏi result
            // screen). Rule đếm/event-scope → null (điều kiện tích luỹ).
            UUID backfillLessonId = firstLessonId(pr.condition());
            UUID backfillAttemptId = backfillLessonId == null ? null
                    : firstCompletedAttempt(userId, backfillLessonId);
            int inserted = inventory.insertIgnoreV2(userId,
                    pr.item().getId(), SOURCE_RECONCILE,
                    backfillLessonId, backfillAttemptId,
                    pr.rule().getId(),
                    pr.rule().getRuleVersion(),
                    firstEventId(pr.condition(), null),
                    causeKey(pr.rule(), userId));
            granted += inserted;
        }
        return granted;
    }

    private record ParsedRule(ItemUnlockRule rule, ItemCatalog item,
                              ItemCondition condition) {
    }

    /** Lesson đầu tiên xuất hiện trong AST (null cho rule không gắn bài). */
    private UUID firstLessonId(ItemCondition c) {
        return switch (c) {
            case ItemCondition.Leaf l -> l.lessonId();
            case ItemCondition.All a -> a.children().stream()
                    .map(this::firstLessonId)
                    .filter(java.util.Objects::nonNull)
                    .findFirst().orElse(null);
            case ItemCondition.Any a -> a.children().stream()
                    .map(this::firstLessonId)
                    .filter(java.util.Objects::nonNull)
                    .findFirst().orElse(null);
        };
    }

    /** Attempt COMPLETED sớm nhất của learner trên lesson (provenance). */
    private UUID firstCompletedAttempt(UUID userId, UUID lessonId) {
        List<?> rows = em.createNativeQuery("""
                SELECT a.id FROM learner_attempts a
                JOIN lesson_versions v ON v.id = a.lesson_version_id
                WHERE a.user_id = :userId AND v.lesson_id = :lessonId
                  AND a.status = 'COMPLETED'
                ORDER BY a.completed_at ASC LIMIT 1
                """)
                .setParameter("userId", userId)
                .setParameter("lessonId", lessonId)
                .getResultList();
        return rows.isEmpty() ? null : (UUID) rows.get(0);
    }

    /**
     * User có footprint đủ để có thể đạt BẤT KỲ rule nào: đã collect
     * evidence, đã complete attempt, hoặc đã có milestone. Set-based,
     * không load entity — chỉ id. Giữ nguyên cho reconcileUnlocks() gọi
     * tường minh (đường V1 nhỏ); runner lớn dùng candidateUsersPage.
     */
    @SuppressWarnings("unchecked")
    private List<UUID> candidateUsers() {
        return em.createNativeQuery("""
                SELECT user_id FROM user_evidence
                UNION
                SELECT a.user_id FROM learner_attempts a
                WHERE a.status = 'COMPLETED'
                UNION
                SELECT p.user_id FROM user_event_progress p
                """)
                .getResultList();
    }
}
