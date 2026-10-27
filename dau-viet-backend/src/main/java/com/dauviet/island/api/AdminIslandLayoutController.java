package com.dauviet.island.api;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.island.api.dto.AdminIslandLayoutDtos.CreateLayoutRequest;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.LayoutDetailResponse;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.LayoutSummaryResponse;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.RevisionRequest;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.UpdateDraftSnapshotRequest;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.UpdateLayoutRequest;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.ValidationReportResponse;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.VersionDetailResponse;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.VersionSummaryResponse;
import com.dauviet.island.application.IslandLayoutService;

/**
 * Admin API quản lý bố cục Đảo Di Sản có phiên bản (ISLAND-04).
 */
@RestController
@Validated
@RequestMapping("/api/v1/admin/island-layouts")
public class AdminIslandLayoutController {

    private final IslandLayoutService layoutService;

    public AdminIslandLayoutController(IslandLayoutService layoutService) {
        this.layoutService = layoutService;
    }

    @GetMapping
    public List<LayoutSummaryResponse> listLayouts() {
        return layoutService.listLayouts();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public LayoutDetailResponse createLayout(
            @Valid @RequestBody CreateLayoutRequest req) {
        return layoutService.createLayout(req);
    }

    @GetMapping("/{layoutId}")
    public LayoutDetailResponse getLayout(@PathVariable UUID layoutId) {
        return layoutService.getLayout(layoutId);
    }

    @PatchMapping("/{layoutId}")
    public LayoutDetailResponse updateLayout(
            @PathVariable UUID layoutId,
            @Valid @RequestBody UpdateLayoutRequest req) {
        return layoutService.updateLayout(layoutId, req);
    }

    @GetMapping("/{layoutId}/versions")
    public List<VersionSummaryResponse> listVersions(
            @PathVariable UUID layoutId) {
        return layoutService.listVersions(layoutId);
    }

    @PostMapping("/{layoutId}/versions")
    @ResponseStatus(HttpStatus.CREATED)
    public VersionDetailResponse createDraft(@PathVariable UUID layoutId) {
        return layoutService.createDraft(layoutId);
    }

    @GetMapping("/versions/{versionId}")
    public VersionDetailResponse getVersion(@PathVariable UUID versionId) {
        return layoutService.getVersion(versionId);
    }

    @PutMapping("/versions/{versionId}")
    public VersionDetailResponse saveDraftSnapshot(
            @PathVariable UUID versionId,
            @Valid @RequestBody UpdateDraftSnapshotRequest req) {
        return layoutService.saveDraftSnapshot(versionId, req);
    }

    @PostMapping("/versions/{versionId}/clone")
    @ResponseStatus(HttpStatus.CREATED)
    public VersionDetailResponse cloneVersion(@PathVariable UUID versionId) {
        return layoutService.cloneVersionToDraft(versionId);
    }

    @GetMapping("/versions/{versionId}/validate")
    public ValidationReportResponse validateVersion(
            @PathVariable UUID versionId) {
        return layoutService.validateVersion(versionId);
    }

    @PostMapping("/versions/{versionId}/publish")
    public VersionDetailResponse publishVersion(
            @PathVariable UUID versionId,
            @Valid @RequestBody RevisionRequest req) {
        return layoutService.publishVersion(versionId, req);
    }

    @PostMapping("/versions/{versionId}/archive")
    public VersionDetailResponse archiveVersion(
            @PathVariable UUID versionId,
            @Valid @RequestBody RevisionRequest req) {
        return layoutService.archiveVersion(versionId, req);
    }
}
