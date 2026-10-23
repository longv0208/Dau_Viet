package com.dauviet.animation.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.animation.api.dto.AnimationDtos.PublishResponse;
import com.dauviet.animation.domain.AnimationExceptions.InvalidStatusTransitionException;
import com.dauviet.animation.domain.AnimationExceptions.ManifestFieldError;
import com.dauviet.animation.domain.AnimationExceptions.ManifestValidationException;
import com.dauviet.animation.domain.AnimationExceptions.SceneNotFoundException;
import com.dauviet.animation.domain.AnimationExceptions.TemplateNotFoundException;
import com.dauviet.animation.domain.AnimationScene;
import com.dauviet.animation.domain.AnimationSceneAssetRef;
import com.dauviet.animation.domain.AnimationSceneStatus;
import com.dauviet.animation.domain.AnimationSceneVersion;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneAssetRefRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneVersionRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationTemplateRepository;
import com.dauviet.animation.manifest.AnimationManifestValidator;
import com.dauviet.lesson.domain.Asset;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Transactional publish: validate the draft manifest at PUBLISH level, insert
 * an immutable animation_scene_versions snapshot (with embedded asset
 * metadata + checksum), record asset refs, and rotate
 * animation_scenes.current_version_id in one transaction. A pessimistic lock
 * on the scene row serializes concurrent publishes so version_no allocation
 * cannot race; UNIQUE(scene_id, version_no) remains the backstop.
 */
@Service
public class AnimationScenePublishService {

    private final AnimationSceneRepository scenes;
    private final AnimationTemplateRepository templates;
    private final AnimationSceneVersionRepository versions;
    private final AnimationSceneAssetRefRepository assetRefs;
    private final AssetRepository assets;
    private final AnimationManifestValidator validator;
    private final ObjectMapper objectMapper;

    public AnimationScenePublishService(AnimationSceneRepository scenes,
                                        AnimationTemplateRepository templates,
                                        AnimationSceneVersionRepository versions,
                                        AnimationSceneAssetRefRepository assetRefs,
                                        AssetRepository assets,
                                        AnimationManifestValidator validator,
                                        ObjectMapper objectMapper) {
        this.scenes = scenes;
        this.templates = templates;
        this.versions = versions;
        this.assetRefs = assetRefs;
        this.assets = assets;
        this.validator = validator;
        this.objectMapper = objectMapper;
    }

    /** Publish the current draft as a new immutable version. */
    @Transactional
    public PublishResponse publish(UUID sceneId, Long expectedRowVersion, UUID adminId) {
        AnimationScene scene = scenes.findForUpdate(sceneId)
                .orElseThrow(() -> new SceneNotFoundException(
                        "Animation scene not found: " + sceneId));
        if (scene.getStatus() == AnimationSceneStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived scene cannot be published");
        }
        if (expectedRowVersion != null && !expectedRowVersion.equals(scene.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    AnimationScene.class, scene.getId());
        }

        AnimationTemplate template = templates.findById(scene.getTemplateId())
                .orElseThrow(() -> new TemplateNotFoundException(
                        "Template not found: " + scene.getTemplateId()));

        JsonNode manifest = parse(scene.getDraftJson());
        var errors = validator.validate(manifest, template);
        if (!errors.isEmpty()) {
            throw new ManifestValidationException(errors);
        }

        // Snapshot = validated manifest + pinned asset metadata so a later
        // asset edit/rename cannot retroactively change a published manifest.
        // assets[] keeps {id (manifest key), assetId, role} + metadata.
        ObjectNode snapshot = manifest.deepCopy();
        snapshot.set("assets", embedAssets(collectAssetRefs(manifest)));

        // Checksum covers the canonical snapshot text — what is stored and what
        // the learner actually receives (manifest + embedded assets), matching
        // the V15 seed recipe encode(digest(snapshot_json::text,'sha256'),'hex').
        String snapshotText = write(snapshot);

        int versionNo = versions.findTopBySceneIdOrderByVersionNoDesc(sceneId)
                .map(v -> v.getVersionNo() + 1).orElse(1);
        AnimationSceneVersion version = new AnimationSceneVersion();
        version.setId(UUID.randomUUID());
        version.setSceneId(sceneId);
        version.setVersionNo(versionNo);
        // P1 §8 — ghi đúng schemaVersion THỰC của manifest, không phải
        // CURRENT_SCHEMA_VERSION: publish manifest v1 → schema_version=1,
        // v2 → 2. Không tự "upgrade" nhãn version khi payload vẫn v1.
        // Validator đảm bảo schemaVersion có mặt và >= 1 — không default.
        version.setSchemaVersion(manifest.path("schemaVersion").asInt());
        version.setRendererCode(template.getRendererCode());
        version.setRendererVersion(template.getRendererVersion());
        version.setSnapshotJson(snapshotText);
        version.setManifestChecksum(sha256(snapshotText));
        version.setPublishedAt(Instant.now());
        version.setPublishedBy(adminId);
        AnimationSceneVersion saved = versions.saveAndFlush(version);

        // Record asset references for the ASSET_IN_USE retirement check.
        for (AssetRef ref : collectAssetRefs(manifest)) {
            assetRefs.save(new AnimationSceneAssetRef(saved.getId(), ref.assetId(), ref.role()));
        }

        scene.setStatus(AnimationSceneStatus.PUBLISHED);
        scene.setCurrentVersionId(saved.getId());
        scene.setUpdatedBy(adminId);
        scenes.saveAndFlush(scene);

        return new PublishResponse(sceneId, saved.getId(), versionNo,
                scene.getStatus().name(), saved.getPublishedAt());
    }

