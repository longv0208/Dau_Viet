package com.dauviet.lesson.application;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.lesson.api.dto.LessonTemplateResponse;
import com.dauviet.lesson.domain.LessonTemplate;
import com.dauviet.lesson.domain.TemplateNotFoundException;
import com.dauviet.lesson.infrastructure.persistence.LessonTemplateRepository;

/** Read-only access to lesson templates (admin tooling). */
@Service
public class LessonTemplateService {

    private final LessonTemplateRepository templates;

    public LessonTemplateService(LessonTemplateRepository templates) {
        this.templates = templates;
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

    private LessonTemplateResponse toDto(LessonTemplate t) {
        return new LessonTemplateResponse(
                t.getId(), t.getCode(), t.getName(), t.getDescription(),
                t.getSchemaVersion(), t.getPresetJson(), t.getEnabled(),
                t.getCreatedAt(), t.getUpdatedAt());
    }
}
