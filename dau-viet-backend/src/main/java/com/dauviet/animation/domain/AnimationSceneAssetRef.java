package com.dauviet.animation.domain;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

/**
 * Asset reference recorded at publish time: (scene_version_id, asset_id, role).
 * Lets the asset service block retirement while a published manifest still
 * references the asset — the manifest text alone is not indexed for this.
 */
@Entity
@Table(name = "animation_scene_asset_refs")
@IdClass(AnimationSceneAssetRef.Key.class)
public class AnimationSceneAssetRef {

    @Id
    @Column(name = "scene_version_id", nullable = false, updatable = false)
    private UUID sceneVersionId;

    @Id
    @Column(name = "asset_id", nullable = false, updatable = false)
    private UUID assetId;

    @Id
    @Column(name = "role", nullable = false, length = 48, updatable = false)
    private String role;

    public AnimationSceneAssetRef() {
    }

    public AnimationSceneAssetRef(UUID sceneVersionId, UUID assetId, String role) {
        this.sceneVersionId = sceneVersionId;
        this.assetId = assetId;
        this.role = role;
    }

    public UUID getSceneVersionId() { return sceneVersionId; }
    public UUID getAssetId() { return assetId; }
    public String getRole() { return role; }

    /** Composite PK. */
    public static class Key implements Serializable {
        private UUID sceneVersionId;
        private UUID assetId;
        private String role;

        public Key() {
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key k)) return false;
            return Objects.equals(sceneVersionId, k.sceneVersionId)
                    && Objects.equals(assetId, k.assetId)
                    && Objects.equals(role, k.role);
        }

        @Override
        public int hashCode() {
            return Objects.hash(sceneVersionId, assetId, role);
        }
    }
}
