package com.dauviet.animation.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import com.dauviet.animation.domain.AnimationExceptions.ManifestFieldError;

/** Admin DTOs for the animation engine — grouped (each is a thin record). */
public final class AnimationDtos {

    private AnimationDtos() {
    }

    /* ---------- templates ---------- */

    public record TemplateCreateRequest(
            @NotBlank @Pattern(regexp = "[A-Z0-9_]{2,64}") String code,
            @NotBlank @Size(max = 150) String name,
            String description,
            @NotBlank String rendererCode,
            Integer rendererVersion,
            Integer schemaVersion,
            String capabilitiesJson,
            String defaultConfigJson,
            UUID thumbnailAssetId,
            Boolean enabled) {
    }

    public record TemplateUpdateRequest(
            @Size(max = 150) String name,
            String description,
            String capabilitiesJson,
            String defaultConfigJson,
            UUID thumbnailAssetId,
            Boolean enabled,
            Long expectedRowVersion) {
    }

    public record TemplateResponse(
            UUID id, String code, String name, String description,
            String rendererCode, Integer rendererVersion, Integer schemaVersion,
            String capabilitiesJson, String defaultConfigJson,
            UUID thumbnailAssetId, Boolean enabled,
            Instant createdAt, Instant updatedAt) {
    }

    /* ---------- scenes ---------- */

    public record SceneCreateRequest(
            @NotNull UUID templateId,
            UUID eventId,
            @NotBlank @Size(max = 255) String title,
            String draftJson) {
    }

    public record SceneUpdateRequest(
            @Size(max = 255) String title,
            UUID eventId,
            boolean clearEvent,
            String draftJson,
            Long expectedRowVersion) {
    }

    public record SceneResponse(
            UUID id, UUID templateId, String templateCode, String rendererCode,
            UUID eventId, String title, String draftJson, String status,
            UUID currentVersionId, Integer currentVersionNo,
            Long rowVersion, Instant createdAt, Instant updatedAt) {
    }

    public record SceneSummaryResponse(
            UUID id, UUID templateId, String rendererCode, UUID eventId,
            String title, String status,
            UUID currentVersionId, Integer currentVersionNo,
            Long rowVersion, Instant updatedAt) {
    }

    /* ---------- versions ---------- */

    public record SceneVersionSummary(
            UUID id, Integer versionNo, Integer schemaVersion,
            String rendererCode, Integer rendererVersion, String manifestChecksum,
            Instant publishedAt, UUID publishedBy) {
    }

    public record SceneVersionDetail(
            UUID id, UUID sceneId, Integer versionNo, Integer schemaVersion,
            String rendererCode, Integer rendererVersion,
            String snapshotJson, String manifestChecksum,
            Instant publishedAt, UUID publishedBy) {
    }

    /* ---------- validate / publish ---------- */

    public record SceneValidationResponse(
            boolean ready,
            List<ManifestFieldError> errors) {
    }

    public record PublishRequest(Long expectedRowVersion) {
    }

    public record PublishResponse(
            UUID sceneId, UUID versionId, Integer versionNo,
            String status, Instant publishedAt) {
    }
}
