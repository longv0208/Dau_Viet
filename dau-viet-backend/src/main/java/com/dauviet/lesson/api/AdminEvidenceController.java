package com.dauviet.lesson.api;

import java.util.Set;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
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

import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.common.api.PageResponse;
import com.dauviet.lesson.api.dto.EvidenceArchiveRequest;
import com.dauviet.lesson.api.dto.EvidencePatchRequest;
import com.dauviet.lesson.api.dto.EvidenceResponse;
import com.dauviet.lesson.api.dto.EvidenceUpsertRequest;
import com.dauviet.lesson.application.EvidenceService;
import com.dauviet.lesson.domain.EvidenceStatus;

/**
 * Admin CRUD for source-backed evidence rows. Archive is the destructive
 * path and refuses while a published snapshot references the evidence.
 */
@RestController
@RequestMapping("/api/v1/admin/evidences")
@Validated
public class AdminEvidenceController {

    private static final Set<String> ALLOWED_SORT_FIELDS =
            Set.of("title", "createdAt", "updatedAt", "status", "evidenceType");
    private static final Sort DEFAULT_SORT = Sort.by(Sort.Direction.DESC, "updatedAt");

    private final EvidenceService service;

    public AdminEvidenceController(EvidenceService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public EvidenceResponse create(@Valid @RequestBody EvidenceUpsertRequest req,
                                   @AuthenticationPrincipal Jwt jwt) {
        return service.create(req, adminId(jwt));
    }

    @GetMapping
    public PageResponse<EvidenceResponse> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "updatedAt,desc") String sort,
            @RequestParam(required = false) UUID eventId,
            @RequestParam(required = false) EvidenceStatus status,
            @RequestParam(required = false) String q) {
        Pageable pageable = PageRequest.of(page, size, parseSort(sort));
        return PageResponse.from(service.list(eventId, status, q, pageable));
    }

    @GetMapping("/{id}")
    public EvidenceResponse get(@PathVariable UUID id) {
        return service.get(id);
    }

    @PatchMapping("/{id}")
    public EvidenceResponse update(@PathVariable UUID id,
                                   @Valid @RequestBody EvidencePatchRequest req) {
        return service.update(id, req);
    }

    @PostMapping("/{id}/approve")
    public EvidenceResponse approve(@PathVariable UUID id) {
        return service.approve(id);
    }

    @PostMapping("/{id}/archive")
    public EvidenceResponse archive(@PathVariable UUID id,
                                    @RequestBody(required = false) EvidenceArchiveRequest req) {
        return service.archive(id, req == null ? null : req.expectedRowVersion());
    }

    private UUID adminId(Jwt jwt) {
        try {
            return UUID.fromString(jwt.getSubject());
        } catch (RuntimeException ex) {
            throw new AuthenticationFailedException();
        }
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
