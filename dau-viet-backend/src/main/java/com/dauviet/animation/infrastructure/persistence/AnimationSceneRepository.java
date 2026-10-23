package com.dauviet.animation.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.animation.domain.AnimationScene;

@Repository
public interface AnimationSceneRepository
        extends JpaRepository<AnimationScene, UUID>,
        JpaSpecificationExecutor<AnimationScene> {

    /**
     * Pessimistic write lock on the scene row — serializes concurrent
     * publishes so version_no allocation cannot race (same pattern as
     * LessonRepository.findForUpdate).
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from AnimationScene s where s.id = :id")
    Optional<AnimationScene> findForUpdate(@Param("id") UUID id);
}
