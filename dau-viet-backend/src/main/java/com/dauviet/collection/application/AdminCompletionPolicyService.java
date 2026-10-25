package com.dauviet.collection.application;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.AdminCompletionPolicyResponse;
import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.AdminCompletionPolicyUpsertRequest;
import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.AdminPolicyValidationResponse;
import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.PolicyDiff;
import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.PolicyIssue;
import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.domain.EventCompletionPolicy.Status;
import com.dauviet.collection.domain.PolicyValidationException;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Admin CRUD + validate + publish cho event_completion_policies (GAME-06).
 *
 * Quy uoc:
 * - Moi event chi co toi da mot DRAFT tai mot thoi diem (service enforce).
 * - PUT sua DRAFT in-place giu nguyen policyId (user override — khong
 *   delete/reinsert). PUBLISHED immutable: muon thay doi = tao DRAFT moi
 *   roi publish.
 * - Publish atomic: lock event row (PESSIMISTIC_WRITE) -> revalidate ->
 *   archive PUBLISHED cu -> publish DRAFT. Partial unique index
 *   ux_event_policy_published bat race tai commit.
 */
@Service
public class AdminCompletionPolicyService {

    private final EventCompletionPolicyRepository policies;
    private final HistoricalEventRepository events;
    private final LessonRepository lessons;
    private final ObjectMapper mapper;

    public AdminCompletionPolicyService(EventCompletionPolicyRepository policies,
            HistoricalEventRepository events,
            LessonRepository lessons,
            ObjectMapper mapper) {
        this.policies = policies;
        this.events = events;
        this.lessons = lessons;
        this.mapper = mapper;
    }

    @Transactional(readOnly = true)
    public List<AdminCompletionPolicyResponse> list(UUID eventId) {
        requireEvent(eventId);
        return policies.findByEventIdOrderByPolicyVersionDesc(eventId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public AdminCompletionPolicyResponse get(UUID eventId, UUID policyId) {
        EventCompletionPolicy p = requirePolicy(eventId, policyId);
        return toResponse(p);
    }

    /**
     * Tao DRAFT moi: policyVersion = maxVersion + 1. Neu da co DRAFT dang
     * mo -> 400 (chi 1 draft tai mot thoi diem).
     */
    @Transactional
    public AdminCompletionPolicyResponse create(UUID eventId,
            AdminCompletionPolicyUpsertRequest req) {
        requireEvent(eventId);
        if (policies.findDraftByEventId(eventId).isPresent()) {
            throw new IllegalArgumentException(
                    "event already has an open DRAFT policy — update it instead of creating a new one");
        }
        Integer max = policies.findMaxVersion(eventId);
        int nextVersion = (max == null ? 0 : max) + 1;
        EventCompletionPolicy draft = EventCompletionPolicy.draft(
                eventId, nextVersion,
                req.requiredLessonIds(), req.optionalLessonIds(),
                toShort(req.masteryThreshold()), mapper);
        policies.save(draft);
        return toResponse(draft);
    }

    /**
     * Sua DRAFT in-place (giu policyId on dinh). PUBLISHED/ARCHIVED -> 400.
     * expectedPolicyVersion != null va khac hien tai -> 409 stale.
     */
    @Transactional
    public AdminCompletionPolicyResponse updateDraft(UUID eventId, UUID policyId,
            AdminCompletionPolicyUpsertRequest req) {
        EventCompletionPolicy p = requirePolicy(eventId, policyId);
        if (p.getStatus() != Status.DRAFT) {
            throw new IllegalArgumentException(
                    "only DRAFT policies can be edited — published policies are immutable; create a new draft");
        }
        checkExpectedVersion(eventId, req.expectedPolicyVersion());
        p.setRequiredLessonIds(req.requiredLessonIds(), mapper);
        p.setOptionalLessonIds(req.optionalLessonIds(), mapper);
        p.setMasteryThreshold(toShort(req.masteryThreshold()));
        policies.save(p);
        return toResponse(p);
    }

    /**
     * Dry-run validate: body tu request (hoac DRAFT hien tai khi req=null).
     * Tra errors co cau truc + diff so voi PUBLISHED hien tai.
     */
    @Transactional(readOnly = true)
    public AdminPolicyValidationResponse validate(UUID eventId, UUID policyId,
            AdminCompletionPolicyUpsertRequest req) {
        HistoricalEvent event = events.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "event not found: " + eventId));
        EventCompletionPolicy p = requirePolicy(eventId, policyId);

        List<UUID> required = req != null && req.requiredLessonIds() != null
                ? req.requiredLessonIds() : p.requiredLessonIds(mapper);
        List<UUID> optional = req != null && req.optionalLessonIds() != null
                ? req.optionalLessonIds() : p.optionalLessonIds(mapper);
        Integer threshold = req != null && req.masteryThreshold() != null
                ? req.masteryThreshold() : p.getMasteryThreshold();

        List<PolicyIssue> errors = collectIssues(event, required, optional,
                threshold);
        List<String> warnings = new ArrayList<>();

        EventCompletionPolicy published = policies.findPublishedByEventId(eventId)
                .orElse(null);
        PolicyDiff diff = null;
        if (published != null) {
            warnings.add("learners that already completed keep their progress — "
                    + "the new version does not revoke existing unlocks");
            Set<UUID> oldRequired = new HashSet<>(published.requiredLessonIds(mapper));
            Set<UUID> newRequired = new HashSet<>(required);
            List<UUID> added = required.stream()
                    .filter(id -> !oldRequired.contains(id)).toList();
            List<UUID> removed = published.requiredLessonIds(mapper).stream()
                    .filter(id -> !newRequired.contains(id)).toList();
            diff = new PolicyDiff(
                    new PolicyDiff.Snapshot(published.getPolicyVersion(),
                            published.requiredLessonIds(mapper).size(),
                            published.optionalLessonIds(mapper).size(),
                            published.getMasteryThreshold(), List.of(), List.of()),
                    new PolicyDiff.Snapshot(p.getPolicyVersion(),
                            required.size(), optional.size(), threshold,
                            added, removed));
        }
        return new AdminPolicyValidationResponse(errors.isEmpty(), errors,
                warnings, diff);
    }

