package com.dauviet.lesson.application;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Component;

import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.api.dto.PublishReadinessResponse;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.domain.LessonTemplate;
import com.dauviet.lesson.draft.DraftSchema;
import com.dauviet.lesson.draft.DraftValidator;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.ValidationLevel;
import com.dauviet.lesson.infrastructure.persistence.LessonTemplateRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Shared PUBLISH-level readiness evaluation used by both the /validate probe
 * (always 200) and the /publish flow (422 on errors). Produces no mutations.
 */
@Component
public class PublishReadinessEvaluator {

    private final LessonTemplateRepository templates;
    private final HistoricalEventRepository events;
    private final DraftValidator draftValidator;
    private final ObjectMapper objectMapper;

    public PublishReadinessEvaluator(LessonTemplateRepository templates,
                                     HistoricalEventRepository events,
                                     DraftValidator draftValidator,
                                     ObjectMapper objectMapper) {
        this.templates = templates;
        this.events = events;
        this.draftValidator = draftValidator;
        this.objectMapper = objectMapper;
    }

    /**
     * Collect readiness errors/warnings/summary for `lesson`.
     * Never throws on an unparseable draft — reports it as an error instead.
     */
    public PublishReadinessResponse evaluate(Lesson l) {
        List<Map<String, String>> warnings = new ArrayList<>();
        List<Map<String, String>> errors = new ArrayList<>();

        // Non-draft states can still be probed but report a warning.
        if (l.getStatus() != LessonStatus.DRAFT) {
            warnings.add(Map.of("code", "LESSON_NOT_DRAFT",
                    "message", "lesson status is " + l.getStatus()));
        }
        if (l.getCentralQuestion() == null || l.getCentralQuestion().isBlank()) {
            errors.add(Map.of("path", "centralQuestion",
                    "code", "MISSING_FIELD",
                    "message", "central question is required before publish"));
        }
        if (l.getObjectivesJson() == null || "[]".equals(l.getObjectivesJson().trim())) {
            warnings.add(Map.of("code", "NO_OBJECTIVES",
                    "message", "lesson has no learning objectives"));
        }
        LessonTemplate tpl = templates.findById(l.getTemplateId()).orElse(null);
        if (tpl == null) {
            errors.add(Map.of("path", "templateId",
                    "code", "TEMPLATE_NOT_FOUND", "message", "template missing"));
        } else if (!Boolean.TRUE.equals(tpl.getEnabled())) {
            errors.add(Map.of("path", "templateId",
                    "code", "TEMPLATE_DISABLED", "message", "template is disabled"));
        } else if (tpl.getSchemaVersion() == null
                || tpl.getSchemaVersion() != DraftSchema.CURRENT_VERSION) {
            errors.add(Map.of("path", "templateId",
                    "code", "TEMPLATE_SCHEMA_MISMATCH",
                    "message", "template schema_version " + tpl.getSchemaVersion()
                            + " does not match draft schemaVersion "
                            + DraftSchema.CURRENT_VERSION));
        }

        // Parent event not yet PUBLISHED: warn but do not block (open product
        // question — see plan §Open Questions). Missing event is a data-integrity
        // problem so it is an error, not a warning.
        var event = events.findById(l.getEventId()).orElse(null);
        if (event == null) {
            errors.add(Map.of("path", "eventId",
                    "code", "EVENT_NOT_FOUND", "message", "parent event missing"));
        } else if (event.getStatus() != EventStatus.PUBLISHED) {
            warnings.add(Map.of("code", "EVENT_NOT_PUBLISHED",
                    "message", "parent event status is " + event.getStatus()));
        }

        JsonNode draftNode;
        try {
            draftNode = objectMapper.readTree(
                    l.getDraftJson() == null ? "{}" : l.getDraftJson());
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            errors.add(Map.of("path", "draftJson", "code", "INVALID_DRAFT",
                    "message", "draft_json is not parseable"));
            return new PublishReadinessResponse(false, errors, warnings, Map.of());
        }
        List<FieldError> fieldErrors = draftValidator.validate(
                draftNode, l.getEventId(), ValidationLevel.PUBLISH);
        fieldErrors.forEach(fe -> errors.add(Map.of(
                "path", fe.path(), "code", fe.code(), "message", fe.message())));

        return new PublishReadinessResponse(errors.isEmpty(), errors, warnings,
                summarize(draftNode, errors.size(), warnings.size()));
    }

    private Map<String, Object> summarize(JsonNode draftNode, int errorCount, int warningCount) {
        int stageCount = 0;
        int activityCount = 0;
        int evidenceRefCount = 0;
        JsonNode stages = draftNode.get("stages");
        if (stages != null && stages.isArray()) {
            stageCount = stages.size();
            for (JsonNode s : stages) {
                JsonNode reqEv = s.get("requiredEvidenceIds");
                if (reqEv != null && reqEv.isArray()) evidenceRefCount += reqEv.size();
                JsonNode acts = s.get("activities");
                if (acts != null && acts.isArray()) {
                    activityCount += acts.size();
                    for (JsonNode a : acts) {
                        JsonNode refs = a.get("evidenceRefs");
                        if (refs != null && refs.isArray()) evidenceRefCount += refs.size();
                    }
                }
            }
        }
        return Map.of(
                "stageCount", stageCount,
                "activityCount", activityCount,
                "evidenceRefs", evidenceRefCount,
                "schemaVersion", draftNode.path("schemaVersion").asInt(-1),
                "errorCount", errorCount,
                "warningCount", warningCount);
    }
}
