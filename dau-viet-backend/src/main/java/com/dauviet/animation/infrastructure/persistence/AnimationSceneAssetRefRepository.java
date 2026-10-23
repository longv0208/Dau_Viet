package com.dauviet.animation.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.dauviet.animation.domain.AnimationSceneAssetRef;

@Repository
public interface AnimationSceneAssetRefRepository
        extends JpaRepository<AnimationSceneAssetRef, AnimationSceneAssetRef.Key> {

    /** All refs pointing at an asset — drives the ASSET_IN_USE retirement check. */
    List<AnimationSceneAssetRef> findByAssetId(UUID assetId);

    void deleteBySceneVersionId(UUID sceneVersionId);
}
