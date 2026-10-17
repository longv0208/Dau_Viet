package com.dauviet.lesson.application;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.api.dto.AdminLessonCreateRequest;
import com.dauviet.lesson.api.dto.AdminLessonDraftRequest;
import com.dauviet.lesson.api.dto.AdminLessonResponse;
import com.dauviet.lesson.api.dto.AdminLessonSummaryResponse;
import com.dauviet.lesson.api.dto.AdminLessonUpdateRequest;
import com.dauviet.lesson.api.dto.PublishReadinessResponse;
import com.dauviet.lesson.api.mapper.AdminLessonMapper;
import com.dauviet.lesson.domain.InvalidStatusTransitionException;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonNotFoundException;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.domain.LessonTemplate;
import com.dauviet.lesson.domain.TemplateDisabledException;
import com.dauviet.lesson.domain.TemplateNotFoundException;
import com.dauviet.lesson.draft.DraftValidationException;
import com.dauviet.lesson.draft.DraftValidator;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.ValidationLevel;

import com.fasterxml.jackson.databind.JsonNode;

import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonTemplateRepository;

import jakarta.persistence.criteria.Predicate;

/**
 * Admin-side lesson write/manage service.
 * Status model mirrors events: DRAFT→PUBLISHED→ARCHIVED, DRAFT→ARCHIVED.
 * Draft edits replace `draft_json` (JSONB) without touching `current_version_id`
 * — published snapshots remain immutable in lesson_versions.
 */
@Service
public class LessonService {

    private final LessonRepository lessons;
    private final LessonTemplateRepository templates;
    private final HistoricalEventRepository events;
    private final AdminLessonMapper mapper;
    private final DraftValidator draftValidator;
    private final PublishReadinessEvaluator readiness;
    private final LearnerProjectionService learnerProjection;
    private final com.dauviet.lesson.draft.SnapshotBuilder snapshotBuilder;
    private final com.fasterxml.jackson.databind.ObjectMapper objectMapper;

