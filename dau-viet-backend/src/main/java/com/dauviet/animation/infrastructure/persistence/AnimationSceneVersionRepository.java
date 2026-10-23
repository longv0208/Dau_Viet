package com.dauviet.animation.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.dauviet.animation.domain.AnimationSceneVersion;

@Repository
public interface AnimationSceneVersionRepository
        extends JpaRepository<AnimationSceneVersion, UUID> {

    Optional<AnimationSceneVersion> findTopBySceneIdOrderByVersionNoDesc(UUID sceneId);

    Optional<AnimationSceneVersion> findBySceneIdAndVersionNo(UUID sceneId, Integer versionNo);

    List<AnimationSceneVersion> findBySceneIdOrderByVersionNoDesc(UUID sceneId);

    /** (version id, owning scene id) pairs — PUBLISH-level pin checks. */
    @Query("select v.id, v.sceneId from AnimationSceneVersion v")
    List<Object[]> findIdAndSceneId();

    /** Scene ids having at least one published version. */
    @Query("select distinct v.sceneId from AnimationSceneVersion v")
    List<UUID> findDistinctSceneIds();
}
