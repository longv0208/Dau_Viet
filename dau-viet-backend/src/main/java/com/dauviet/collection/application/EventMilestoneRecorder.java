package com.dauviet.collection.application;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.domain.HistoricalDossier;
import com.dauviet.collection.domain.UserEventProgress;
import com.dauviet.collection.infrastructure.persistence.EventDossierRepository;
import com.dauviet.collection.infrastructure.persistence.HistoricalDossierRepository;
import com.dauviet.collection.infrastructure.persistence.UserDossierUnlockRepository;
import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.reward.application.ItemUnlockService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.context.annotation.Lazy;

import jakarta.persistence.EntityManager;

/**
 * Ghi milestone EVENT_COMPLETED / EVENT_MASTERED + fan-out mở hồ sơ
 * (GAME-04 §10). Chạy BÊN TRONG transaction complete của attempt —
 * ledger + unlock cùng commit/rollback với lesson completion.
 *
 * Đường đi: advisory lock (user,event) → published policy → evaluate →
 * insertIgnore từng milestone (idempotent, entitlement không viết lại) →
 * fan-out dossier qua event_dossiers unlock_on='EVENT_COMPLETED' →
 * insertIgnore per dossier (insert >0 = mở mới, trả về cho cue).
 *
 * Race hai-lesson-cuối: lock tuần tự hoá cặp (user,event); loser của lock
 * đánh giá lại trên trạng thái đã commit của winner — ON CONFLICT DO
 * NOTHING bảo đảm không duplicate, không mất milestone.
 */
@Service
public class EventMilestoneRecorder {

    private final EntityManager entityManager;
    private final EventCompletionPolicyService policyService;
    private final EventProgressEvaluator evaluator;
    private final UserEventProgressRepository progress;
    private final EventDossierRepository eventDossiers;
    private final HistoricalDossierRepository dossiers;
    private final UserDossierUnlockRepository unlocks;
    private final ItemUnlockService itemUnlocks;
    private final ObjectMapper mapper;

    public EventMilestoneRecorder(EntityManager entityManager,
            EventCompletionPolicyService policyService,
            EventProgressEvaluator evaluator,
            UserEventProgressRepository progress,
            EventDossierRepository eventDossiers,
            HistoricalDossierRepository dossiers,
            UserDossierUnlockRepository unlocks,
            @Lazy ItemUnlockService itemUnlocks,
            ObjectMapper mapper) {
        this.entityManager = entityManager;
        this.policyService = policyService;
        this.evaluator = evaluator;
        this.progress = progress;
        this.eventDossiers = eventDossiers;
        this.dossiers = dossiers;
        this.unlocks = unlocks;
        this.itemUnlocks = itemUnlocks;
        this.mapper = mapper;
    }

