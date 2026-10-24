package com.dauviet.reward.application;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Component;

import jakarta.persistence.EntityManager;

import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.EvidenceStatus;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.infrastructure.persistence.EvidenceRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;

/**
 * Kiểm tra tham chiếu + ràng buộc nghiệp vụ của AST đã parse (GAME-05
 * §10 contract). Parser chỉ chặt grammar; validator chặn publish rule
 * trỏ tới tài nguyên sai trạng thái — mọi lỗi ném {@link ItemRuleException}
 * (400), không bao giờ để malformed config rơi vào DB.
 *
 * Chặn publish khi:
 *  - leaf thiếu/thừa trường theo type;
 *  - event không tồn tại/không PUBLISHED; leaf EVENT_COMPLETED/EVENT_MASTERED
 *    trỏ event chưa có policy PUBLISHED (NOT_CONFIGURED — learner không thể
 *    đạt được, rule vô nghĩa);
 *  - lesson không tồn tại/không PUBLISHED;
 *  - SPECIFIC_EVIDENCE_SET: evidenceIds rỗng/trùng, evidence không tồn tại
 *    hoặc không thuộc eventId khai báo;
 *  - threshold/level thiếu hoặc trùng leaf giống hệt nhau (vô nghĩa);
 *  - LEVEL_AT_LEAST bị kích hoạt — parse được nhưng GAME-07 mới đánh giá,
 *    không cho publish vì sẽ mãi không-satisfied.
 */
@Component
public class ItemConditionValidator {

    private final HistoricalEventRepository events;
    private final EventCompletionPolicyRepository policies;
    private final LessonRepository lessons;
    private final EvidenceRepository evidences;
    private final EntityManager em;

    public ItemConditionValidator(HistoricalEventRepository events,
            EventCompletionPolicyRepository policies,
            LessonRepository lessons,
            EvidenceRepository evidences,
            EntityManager em) {
        this.events = events;
        this.policies = policies;
        this.lessons = lessons;
        this.evidences = evidences;
        this.em = em;
    }

    /** Validate toàn bộ AST trước khi insert rule v2. */
    public void validate(ItemCondition condition) {
        List<ItemCondition.Leaf> leaves = flatten(condition);
        if (leaves.isEmpty()) {
            throw new ItemRuleException("condition has no leaf");
        }
        // Leaf trùng hệt nhau trong cùng ALL/ANY là vô nghĩa — chặn sớm.
        Set<String> seen = new HashSet<>();
        for (ItemCondition.Leaf leaf : leaves) {
            String fingerprint = fingerprint(leaf);
            if (!seen.add(fingerprint)) {
                throw new ItemRuleException(
                        "duplicate leaf condition: " + fingerprint);
            }
            validateLeaf(leaf);
        }
    }

    private List<ItemCondition.Leaf> flatten(ItemCondition c) {
        List<ItemCondition.Leaf> out = new ArrayList<>();
        switch (c) {
            case ItemCondition.Leaf l -> out.add(l);
            case ItemCondition.All a ->
                    a.children().forEach(ch -> out.addAll(flatten(ch)));
            case ItemCondition.Any a ->
                    a.children().forEach(ch -> out.addAll(flatten(ch)));
        }
        return out;
    }

    private String fingerprint(ItemCondition.Leaf l) {
        return l.type() + "|" + l.eventId() + "|" + l.lessonId()
                + "|" + l.evidenceIds() + "|" + l.threshold() + "|" + l.level();
    }

    private void validateLeaf(ItemCondition.Leaf leaf) {
        switch (leaf.type()) {
            case LESSON_COMPLETED -> requireLesson(leaf.lessonId());
            case LESSON_MASTERED -> {
                requireLesson(leaf.lessonId());
                requireThreshold(leaf.threshold(), "LESSON_MASTERED");
            }
            case COLLECTION_COUNT, LESSON_COUNT,
                 TOTAL_EVENTS_COMPLETED, TOTAL_EVENTS_MASTERED ->
                    requireThreshold(leaf.threshold(), leaf.type().name());
            case EVENT_COMPLETED, EVENT_MASTERED -> {
                UUID eventId = requireEvent(leaf.eventId());
                requireConfiguredPolicy(eventId, leaf.type().name());
            }
            case EVENT_EVIDENCE_COUNT -> {
                requireEvent(leaf.eventId());
                requireThreshold(leaf.threshold(), "EVENT_EVIDENCE_COUNT");
            }
            case SPECIFIC_EVIDENCE_SET -> validateEvidenceSet(leaf);
            case LEVEL_AT_LEAST -> throw new ItemRuleException(
                    "LEVEL_AT_LEAST is not evaluable yet (GAME-07); "
                    + "do not publish");
        }
    }

    private void requireThreshold(Integer threshold, String type) {
        if (threshold == null || threshold <= 0) {
            throw new ItemRuleException(type + " requires a positive threshold");
        }
    }