    /**
     * Publish atomic: lock event row -> verify DRAFT + expectedPolicyVersion
     * -> revalidate -> archive PUBLISHED cu -> set PUBLISHED + publishedAt.
     */
    @Transactional
    public AdminCompletionPolicyResponse publish(UUID eventId, UUID policyId,
            Integer expectedPolicyVersion) {
        HistoricalEvent event = events.findForUpdate(eventId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "event not found: " + eventId));
        EventCompletionPolicy p = requirePolicy(eventId, policyId);
        if (p.getStatus() != Status.DRAFT) {
            throw new IllegalArgumentException(
                    "only DRAFT policies can be published (current status: "
                    + p.getStatus() + ")");
        }
        checkExpectedVersion(eventId, expectedPolicyVersion);

        List<PolicyIssue> issues = collectIssues(event,
                p.requiredLessonIds(mapper), p.optionalLessonIds(mapper),
                p.getMasteryThreshold());
        if (!issues.isEmpty()) {
            throw new PolicyValidationException(issues.stream()
                    .map(i -> i.code() + ": " + i.message()).toList());
        }

        // Archive phai FLUSH truoc khi set PUBLISHED — partial unique index
        // ux_event_policy_published chan ca transaction neu luc commit co
        // 2 row PUBLISHED cung event.
        policies.findPublishedByEventId(eventId).ifPresent(old -> {
            old.setStatus(Status.ARCHIVED);
            policies.saveAndFlush(old);
        });
        p.setStatus(Status.PUBLISHED);
        p.setPublishedAt(Instant.now());
        policies.save(p);
        return toResponse(p);
    }

    /* ---------- helpers ---------- */

    private HistoricalEvent requireEvent(UUID eventId) {
        return events.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "event not found: " + eventId));
    }

    private EventCompletionPolicy requirePolicy(UUID eventId, UUID policyId) {
        EventCompletionPolicy p = policies.findById(policyId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "policy not found: " + policyId));
        if (!eventId.equals(p.getEventId())) {
            throw new ResourceNotFoundException(
                    "policy " + policyId + " does not belong to event " + eventId);
        }
        return p;
    }

    /**
     * Optimistic guard: admin phai dang thay version moi nhat. Khac
     * maxVersion -> 409 qua OptimisticLockingFailure.
     */
    private void checkExpectedVersion(UUID eventId, Integer expected) {
        if (expected == null) {
            return;
        }
        Integer max = policies.findMaxVersion(eventId);
        int current = max == null ? 0 : max;
        if (current != expected) {
            throw new org.springframework.dao.OptimisticLockingFailureException(
                    "policy version mismatch: expected " + expected
                    + " but current max is " + current + " — reload and retry");
        }
    }

    /**
     * Tat ca rule validation chay ca luc dry-run lan publish.
     * Event PUBLISHED, >=1 required, khong duplicate, khong overlap
     * required∩optional, lesson ton tai + dung event + PUBLISHED,
     * threshold 0..100.
     */
    private List<PolicyIssue> collectIssues(HistoricalEvent event,
            List<UUID> required, List<UUID> optional, Integer threshold) {
        List<PolicyIssue> issues = new ArrayList<>();

        if (event.getStatus() != EventStatus.PUBLISHED) {
            issues.add(new PolicyIssue("EVENT_NOT_PUBLISHED",
                    "event must be PUBLISHED before its completion policy can go live (current: "
                    + event.getStatus() + ")", "eventId"));
        }

        List<UUID> req = required == null ? List.of() : required;
        List<UUID> opt = optional == null ? List.of() : optional;

        if (req.isEmpty()) {
            issues.add(new PolicyIssue("REQUIRED_EMPTY",
                    "at least one required lesson is needed", "requiredLessonIds"));
        }
        issues.addAll(checkList(req, opt, event.getId(), "requiredLessonIds"));
        issues.addAll(checkList(opt, req, event.getId(), "optionalLessonIds"));

        if (threshold != null && (threshold < 0 || threshold > 100)) {
            issues.add(new PolicyIssue("THRESHOLD_RANGE",
                    "masteryThreshold must be 0..100", "masteryThreshold"));
        }
        return issues;
    }

    private List<PolicyIssue> checkList(List<UUID> ids, List<UUID> other,
            UUID eventId, String field) {
        List<PolicyIssue> issues = new ArrayList<>();
        Set<UUID> seen = new HashSet<>();
        Set<UUID> otherSet = new HashSet<>(other);
        for (UUID id : ids) {
            if (!seen.add(id)) {
                issues.add(new PolicyIssue("LESSON_DUPLICATE",
                        "duplicate lesson id " + id, field));
            }
            if (otherSet.contains(id)) {
                issues.add(new PolicyIssue("LESSON_OVERLAP",
                        "lesson " + id + " cannot be both required and optional",
                        field));
            }
            Lesson lesson = lessons.findById(id).orElse(null);
            if (lesson == null) {
                issues.add(new PolicyIssue("LESSON_NOT_FOUND",
                        "lesson " + id + " does not exist", field));
            } else if (!eventId.equals(lesson.getEventId())) {
                issues.add(new PolicyIssue("LESSON_WRONG_EVENT",
                        "lesson " + id + " belongs to a different event", field));
            } else if (lesson.getStatus() != LessonStatus.PUBLISHED) {
                issues.add(new PolicyIssue("LESSON_NOT_PUBLISHED",
                        "lesson " + id + " is not PUBLISHED (current: "
                        + lesson.getStatus() + ")", field));
            }
        }
        return issues;
    }

    private Short toShort(Integer v) {
        return v == null ? null : v.shortValue();
    }

    private AdminCompletionPolicyResponse toResponse(EventCompletionPolicy p) {
        return new AdminCompletionPolicyResponse(
                p.getId(), p.getEventId(), p.getPolicyVersion(),
                p.getStatus().name(),
                p.requiredLessonIds(mapper), p.optionalLessonIds(mapper),
                p.getMasteryThreshold(), p.getPublishedAt(), p.getCreatedAt());
    }
}
