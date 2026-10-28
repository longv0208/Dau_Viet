package com.dauviet.historicalevent.admin;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.admin.dto.AdminEventCreateRequest;
import com.dauviet.historicalevent.admin.dto.AdminEventResponse;
import com.dauviet.historicalevent.admin.dto.AdminEventSummaryResponse;
import com.dauviet.historicalevent.admin.dto.AdminEventUpdateRequest;
import com.dauviet.historicalevent.admin.mapper.AdminEventMapper;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.EventInUseException;
import com.dauviet.lesson.domain.InvalidStatusTransitionException;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.domain.LessonStatus;

import jakarta.persistence.criteria.Predicate;

/**
 * Admin-side write/manage service for historical events.
 * Enforces status transitions DRAFT→PUBLISHED→ARCHIVED and DRAFT→ARCHIVED,
 * slug immutability after PUBLISHED, and refuses to archive an event still
 * referenced by non-archived lessons.
 */
@Service
public class AdminEventService {

    private final HistoricalEventRepository events;
    private final LessonRepository lessons;
    private final AdminEventMapper mapper;

    public AdminEventService(HistoricalEventRepository events,
                             LessonRepository lessons,
                             AdminEventMapper mapper) {
        this.events = events;
        this.lessons = lessons;
        this.mapper = mapper;
    }

    @Transactional
    public AdminEventResponse create(AdminEventCreateRequest req) {
        HistoricalEvent e = new HistoricalEvent();
        e.setId(UUID.randomUUID());
        e.setSlug(req.slug());
        e.setTitle(req.title());
        e.setEra(req.era());
        e.setPeriod(req.period());
        e.setStartYear(req.startYear());
        e.setSummary(req.summary());
        e.setDescription(req.description());
        e.setLocation(req.location());
        e.setCoverAssetKey(req.coverAssetKey() != null && !req.coverAssetKey().isBlank()
                ? req.coverAssetKey().trim()
                : null);
        e.setTags(req.tags() == null ? new ArrayList<>() : new ArrayList<>(req.tags()));
        e.setStatus(EventStatus.DRAFT);
        try {
            return mapper.toResponse(events.saveAndFlush(e));
        } catch (DataIntegrityViolationException ex) {
            throw mapDataIntegrity(ex, req.slug());
        }
    }

    @Transactional(readOnly = true)
    public Page<AdminEventSummaryResponse> list(EventStatus status, String q, Pageable pageable) {
        Specification<HistoricalEvent> spec = (root, cq, cb) -> {
            List<Predicate> preds = new ArrayList<>();
            if (status != null) {
                preds.add(cb.equal(root.get("status"), status));
            }
            if (q != null && !q.isBlank()) {
                String like = "%" + q.trim().toLowerCase() + "%";
                Predicate textMatch = cb.or(
                        cb.like(cb.lower(root.get("title")), like),
                        cb.like(cb.lower(root.get("slug")), like));
                try {
                    preds.add(cb.or(textMatch, cb.equal(root.get("startYear"), Integer.valueOf(q.trim()))));
                } catch (NumberFormatException ex) {
                    preds.add(textMatch);
                }
            }
            return cb.and(preds.toArray(new Predicate[0]));
        };
        return events.findAll(spec, pageable).map(mapper::toSummary);
    }

    @Transactional(readOnly = true)
    public AdminEventResponse get(UUID id) {
        return events.findById(id)
                .map(mapper::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found: " + id));
    }

    @Transactional
    public AdminEventResponse update(UUID id, AdminEventUpdateRequest req) {
        HistoricalEvent e = load(id);
        checkVersion(e, req.expectedRowVersion());
        if (e.getStatus() == EventStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived event cannot be edited");
        }
        if (req.slug() != null && !req.slug().equals(e.getSlug())) {
            if (e.getStatus() != EventStatus.DRAFT) {
                throw new InvalidStatusTransitionException(
                        "slug is immutable once the event is " + e.getStatus());
            }
            e.setSlug(req.slug());
        }
        if (req.title() != null) e.setTitle(req.title());
        if (req.era() != null) e.setEra(req.era());
        if (req.period() != null) e.setPeriod(req.period());
        if (req.startYear() != null) e.setStartYear(req.startYear());
        if (req.summary() != null) e.setSummary(req.summary());
        if (req.description() != null) e.setDescription(req.description());
        if (req.location() != null) e.setLocation(req.location());
        if (req.coverAssetKey() != null) {
            e.setCoverAssetKey(req.coverAssetKey().isBlank() ? null : req.coverAssetKey().trim());
        }
        if (req.tags() != null) e.setTags(new ArrayList<>(req.tags()));
        try {
            return mapper.toResponse(events.saveAndFlush(e));
        } catch (DataIntegrityViolationException ex) {
            throw mapDataIntegrity(ex, req.slug());
        }
    }

    @Transactional
    public AdminEventResponse publish(UUID id) {
        HistoricalEvent e = load(id);
        if (e.getStatus() != EventStatus.DRAFT) {
            throw new InvalidStatusTransitionException(
                    "cannot publish event in status " + e.getStatus());
        }
        e.setStatus(EventStatus.PUBLISHED);
        return mapper.toResponse(events.saveAndFlush(e));
    }

    @Transactional
    public AdminEventResponse archive(UUID id) {
        HistoricalEvent e = load(id);
        if (e.getStatus() == EventStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("event already archived");
        }
        if (lessons.existsByEventIdAndStatusNot(id, LessonStatus.ARCHIVED)) {
            throw new EventInUseException(
                    "event still has non-archived lessons; archive them first");
        }
        e.setStatus(EventStatus.ARCHIVED);
        return mapper.toResponse(events.saveAndFlush(e));
    }

    private HistoricalEvent load(UUID id) {
        return events.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found: " + id));
    }

    private void checkVersion(HistoricalEvent e, Long expected) {
        if (expected != null && !expected.equals(e.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    HistoricalEvent.class, e.getId());
        }
    }

    /**
     * Only translate a constraint violation into a user-facing "slug already
     * exists" error when the failing constraint is actually the slug unique
     * index; any other integrity violation is rethrown unchanged.
     */
    private RuntimeException mapDataIntegrity(DataIntegrityViolationException ex, String slug) {
        String msg = String.valueOf(ex.getMessage());
        String root = ex.getRootCause() == null ? "" : String.valueOf(ex.getRootCause().getMessage());
        String haystack = (msg + " " + root).toLowerCase(Locale.ROOT);
        if (haystack.contains("slug")) {
            return new IllegalArgumentException("slug already exists: " + slug);
        }
        return ex;
    }
}
