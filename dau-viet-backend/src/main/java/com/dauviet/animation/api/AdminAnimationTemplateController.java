package com.dauviet.animation.api;

import java.util.Set;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
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

import com.dauviet.animation.api.dto.AnimationDtos.TemplateCreateRequest;
import com.dauviet.animation.api.dto.AnimationDtos.TemplateResponse;
import com.dauviet.animation.api.dto.AnimationDtos.TemplateUpdateRequest;
import com.dauviet.animation.application.AnimationTemplateService;
import com.dauviet.common.api.PageResponse;

/** Admin animation template CRUD. Requires ROLE_CONTENT_ADMIN. */
@RestController
@RequestMapping("/api/v1/admin/animation-templates")
@Validated
public class AdminAnimationTemplateController {

    private static final Set<String> ALLOWED_SORT_FIELDS =
            Set.of("name", "code", "createdAt", "updatedAt");
    private static final Sort DEFAULT_SORT = Sort.by(Sort.Direction.ASC, "code");

    private final AnimationTemplateService service;

    public AdminAnimationTemplateController(AnimationTemplateService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TemplateResponse create(@Valid @RequestBody TemplateCreateRequest req) {
        return service.create(req);
    }

    @GetMapping
    public PageResponse<TemplateResponse> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "code,asc") String sort,
            @RequestParam(required = false) String rendererCode,
            @RequestParam(required = false) Boolean enabled,
            @RequestParam(required = false) String q) {
        Pageable pageable = PageRequest.of(page, size, parseSort(sort));
        return PageResponse.from(service.list(rendererCode, enabled, q, pageable));
    }

    @GetMapping("/{id}")
    public TemplateResponse get(@PathVariable UUID id) {
        return service.get(id);
    }

    @PatchMapping("/{id}")
    public TemplateResponse update(@PathVariable UUID id,
                                   @Valid @RequestBody TemplateUpdateRequest req) {
        return service.update(id, req);
    }

    private Sort parseSort(String sort) {
        if (sort == null || sort.isBlank()) return DEFAULT_SORT;
        String[] parts = sort.split(",");
        if (parts.length > 2) {
            throw new IllegalArgumentException("Malformed sort parameter: " + sort);
        }
        String field = parts[0].trim();
        if (!ALLOWED_SORT_FIELDS.contains(field)) {
            throw new IllegalArgumentException("Unsupported sort field: " + field);
        }
        if (parts.length == 1) return Sort.by(Sort.Direction.ASC, field);
        String dir = parts[1].trim().toLowerCase();
        if (!dir.equals("asc") && !dir.equals("desc")) {
            throw new IllegalArgumentException("Unsupported sort direction: " + parts[1].trim());
        }
        return Sort.by(Sort.Direction.fromString(dir), field);
    }
}
