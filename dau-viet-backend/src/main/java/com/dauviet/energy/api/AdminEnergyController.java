package com.dauviet.energy.api;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.energy.api.dto.AdminEnergyDtos.AdminEnergyRemedyResponse;
import com.dauviet.energy.api.dto.AdminEnergyDtos.AdminEnergySettingsResponse;
import com.dauviet.energy.api.dto.AdminEnergyDtos.CreateEnergyRemedyRequest;
import com.dauviet.energy.api.dto.AdminEnergyDtos.PatchEnergyRemedyRequest;
import com.dauviet.energy.api.dto.AdminEnergyDtos.UpdateEnergyRemedyRequest;
import com.dauviet.energy.api.dto.AdminEnergyDtos.UpdateEnergySettingsRequest;
import com.dauviet.energy.application.AdminEnergyService;

/**
 * Admin API quản lý Viện Thái Y (GAME-07 Issue #28):
 * - GET/PUT /api/v1/admin/energy/settings — quy tắc Thể lực toàn cục.
 * - CRUD /api/v1/admin/energy/remedies — danh mục vật phẩm Viện Thái Y.
 *
 * <p>Authorization do SecurityConfig đảm bảo (admin role ở path /admin/**).
 * updated_by trong settings ghi nhận admin JWT subject.
 */
@RestController
@Validated
@RequestMapping("/api/v1/admin/energy")
public class AdminEnergyController {

    private final AdminEnergyService service;
    private final JwtSubjectExtractor subjects;

    public AdminEnergyController(AdminEnergyService service,
                                 JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /* ---------- Settings ---------- */

    @GetMapping("/settings")
    public AdminEnergySettingsResponse getSettings() {
        return service.getSettings();
    }

    @PutMapping("/settings")
    public AdminEnergySettingsResponse updateSettings(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UpdateEnergySettingsRequest req) {
        return service.updateSettings(req, subjects.userId(jwt));
    }

    /* ---------- Remedies ---------- */

    @GetMapping("/remedies")
    public List<AdminEnergyRemedyResponse> listRemedies() {
        return service.listRemedies();
    }

    @GetMapping("/remedies/{id}")
    public AdminEnergyRemedyResponse getRemedy(@PathVariable UUID id) {
        return service.getRemedy(id);
    }

    @PostMapping("/remedies")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminEnergyRemedyResponse createRemedy(
            @Valid @RequestBody CreateEnergyRemedyRequest req) {
        return service.createRemedy(req);
    }

    @PutMapping("/remedies/{id}")
    public AdminEnergyRemedyResponse updateRemedy(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateEnergyRemedyRequest req) {
        return service.updateRemedy(id, req);
    }

    @PatchMapping("/remedies/{id}")
    public AdminEnergyRemedyResponse patchRemedy(
            @PathVariable UUID id,
            @Valid @RequestBody PatchEnergyRemedyRequest req) {
        return service.patchRemedy(id, req);
    }

    @DeleteMapping("/remedies/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteRemedy(@PathVariable UUID id) {
        service.deleteRemedy(id);
    }
}
