package com.dauviet.lesson.application;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.lesson.api.dto.AdminLessonTemplateCreateRequest;
import com.dauviet.lesson.api.dto.AdminLessonTemplateUpdateRequest;
import com.dauviet.lesson.api.dto.LessonTemplateResponse;
import com.dauviet.lesson.domain.LessonTemplate;
import com.dauviet.lesson.domain.TemplateCodeTakenException;
import com.dauviet.lesson.domain.TemplateNotFoundException;
import com.dauviet.lesson.draft.DraftSchema;
import com.dauviet.lesson.draft.DraftValidationException;
import com.dauviet.lesson.draft.DraftValidator;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.ValidationLevel;
import com.dauviet.lesson.infrastructure.persistence.LessonTemplateRepository;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Admin access to lesson templates — list/read plus skeleton authoring. */
@Service
public class LessonTemplateService {

    private final LessonTemplateRepository templates;
    private final DraftValidator draftValidator;
    private final ObjectMapper objectMapper;

    public LessonTemplateService(LessonTemplateRepository templates,
                                 DraftValidator draftValidator,
                                 ObjectMapper objectMapper) {
        this.templates = templates;
        this.draftValidator = draftValidator;
        this.objectMapper = objectMapper;
    }

    @Transactional(readOnly = true)
    public List<LessonTemplateResponse> listEnabled() {
        return templates.findAllByEnabledTrue().stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public LessonTemplateResponse get(UUID id) {
        return templates.findById(id).map(this::toDto)
                .orElseThrow(() -> new TemplateNotFoundException("Template not found: " + id));
    }

    /**
     * Create an enabled template. The preset must be a valid draft-shaped
     * skeleton (SAVE-level check — stages with valid ids/types/nextStageIds;
     * incomplete activities are tolerated so the wizard can stay minimal).
     */
    @Transactional
    public LessonTemplateResponse create(AdminLessonTemplateCreateRequest req) {
        String code = req.code().trim();
        templates.findByCode(code).ifPresent(t -> {
            throw new TemplateCodeTakenException("Template code already exists: " + code);
        });

        String preset = validatePreset(req.presetJson());

        LessonTemplate t = LessonTemplate.create(
                UUID.randomUUID(),
                code,
                req.name().trim(),
                req.description() == null ? null : req.description().trim(),
                DraftSchema.CURRENT_VERSION,
                preset);
        return toDto(templates.saveAndFlush(t));
    }

    /**
     * Partial update — null fields stay unchanged. presetJson revalidated at
     * SAVE level when provided so an edit cannot corrupt the skeleton.
     */
    @Transactional
    public LessonTemplateResponse update(UUID id, AdminLessonTemplateUpdateRequest req) {
        LessonTemplate t = templates.findById(id)
                .orElseThrow(() -> new TemplateNotFoundException("Template not found: " + id));
        if (req.name() != null) t.setName(req.name().trim());
        if (req.description() != null) t.setDescription(req.description().trim());
        if (req.enabled() != null) t.setEnabled(req.enabled());
        if (req.presetJson() != null) {
            t.setPresetJson(validatePreset(req.presetJson()));
        }
        return toDto(templates.saveAndFlush(t));
    }

    private String validatePreset(String presetJson) {
        String preset = DraftValidator.requireJsonObject(presetJson, "presetJson");
        JsonNode presetNode;
        try {
            presetNode = objectMapper.readTree(preset);
        } catch (com.fasterxml.jackson.core.JsonProcessingException ex) {
            throw new com.dauviet.lesson.domain.DraftSchemaInvalidException(
                    "presetJson is not valid JSON");
        }
        List<FieldError> errs = draftValidator.validate(presetNode, null, ValidationLevel.SAVE);
        if (!errs.isEmpty()) {
            throw new DraftValidationException(errs);
        }
        return preset;
    }

    private LessonTemplateResponse toDto(LessonTemplate t) {
        return new LessonTemplateResponse(
                t.getId(), t.getCode(), t.getName(), t.getDescription(),
                t.getSchemaVersion(), t.getPresetJson(), t.getEnabled(),
                t.getCreatedAt(), t.getUpdatedAt());
    }
}
