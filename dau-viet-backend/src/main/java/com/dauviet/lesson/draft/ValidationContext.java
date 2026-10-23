package com.dauviet.lesson.draft;

import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Carries what a validator needs beyond the JSON itself:
 * the lesson's event (evidence refs must belong to it) and lookups
 * resolved by the caller so validators stay persistence-free.
 */
public record ValidationContext(
        UUID eventId,
        ValidationLevel level,
        Set<String> validEvidenceIds,
        Set<String> activeAssetIds,
        Map<String, UUID> sceneVersionToScene,
        Set<UUID> publishedSceneIds) {

    /** Back-compat constructor for callers predating animation scenes. */
    public ValidationContext(UUID eventId, ValidationLevel level,
                             Set<String> validEvidenceIds, Set<String> activeAssetIds) {
        this(eventId, level, validEvidenceIds, activeAssetIds, Map.of(), Set.of());
    }

    /** Back-compat constructor without publishedSceneIds. */
    public ValidationContext(UUID eventId, ValidationLevel level,
                             Set<String> validEvidenceIds, Set<String> activeAssetIds,
                             Map<String, UUID> sceneVersionToScene) {
        this(eventId, level, validEvidenceIds, activeAssetIds,
                sceneVersionToScene, Set.of());
    }

    /** True when an evidence id exists, belongs to this event, and is publishable. */
    public boolean evidenceUsable(String evidenceId) {
        return validEvidenceIds != null && validEvidenceIds.contains(evidenceId);
    }

    public boolean assetUsable(String assetId) {
        return activeAssetIds != null && activeAssetIds.contains(assetId);
    }

    /** True when an animation_scene_versions id exists (published manifest). */
    public boolean sceneVersionUsable(String versionId) {
        return sceneVersionToScene != null && sceneVersionToScene.containsKey(versionId);
    }

    /**
     * Owning scene id of a published version, or null when the version id is
     * unknown. Used to detect animationSceneId ≠ version.sceneId mismatches.
     */
    public UUID sceneOfVersion(String versionId) {
        return sceneVersionToScene == null ? null : sceneVersionToScene.get(versionId);
    }

    /** True when the scene has at least one published version. */
    public boolean sceneHasPublishedVersion(String sceneId) {
        if (publishedSceneIds == null || sceneId == null) return false;
        try {
            return publishedSceneIds.contains(UUID.fromString(sceneId));
        } catch (RuntimeException e) {
            return false;
        }
    }

    public boolean isPublish() {
        return level == ValidationLevel.PUBLISH;
    }
}
