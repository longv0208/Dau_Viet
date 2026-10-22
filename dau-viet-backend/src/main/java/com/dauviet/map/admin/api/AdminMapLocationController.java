package com.dauviet.map.admin.api;

import java.util.List;
import java.util.UUID;

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

import com.dauviet.map.admin.AdminMapLocationService;
import com.dauviet.map.admin.dto.AdminMapLocationRequest;
import com.dauviet.map.admin.dto.AdminMapLocationResponse;
import com.dauviet.map.domain.MapLocationStatus;

import jakarta.validation.Valid;

/**
 * Admin map-location config nested under /admin/events/{eventId}.
 * ROLE_CONTENT_ADMIN via SecurityConfig on /api/v1/admin/**.
 */
@RestController
@RequestMapping("/api/v1/admin/events/{eventId}/map-locations")
@Validated
public class AdminMapLocationController {

    private final AdminMapLocationService service;

    public AdminMapLocationController(AdminMapLocationService service) {
        this.service = service;
    }

    @GetMapping
    public List<AdminMapLocationResponse> list(@PathVariable UUID eventId) {
        return service.list(eventId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AdminMapLocationResponse create(@PathVariable UUID eventId,
            @Valid @RequestBody AdminMapLocationRequest req) {
        return service.create(eventId, req);
    }

    @PatchMapping("/{locationId}")
    public AdminMapLocationResponse update(@PathVariable UUID eventId,
            @PathVariable UUID locationId,
            @Valid @RequestBody AdminMapLocationRequest req,
            @RequestParam(required = false) Long expectedRowVersion) {
        return service.update(eventId, locationId, req, expectedRowVersion);
    }

    /** Publish / archive a location (FR-36 visibility gate for learners). */
    @PostMapping("/{locationId}/status")
    public AdminMapLocationResponse setStatus(@PathVariable UUID eventId,
            @PathVariable UUID locationId,
            @RequestParam MapLocationStatus status) {
        return service.setStatus(eventId, locationId, status);
    }
}
