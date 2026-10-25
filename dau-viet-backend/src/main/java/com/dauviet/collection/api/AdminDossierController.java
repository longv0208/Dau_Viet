package com.dauviet.collection.api;

import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.collection.api.dto.AdminDossierDtos.AdminDossierCreateRequest;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminDossierDetailResponse;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminDossierSummaryResponse;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminDossierUpdateRequest;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminEventDossierLinkRequest;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminEventDossierLinkResponse;
import com.dauviet.collection.application.AdminDossierService;
import com.dauviet.common.api.PageResponse;
import com.dauviet.common.security.JwtSubjectExtractor;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/**
 * Admin endpoints cho historical dossiers (GAME-06 Module B):
 * CRUD + publish/archive + event-dossier link management.
 * /api/v1/admin/** da duoc CONTENT_ADMIN guard boi SecurityConfig.
 */
@RestController
@RequestMapping("/api/v1/admin")
@Validated
public class AdminDossierController {

    private final AdminDossierService service;
    private final JwtSubjectExtractor subjects;

    public AdminDossierController(AdminDossierService service,
            JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /* ---------- dossier CRUD ---------- */

    @GetMapping("/dossiers")
    public PageResponse<AdminDossierSummaryResponse> list(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "updatedAt,desc") String sort) {
        Sort s = Sort.by(sort.split(",")[0]);
        if (sort.endsWith(",desc")) {
            s = s.descending();
        } else {
            s = s.ascending();
        }
        Page<AdminDossierSummaryResponse> p = service.list(type, status, q,
                PageRequest.of(page, size, s));
        return PageResponse.from(p);
    }

    @PostMapping("/dossiers")
    public ResponseEntity<AdminDossierDetailResponse> create(
            @Valid @RequestBody AdminDossierCreateRequest req,
            @AuthenticationPrincipal Jwt jwt) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.create(req, subjects.userId(jwt)));
    }

    @GetMapping("/dossiers/{id}")
    public AdminDossierDetailResponse detail(@PathVariable UUID id) {
        return service.get(id);
    }

    @PutMapping("/dossiers/{id}")
    public AdminDossierDetailResponse update(@PathVariable UUID id,
            @Valid @RequestBody AdminDossierUpdateRequest req) {
        return service.update(id, req);
    }

    /** Publish: validate -> dossier_version++ -> snapshot V28 row. */
    @PostMapping("/dossiers/{id}/publish")
    public AdminDossierDetailResponse publish(@PathVariable UUID id,
            @AuthenticationPrincipal Jwt jwt) {
        return service.publish(id, subjects.userId(jwt));
    }

    /** Archive: learner da unlock van doc duoc — chi an khoi catalog moi. */
    @PostMapping("/dossiers/{id}/archive")
    public AdminDossierDetailResponse archive(@PathVariable UUID id) {
        return service.archive(id);
    }

    /* ---------- event-dossier links ---------- */

    @GetMapping("/events/{eventId}/dossiers")
    public List<AdminEventDossierLinkResponse> listEventLinks(
            @PathVariable UUID eventId) {
        return service.listEventLinks(eventId);
    }

    /**
     * Replace-list: dossierId moi phai PUBLISHED; displayOrder >= 0,
     * khong trung. Lazy reconcile pick up link moi — khong fan-out.
     */
    @PutMapping("/events/{eventId}/dossiers")
    public List<AdminEventDossierLinkResponse> replaceEventLinks(
            @PathVariable UUID eventId,
            @Valid @RequestBody List<AdminEventDossierLinkRequest> req) {
        return service.replaceEventLinks(eventId, req);
    }
}