    /**
     * Đánh giá + ghi milestone/dossier unlock cho (user, event) sau khi một
     * attempt của event hoàn thành. Gọi trong cùng tx với doComplete.
     *
     * @return dossier ids mở MỚI trong lần này (rỗng nếu replay / đã grant /
     *         chưa đạt milestone) — caller nhét vào CompleteAttemptResponse.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public Set<UUID> recordIfEarned(UUID userId, UUID eventId) {
        return recordIfEarned(userId, eventId, null, null);
    }

    /**
     * Bản đầy đủ — doComplete truyền lessonId/attemptId đang complete để
     * item grant qua leaf EVENT_COMPLETED/EVENT_MASTERED ghi đúng
     * source_lesson_id/source_attempt_id (provenance result screen,
     * FIX FINAL-1). Reconcile giữ bản 2-tham-số → provenance null, không
     * gán attempt giả.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public Set<UUID> recordIfEarned(UUID userId, UUID eventId,
                                    UUID lessonId, UUID attemptId) {
        // Serial hoá cặp (user,event): hai completion song song của hai lesson
        // cuối không được ghi mất milestone — loser thấy winner đã commit.
        entityManager.createNativeQuery(
                "select pg_advisory_xact_lock(hashtextextended(:k, 0::bigint))")
                .setParameter("k", userId + "|" + eventId)
                .getSingleResult();

        return policyService.publishedPolicyOf(eventId)
                .map(policy -> evaluateAndRecord(userId, policy,
                        lessonId, attemptId))
                .orElse(Set.of()); // NOT_CONFIGURED — không ghi gì (EVT-07)
    }

    private Set<UUID> evaluateAndRecord(UUID userId,
                                        EventCompletionPolicy policy,
                                        UUID lessonId, UUID attemptId) {
        UUID eventId = policy.getEventId();
        EventProgressEvaluator.Evaluation ev =
                evaluator.evaluate(userId, policy);
        String snapshot = policy.getRequiredLessonIdsJson();

        Set<UUID> newlyUnlocked = new LinkedHashSet<>();
        boolean completedAlready = progress.exists(userId, eventId,
                UserEventProgress.Milestone.EVENT_COMPLETED.name());
        boolean newCompleted = false;
        if (ev.completed() && !completedAlready) {
            progress.insertIgnore(userId, eventId,
                    UserEventProgress.Milestone.EVENT_COMPLETED.name(),
                    policy.getPolicyVersion(), snapshot);
            newCompleted = true;
        }
        // Fan-out dossier khi (a) mới grant EVENT_COMPLETED, HOẶC (b) đã
        // grant nhưng admin publish/link thêm dossier sau (FIX 4).
        // insertIgnore trả 0 khi đã có → newlyUnlocked chỉ chứa grant MỚI.
        if (ev.completed() || completedAlready) {
            fanOutDossierUnlocks(userId, eventId, newlyUnlocked);
        }
        boolean newMastered = false;
        if (ev.mastered()
                && !progress.exists(userId, eventId,
                        UserEventProgress.Milestone.EVENT_MASTERED.name())) {
            progress.insertIgnore(userId, eventId,
                    UserEventProgress.Milestone.EVENT_MASTERED.name(),
                    policy.getPolicyVersion(), snapshot);
            newMastered = true;
        }
        // GAME-05 FIX-3 + FINAL-1: milestone MỚI ghi xong → đánh giá item
        // rules ngay trong cùng tx, truyền provenance lesson/attempt khi
        // caller là doComplete (grant ghi source_attempt_id đúng cho
        // result screen); reconcile truyền null → không gán attempt giả.
        // Chỉ khi milestone MỚI — không đánh giá thừa mỗi lần đọc lại;
        // lần evaluateAfterLessonCompletion sau đó trong doComplete no-op
        // nhờ insertIgnore + cause_key.
        if (newCompleted || newMastered) {
            itemUnlocks.evaluateAfterEventMilestone(userId, eventId,
                    lessonId, attemptId);
        }
        return newlyUnlocked;
    }

    /**
     * Mở mọi dossier PUBLISHED link tới event qua unlock_on='EVENT_COMPLETED'.
     * insertIgnore trả số row thực insert — >0 nghĩa mở mới (cue).
     * DRAFT dossier không được fan-out cho đến khi admin publish (GAME-06).
     */
    private void fanOutDossierUnlocks(UUID userId, UUID eventId,
                                      Set<UUID> newlyUnlocked) {
        List<UUID> dossierIds = eventDossiers.findEventCompletedDossierIds(eventId);
        if (dossierIds.isEmpty()) {
            return;
        }
        for (HistoricalDossier d : dossiers.findAllByIdIn(Set.copyOf(dossierIds))) {
            if (d.getStatus() != HistoricalDossier.Status.PUBLISHED) {
                continue;
            }
            int inserted = unlocks.insertIgnore(userId, d.getId(), eventId,
                    d.getDossierVersion() == null ? 1 : d.getDossierVersion());
            if (inserted > 0) {
                newlyUnlocked.add(d.getId());
            }
        }
    }
}
