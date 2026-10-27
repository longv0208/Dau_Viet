package com.dauviet.lesson.api;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.api.PageResponse;
import com.dauviet.lesson.api.dto.AdminLessonTemplateCreateRequest;
import com.dauviet.lesson.api.dto.AdminLessonTemplateUpdateRequest;
import com.dauviet.lesson.api.dto.LessonTemplateResponse;
import com.dauviet.lesson.application.LessonTemplateService;

/**
 * Lesson template endpoints (admin). Requires ROLE_CONTENT_ADMIN.
 */
@RestController
@RequestMapping("/api/v1/admin/lesson-templates")
@Validated
public class AdminLessonTemplateController {

    private final LessonTemplateService service;

    public AdminLessonTemplateController(LessonTemplateService service) {
        this.service = service;
    }

    @GetMapping
    public List<LessonTemplateResponse> listEnabled() {
        return service.listEnabled();
    }

    @GetMapping(params = "page")
    public PageResponse<LessonTemplateResponse> listPaged(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) Boolean enabled,
            @RequestParam(required = false) String q) {
        Pageable pageable = PageRequest.of(page, size);
        return PageResponse.from(service.list(enabled, q, pageable));
    }

    @GetMapping("/{id}")
    public LessonTemplateResponse get(@PathVariable UUID id) {
        return service.get(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public LessonTemplateResponse create(@Valid @RequestBody AdminLessonTemplateCreateRequest req) {
        return service.create(req);
    }

    @PatchMapping("/{id}")
    public LessonTemplateResponse update(@PathVariable UUID id,
                                         @Valid @RequestBody AdminLessonTemplateUpdateRequest req) {
        return service.update(id, req);
    }
}