    /* ---------- snapshot helpers ---------- */

    /**
     * manifestKey = the draft's declared assets[].id (binding key inside the
     * manifest); assetId = the real Asset row; role = BACKGROUND/OBJECT/…
     */
    private record AssetRef(String manifestKey, UUID assetId, String role) {
    }

    private Set<AssetRef> collectAssetRefs(JsonNode manifest) {
        Set<AssetRef> refs = new LinkedHashSet<>();
        JsonNode arr = manifest.get("assets");
        if (arr != null && arr.isArray()) {
            for (JsonNode a : arr) {
                UUID id = parseUuid(a.path("assetId").asText(null));
                if (id != null) {
                    refs.add(new AssetRef(a.path("id").asText(null), id,
                            a.path("role").asText("OBJECT")));
                }
            }
        }
        JsonNode map = manifest.get("map");
        if (map != null) {
            UUID bg = parseUuid(map.path("backgroundAssetId").asText(null));
            if (bg != null) refs.add(new AssetRef("background", bg, "BACKGROUND"));
        }
        return refs;
    }

    private com.fasterxml.jackson.databind.node.ArrayNode embedAssets(
            Set<AssetRef> refs) {
        var out = objectMapper.createArrayNode();
        if (refs.isEmpty()) return out;
        Set<UUID> ids = new LinkedHashSet<>();
        for (AssetRef r : refs) ids.add(r.assetId());
        Map<UUID, Asset> byId = new HashMap<>();
        for (Asset a : assets.findAllById(ids)) byId.put(a.getId(), a);
        for (AssetRef ref : refs) {
            Asset a = byId.get(ref.assetId());
            if (a == null) continue; // validator already rejects missing assets
            ObjectNode node = objectMapper.createObjectNode();
            // Keep the manifest binding: stable key + assetId + role — the
            // learner resolves assetId → bytes; publish must never lose
            // role/binding when replacing assets[] with metadata.
            node.put("id", ref.manifestKey() == null
                    ? a.getId().toString() : ref.manifestKey());
            node.put("assetId", a.getId().toString());
            node.put("role", ref.role());
            node.put("storageKey", a.getStorageKey());
            node.put("mimeType", a.getMimeType());
            node.put("sizeBytes", a.getSizeBytes());
            if (a.getOriginalFilename() != null) {
                node.put("originalFilename", a.getOriginalFilename());
            }
            if (a.getAltText() != null) node.put("altText", a.getAltText());
            out.add(node);
        }
        return out;
    }

    private JsonNode parse(String json) {
        try {
            return objectMapper.readTree(json == null ? "{}" : json);
        } catch (Exception e) {
            throw new ManifestValidationException(java.util.List.of(
                    new ManifestFieldError("draftJson", "INVALID_JSON",
                            "draft_json is not parseable")));
        }
    }

    private String write(JsonNode node) {
        try {
            return objectMapper.writeValueAsString(node);
        } catch (Exception e) {
            throw new IllegalStateException("manifest serialization failed", e);
        }
    }

    private static String sha256(String text) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(
                    md.digest(text.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("checksum failed", e);
        }
    }

    private static UUID parseUuid(String text) {
        if (text == null) return null;
        try {
            return UUID.fromString(text);
        } catch (RuntimeException e) {
            return null;
        }
    }
}
