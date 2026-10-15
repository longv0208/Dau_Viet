package com.dauviet.historicalevent.admin.api;

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

import com.dauviet.common.api.PageResponse;
import com.dauviet.historicalevent.admin.AdminEventService;
import com.dauviet.historicalevent.admin.dto.AdminEventCreateRequest;
import com.dauviet.historicalevent.admin.dto.AdminEventResponse;
import com.dauviet.historicalevent.admin.dto.AdminEventSummaryResponse;
import com.dauviet.historicalevent.admin.dto.AdminEventUpdateRequest;
import com.dauviet.historicalevent.domain.EventStatus;

/**
 * Admin CRUD + publish/archive for historical events.
 * Requires ROLE_CONTENT_ADMIN (enforced by SecurityConfig on /api/v1/admin/**).
 */
@RestController
@RequestMapping("/api/v1/admin/events")
@Validated
public class AdminEventController {

    private static final Set<String> ALLOWED_SORT_FIELDS =
            Set.of("title", "slug", "startYear", "createdAt", "updatedAt", "status");
    private static final Sort DEFAULT_SORT = Sort.by(Sort.Direction.DESC, "updatedAt");

    private final AdminEventService service;

    public AdminEventController(AdminEventService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AdminEventResponse create(@Valid @RequestBody AdminEventCreateRequest req) {
        return service.create(req);
    }

    @GetMapping
    public PageResponse<AdminEventSummaryResponse> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "updatedAt,desc") String sort,
            @RequestParam(required = false) EventStatus status,
            @RequestParam(required = false) String q) {
        Pageable pageable = PageRequest.of(page, size, parseSort(sort));
        return PageResponse.from(service.list(status, q, pageable));
    }

    @GetMapping("/{id}")
    public AdminEventResponse get(@PathVariable UUID id) {
        return service.get(id);
    }

    @PatchMapping("/{id}")
    public AdminEventResponse update(@PathVariable UUID id,
                                     @Valid @RequestBody AdminEventUpdateRequest req) {
        return service.update(id, req);
    }

    @PostMapping("/{id}/publish")
    public AdminEventResponse publish(@PathVariable UUID id) {
        return service.publish(id);
    }

    @PostMapping("/{id}/archive")
    public AdminEventResponse archive(@PathVariable UUID id) {
        return service.archive(id);
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