    public LessonService(LessonRepository lessons,
                         LessonTemplateRepository templates,
                         HistoricalEventRepository events,
                         AdminLessonMapper mapper,
                         DraftValidator draftValidator,
                         PublishReadinessEvaluator readiness,
                         LearnerProjectionService learnerProjection,
                         com.dauviet.lesson.draft.SnapshotBuilder snapshotBuilder,
                         com.fasterxml.jackson.databind.ObjectMapper objectMapper) {
        this.lessons = lessons;
        this.templates = templates;
        this.events = events;
        this.mapper = mapper;
        this.draftValidator = draftValidator;
        this.readiness = readiness;
        this.learnerProjection = learnerProjection;
        this.snapshotBuilder = snapshotBuilder;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public AdminLessonResponse create(AdminLessonCreateRequest req, UUID adminId) {
        if (!events.existsById(req.eventId())) {
            throw new ResourceNotFoundException("Event not found: " + req.eventId());
        }
        LessonTemplate tpl = templates.findById(req.templateId())
                .orElseThrow(() -> new TemplateNotFoundException("Template not found: " + req.templateId()));
        if (!Boolean.TRUE.equals(tpl.getEnabled())) {
            throw new TemplateDisabledException("Template disabled: " + tpl.getCode());
        }
        String objectives = req.objectivesJson() == null
                ? "[]" : DraftValidator.requireJsonArray(req.objectivesJson(), "objectivesJson");
        String draft = req.draftJson() == null
                ? "{}" : DraftValidator.requireJsonObject(req.draftJson(), "draftJson");

        Lesson l = new Lesson();
        l.setId(UUID.randomUUID());
        l.setEventId(req.eventId());
        l.setTemplateId(req.templateId());
        l.setTitle(req.title());
        l.setCentralQuestion(req.centralQuestion());
        l.setObjectivesJson(objectives);
        l.setDraftJson(draft);
        l.setStatus(LessonStatus.DRAFT);
        l.setCreatedBy(adminId);
        l.setUpdatedBy(adminId);
        return mapper.toResponse(lessons.saveAndFlush(l));
    }

    @Transactional(readOnly = true)
    public Page<AdminLessonSummaryResponse> list(UUID eventId, LessonStatus status,
                                                 String q, Pageable pageable) {
        Specification<Lesson> spec = (root, cq, cb) -> {
            List<Predicate> preds = new ArrayList<>();
            if (eventId != null) preds.add(cb.equal(root.get("eventId"), eventId));
            if (status != null) preds.add(cb.equal(root.get("status"), status));
            if (q != null && !q.isBlank()) {
                String like = "%" + q.trim().toLowerCase() + "%";
                preds.add(cb.or(
                        cb.like(cb.lower(root.get("title")), like),
                        cb.like(cb.lower(root.get("centralQuestion")), like)));
            }
            return cb.and(preds.toArray(new Predicate[0]));
        };
        return lessons.findAll(spec, pageable).map(mapper::toSummary);
    }

    @Transactional(readOnly = true)
    public AdminLessonResponse get(UUID id) {
        return lessons.findById(id).map(mapper::toResponse)
                .orElseThrow(() -> new LessonNotFoundException("Lesson not found: " + id));
    }

    @Transactional
    public AdminLessonResponse update(UUID id, AdminLessonUpdateRequest req, UUID adminId) {
        Lesson l = load(id);
        checkVersion(l, req.expectedRowVersion());
        if (l.getStatus() == LessonStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived lesson cannot be edited");
        }
        if (req.templateId() != null && !req.templateId().equals(l.getTemplateId())) {
            // Rebinding the template reshapes the draft, so only allow it while
            // the lesson is still a draft (published snapshot is immutable anyway).
            if (l.getStatus() != LessonStatus.DRAFT) {
                throw new InvalidStatusTransitionException(
                        "template can only be changed while lesson is DRAFT");
            }
            LessonTemplate tpl = templates.findById(req.templateId())
                    .orElseThrow(() -> new TemplateNotFoundException(
                            "Template not found: " + req.templateId()));
            if (!Boolean.TRUE.equals(tpl.getEnabled())) {
                throw new TemplateDisabledException("Template disabled: " + tpl.getCode());
            }
            l.setTemplateId(req.templateId());
        }
        if (req.title() != null) l.setTitle(req.title());
        if (req.centralQuestion() != null) l.setCentralQuestion(req.centralQuestion());
        if (req.objectivesJson() != null) {
            l.setObjectivesJson(DraftValidator.requireJsonArray(req.objectivesJson(), "objectivesJson"));
        }
        l.setUpdatedBy(adminId);
        return mapper.toResponse(lessons.saveAndFlush(l));
    }

    @Transactional
    public AdminLessonResponse updateDraft(UUID id, AdminLessonDraftRequest req, UUID adminId) {
        Lesson l = load(id);
        checkVersion(l, req.expectedRowVersion());
        if (l.getStatus() == LessonStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived lesson cannot be edited");
        }
        // Replaces draft_json; current_version_id (published snapshot) untouched.
        String canonical = DraftValidator.requireJsonObject(req.draftJson(), "draftJson");
        // Structural SAVE-level check on the parsed document — incomplete
        // drafts are allowed (missing config etc.) but bad shapes are not.
        List<FieldError> errs;
        try {
            errs = draftValidator.validate(
                    objectMapper.readTree(canonical), l.getEventId(), ValidationLevel.SAVE);
        } catch (com.fasterxml.jackson.core.JsonProcessingException ex) {
            throw new com.dauviet.lesson.domain.DraftSchemaInvalidException(
                    "draftJson is not valid JSON");
        }
        if (!errs.isEmpty()) {
            throw new DraftValidationException(errs);
        }
        l.setDraftJson(canonical);
        l.setUpdatedBy(adminId);
        return mapper.toResponse(lessons.saveAndFlush(l));
    }

    /**
     * PUBLISH-level readiness probe — read-only, always returns 200.
     * Never creates lesson_versions and never mutates the draft.
     */
    @Transactional(readOnly = true)
    public PublishReadinessResponse checkPublishReadiness(UUID id) {
        return readiness.evaluate(load(id));
    }

    /**
     * Learner-safe projection of the CURRENT draft — what a learner would see
     * if the draft were published now. Read-only; never writes lesson_versions.
     */
    @Transactional(readOnly = true)
    public com.dauviet.lesson.api.dto.LearnerLessonContent preview(UUID id) {
        Lesson l = load(id);
        JsonNode draft;
        try {
            draft = objectMapper.readTree(l.getDraftJson() == null ? "{}" : l.getDraftJson());
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw new com.dauviet.lesson.domain.DraftSchemaInvalidException(
                    "draftJson is not valid JSON");
        }
        // Enrich with denormalized evidence[]/assets[] so the draft preview
        // resolves the same document bodies learners would get after publish.
        // Falls back to the bare draft when the lesson has no template or the
        // template row is missing — preview must stay available for drafts.
        JsonNode source = draft;
        if (l.getTemplateId() != null) {
            try {
                LessonTemplate tpl = templates.findById(l.getTemplateId()).orElse(null);
                if (tpl != null) {
                    source = snapshotBuilder.build(l, draft, tpl);
                }
            } catch (RuntimeException ignored) {
                // Missing evidence/asset rows in an unfinished draft must not
                // break preview; publish-time validation is authoritative.
                source = draft;
            }
        }
        return new com.dauviet.lesson.api.dto.LearnerLessonContent(
                l.getId(), null, null, learnerProjection.project(source));
    }

    @Transactional
    public AdminLessonResponse archive(UUID id, UUID adminId) {
        Lesson l = load(id);
        if (l.getStatus() == LessonStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("lesson already archived");
        }
        l.setStatus(LessonStatus.ARCHIVED);
        l.setUpdatedBy(adminId);
        return mapper.toResponse(lessons.saveAndFlush(l));
    }

    private Lesson load(UUID id) {
        return lessons.findById(id)
                .orElseThrow(() -> new LessonNotFoundException("Lesson not found: " + id));
    }

    private void checkVersion(Lesson l, Long expected) {
        if (expected != null && !expected.equals(l.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    Lesson.class, l.getId());
        }
    }
}