    /** Trả về eventId hợp lệ sau khi kiểm tra tồn tại + PUBLISHED. */
    private UUID requireEvent(UUID eventId) {
        if (eventId == null) {
            throw new ItemRuleException("event condition requires eventId");
        }
        var event = events.findById(eventId).orElseThrow(() ->
                new ItemRuleException("event not found: " + eventId));
        if (event.getStatus() != EventStatus.PUBLISHED) {
            throw new ItemRuleException(
                    "event not published: " + eventId);
        }
        return eventId;
    }

    /** EVENT_COMPLETED/EVENT_MASTERED cần event có policy PUBLISHED —
     * learner không bao giờ đạt milestone trên event NOT_CONFIGURED. */
    private void requireConfiguredPolicy(UUID eventId, String type) {
        if (policies.findPublishedByEventId(eventId).isEmpty()) {
            throw new ItemRuleException(type + " requires event "
                    + eventId + " to have a published completion policy");
        }
    }

    private void requireLesson(UUID lessonId) {
        if (lessonId == null) {
            throw new ItemRuleException("lesson condition requires lessonId");
        }
        var lesson = lessons.findById(lessonId).orElseThrow(() ->
                new ItemRuleException("lesson not found: " + lessonId));
        if (lesson.getStatus() != LessonStatus.PUBLISHED) {
            throw new ItemRuleException("lesson not published: " + lessonId);
        }
    }

    private void validateEvidenceSet(ItemCondition.Leaf leaf) {
        if (leaf.eventId() == null) {
            throw new ItemRuleException(
                    "SPECIFIC_EVIDENCE_SET requires eventId");
        }
        requireEvent(leaf.eventId());
        List<UUID> ids = leaf.evidenceIds();
        if (ids == null || ids.isEmpty()) {
            throw new ItemRuleException(
                    "SPECIFIC_EVIDENCE_SET requires non-empty evidenceIds");
        }
        Set<UUID> distinct = new HashSet<>(ids);
        if (distinct.size() != ids.size()) {
            throw new ItemRuleException(
                    "SPECIFIC_EVIDENCE_SET has duplicate evidenceIds");
        }
        for (UUID id : ids) {
            // Mỗi evidence phải tồn tại, thuộc đúng event khai báo và ở
            // trạng thái APPROVED (DRAFT chưa xuất hiện trong published
            // snapshot, ARCHIVED đã rút khỏi catalog).
            if (!evidences.existsByIdAndEventIdAndStatusIn(id, leaf.eventId(),
                    List.of(EvidenceStatus.APPROVED))) {
                throw new ItemRuleException(
                        "evidence " + id + " does not belong to event "
                        + leaf.eventId() + " or is not usable");
            }
            // FIX-6: evidence phải THỰC SỰ collect được — xuất hiện trong
            // mảng snapshot.evidence[] của một bài học PUBLISHED hiện tại
            // (snapshot root embed mọi evidence mà draft tham chiếu qua
            // visibleEvidenceIds / requiredEvidenceIds / acceptedEvidenceIds /
            // evidenceRefs / evidenceOptions), HOẶC đã từng được learner
            // collect (user_evidence row tồn tại — evidence lấy từ phiên
            // bản cũ đã rút vẫn giữ quyền, không mất entitlement). Rule
            // yêu cầu evidence không ai collect được là cấu hình chết.
            if (!isCollectible(id)) {
                throw new ItemRuleException(
                        "evidence " + id + " is not collectible: absent "
                        + "from every published lesson snapshot and never "
                        + "collected before");
            }
        }
    }

    /**
     * Evidence "collect được" khi nằm trong snapshot.evidence[] của ít
     * nhất một lesson PUBLISHED (current_version), hoặc đã có ít nhất
     * một learner collect từ phiên bản trước (snapshot cũ đã gỡ nhưng
     * entitlement phải giữ — rule vẫn có thể đạt cho người đã sưu tầm).
     * Không suy ra từ title/tag — chỉ đọc cấu trúc đã publish.
     */
    private boolean isCollectible(UUID evidenceId) {
        Number inSnapshot = (Number) em.createNativeQuery("""
                SELECT COUNT(*) FROM lesson_versions lv
                JOIN lessons l ON l.current_version_id = lv.id
                WHERE l.status = 'PUBLISHED'
                  AND EXISTS (
                    SELECT 1 FROM jsonb_array_elements(
                        lv.snapshot_json -> 'evidence') e
                    WHERE e ->> 'id' = :eid
                  )
                """)
                .setParameter("eid", evidenceId.toString())
                .getSingleResult();
        if (inSnapshot.longValue() > 0) return true;
        Number collected = (Number) em.createNativeQuery(
                "SELECT COUNT(*) FROM user_evidence WHERE evidence_id = :eid")
                .setParameter("eid", evidenceId)
                .getSingleResult();
        return collected.longValue() > 0;
    }
}
