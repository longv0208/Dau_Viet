package com.dauviet.collection.application;

import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.domain.UserEventProgress;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;

/**
 * Điểm hội tụ duy nhất cho "đánh giá + ghi milestone nếu đủ điều kiện"
 * (GAME-04 FIX 3). Hai luồng gọi:
 *   - {@code EventProgressQueryService.progressOf} (reconcile-on-read event
 *     progress) — khi learner mở trang event mà chưa có milestone.
 *   - {@code DossierService} (lazy reconcile khi learner mở thẳng Collection)
 *     — FIX 3: tránh buộc learner qua event progress trước mới thấy unlock.
 *
 * Cả hai đều vào đây để:
 *   - advisory lock (user,event) serialize reconcile;
 *   - evaluate qua EventProgressEvaluator → recorder persist;
 *   - chỉ ghi khi policy PUBLISHED tồn tại (NOT_CONFIGURED bỏ qua);
 *   - insertIgnore + PK composite → idempotent tuyệt đối, không dup.
 *
 * KHÔNG gọi cho mọi dossier — chỉ reconcile các event learner có liên quan
 * (từ unlock hiện có / dossier sắp xem). Không tạo batch lớn trên mọi
 * request list — phạm vi rõ ràng theo eventIds được truyền vào.
 */
@Service
public class EventReconcileService {

    private final EventCompletionPolicyRepository policies;
    private final EventCompletionPolicyService policyService;
    private final EventMilestoneRecorder recorder;
    private final UserEventProgressRepository progress;

    public EventReconcileService(EventCompletionPolicyRepository policies,
                                 EventCompletionPolicyService policyService,
                                 EventMilestoneRecorder recorder,
                                 UserEventProgressRepository progress) {
        this.policies = policies;
        this.policyService = policyService;
        this.recorder = recorder;
        this.progress = progress;
    }

    /**
     * Reconcile một (user,event): nếu policy PUBLISHED tồn tại và learner đã
     * đủ điều kiện (tất cả required lesson COMPLETED), ghi milestone + fan-out
     * dossier unlocks nguyên tử trong tx hiện tại. Idempotent — gọi lại an
     * toàn (insertIgnore + PK).
     *
     * @return dossier ids mở MỚI (rỗng nếu chưa đạt / đã grant / NOT_CONFIGURED)
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public Set<UUID> reconcileEvent(UUID userId, UUID eventId) {
        return policyService.publishedPolicyOf(eventId)
                .map(policy -> reconcileWithPolicy(userId, policy))
                .orElse(Set.of());
    }

    /**
     * Reconcile tập events — dùng khi learner mở Collection/Dossier list mà
     * có completed attempt cũ chưa qua event progress page. Chỉ xử lý event
     * có policy PUBLISHED; idempotent; mỗi event chạy trong cùng tx caller.
     *
     * @return tổng hợp dossier ids mở MỚI trên các event
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public Set<UUID> reconcileEvents(UUID userId, List<UUID> eventIds) {
        java.util.Set<UUID> out = new java.util.LinkedHashSet<>();
        for (UUID eventId : eventIds) {
            out.addAll(reconcileEvent(userId, eventId));
        }
        return out;
    }

    /**
     * Reconcile các event mà learner có quan hệ (đã unlock dossier thuộc
     * event, HOẶC completed lesson của event mà chưa có milestone). Dùng cho
     * dossier list/detail — tránh loop qua mọi event trên hệ thống.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public Set<UUID> reconcileOwnedEvents(UUID userId, UUID... candidateEventIds) {
        java.util.Set<UUID> out = new java.util.LinkedHashSet<>();
        for (UUID eventId : candidateEventIds) {
            if (eventId == null) continue;
            // Nhanh: nếu đã có EVENT_COMPLETED → recorder sẽ no-op (đã grant),
            // vẫn gọi để fan-out dossier mới nếu admin publish thêm (FIX 4).
            out.addAll(reconcileEvent(userId, eventId));
        }
        return out;
    }

    /* ---------- internals ---------- */

    /**
     * Đánh giá và ghi milestone + fan-out nếu đủ điều kiện. Gọi nguyên
     * recorder (đã chứa advisory lock + insertIgnore + fanOut PUBLISHED-only)
     * để giữ một đường duy nhất.
     */
    private Set<UUID> reconcileWithPolicy(UUID userId,
                                          EventCompletionPolicy policy) {
        return recorder.recordIfEarned(userId, policy.getEventId());
    }

    /** Tìm các event có policy PUBLISHED — hỗ trợ scan phạm vi khi cần. */
    @Transactional(readOnly = true)
    public List<UUID> eventsWithPublishedPolicy() {
        return policies.findAll().stream()
                .filter(p -> p.getStatus()
                        == EventCompletionPolicy.Status.PUBLISHED)
                .map(EventCompletionPolicy::getEventId)
                .toList();
    }
}
