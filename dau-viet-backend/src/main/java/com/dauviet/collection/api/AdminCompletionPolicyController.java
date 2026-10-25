package com.dauviet.collection.api;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.AdminCompletionPolicyResponse;
import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.AdminCompletionPolicyUpsertRequest;
import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.AdminPolicyPublishRequest;
import com.dauviet.collection.api.dto.AdminCompletionPolicyDtos.AdminPolicyValidationResponse;
import com.dauviet.collection.application.AdminCompletionPolicyService;

import jakarta.validation.Valid;

/**
 * Admin endpoints cho event completion policy (GAME-06 Module A).
 * Moi route duoi /api/v1/admin/** da duoc CONTENT_ADMIN guard boi
 * SecurityConfig — khong can @PreAuthorize rieng.
 */
@RestController
@RequestMapping("/api/v1/admin/events/{eventId}/completion-policies")
@Validated
public class AdminCompletionPolicyController {

    private final AdminCompletionPolicyService service;

    public AdminCompletionPolicyController(AdminCompletionPolicyService service) {
        this.service = service;
    }

    /** List moi version (DRAFT/PUBLISHED/ARCHIVED), moi nhat truoc. */
    @GetMapping
    public List<AdminCompletionPolicyResponse> list(@PathVariable UUID eventId) {
        return service.list(eventId);
    }

    @GetMapping("/{policyId}")
    public AdminCompletionPolicyResponse detail(@PathVariable UUID eventId,
            @PathVariable UUID policyId) {
        return service.get(eventId, policyId);
    }

    /** Tao DRAFT moi — version = maxVersion+1 (copy-on-write tu PUBLISHED). */
    @PostMapping
    public ResponseEntity<AdminCompletionPolicyResponse> create(
            @PathVariable UUID eventId,
            @Valid @RequestBody AdminCompletionPolicyUpsertRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.create(eventId, req));
    }

    /** Sua DRAFT in-place giu policyId. 400 khi status != DRAFT. */
    @PutMapping("/{policyId}")
    public AdminCompletionPolicyResponse updateDraft(@PathVariable UUID eventId,
            @PathVariable UUID policyId,
            @Valid @RequestBody AdminCompletionPolicyUpsertRequest req) {
        return service.updateDraft(eventId, policyId, req);
    }

    /**
     * Dry-run validate. Body rong/nullable = validate DRAFT hien tai;
     * body co du lieu = validate payload admin sap luu (khong ghi DB).
     */
    @PostMapping("/{policyId}/validate")
    public AdminPolicyValidationResponse validate(@PathVariable UUID eventId,
            @PathVariable UUID policyId,
            @RequestBody(required = false) @Valid AdminCompletionPolicyUpsertRequest req) {
        return service.validate(eventId, policyId, req);
    }

    /**
     * Atomic publish: lock event -> revalidate -> archive PUBLISHED cu ->
     * publish DRAFT. 409 stale version, 422 khi validate fail.
     */
    @PostMapping("/{policyId}/publish")
    public AdminCompletionPolicyResponse publish(@PathVariable UUID eventId,
            @PathVariable UUID policyId,
            @Valid @RequestBody(required = false) AdminPolicyPublishRequest req) {
        Integer expected = req == null ? null : req.expectedPolicyVersion();
        return service.publish(eventId, policyId, expected);
    }
}
