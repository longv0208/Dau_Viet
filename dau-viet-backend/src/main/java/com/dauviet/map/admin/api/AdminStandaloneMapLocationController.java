package com.dauviet.map.admin.api;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.map.admin.AdminMapLocationService;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.EventLinkInput;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.MediaInput;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.ReplaceUnlockLessonsRequest;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.StandaloneLocationRequest;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.StandaloneLocationResponse;
import com.dauviet.map.domain.MapLocationStatus;

import jakarta.validation.Valid;

/**
 * Standalone admin API for heritage locations (/api/v1/admin/map-locations).
 * Guarded by ROLE_CONTENT_ADMIN via SecurityConfig on /api/v1/admin/**.
 */
@RestController
@RequestMapping("/api/v1/admin/map-locations")
@Validated
public class AdminStandaloneMapLocationController {

    private final AdminMapLocationService service;

    public AdminStandaloneMapLocationController(AdminMapLocationService service) {
        this.service = service;
    }

    @GetMapping
    public List<StandaloneLocationResponse> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String kind,
            @RequestParam(required = false) MapLocationStatus status,
            @RequestParam(required = false) UUID eventId) {
        return service.listStandalone(q, kind, status, eventId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public StandaloneLocationResponse create(@Valid @RequestBody StandaloneLocationRequest req) {
        return service.createStandalone(req);
    }

    @GetMapping("/{locationId}")
    public StandaloneLocationResponse get(@PathVariable UUID locationId) {
        return service.getStandalone(locationId);
    }

    @PatchMapping("/{locationId}")
    public StandaloneLocationResponse update(
            @PathVariable UUID locationId,
            @Valid @RequestBody StandaloneLocationRequest req,
            @RequestParam(required = false) Long expectedRowVersion) {
        return service.updateStandalone(locationId, req, expectedRowVersion);
    }

    @PostMapping("/{locationId}/status")
    public StandaloneLocationResponse setStatus(
            @PathVariable UUID locationId,
            @RequestParam MapLocationStatus status,
            @RequestParam(required = false) Long expectedRowVersion) {
        return service.setStandaloneStatus(locationId, status, expectedRowVersion);
    }

    @PutMapping("/{locationId}/events")
    public StandaloneLocationResponse replaceEvents(
            @PathVariable UUID locationId,
            @Valid @RequestBody List<@Valid EventLinkInput> events) {
        return service.replaceEvents(locationId, events);
    }

    @PutMapping("/{locationId}/unlock-lessons")
    public StandaloneLocationResponse replaceUnlockLessons(
            @PathVariable UUID locationId,
            @Valid @RequestBody ReplaceUnlockLessonsRequest req) {
        return service.replaceUnlockLessons(locationId, req);
    }

    @PutMapping("/{locationId}/media")
    public StandaloneLocationResponse replaceMedia(
            @PathVariable UUID locationId,
            @Valid @RequestBody List<@Valid MediaInput> media) {
        return service.replaceMedia(locationId, media);
    }
}
