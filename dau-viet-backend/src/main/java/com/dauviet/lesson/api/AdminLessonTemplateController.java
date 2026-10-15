package com.dauviet.lesson.api;

import java.util.List;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.lesson.api.dto.LessonTemplateResponse;
import com.dauviet.lesson.application.LessonTemplateService;

/**
 * Read-only lesson template endpoints (admin). Requires ROLE_CONTENT_ADMIN.
 */
@RestController
@RequestMapping("/api/v1/admin/lesson-templates")
public class AdminLessonTemplateController {

    private final LessonTemplateService service;

    public AdminLessonTemplateController(LessonTemplateService service) {
        this.service = service;
    }

    @GetMapping
    public List<LessonTemplateResponse> listEnabled() {
        return service.listEnabled();
    }

    @GetMapping("/{id}")
    public LessonTemplateResponse get(@PathVariable UUID id) {
        return service.get(id);
    }
}
