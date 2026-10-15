package com.dauviet.lesson.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.dauviet.lesson.domain.LessonVersion;

/**
 * Read + insert only. The DB trigger trg_lesson_versions_immutable forbids
 * UPDATE/DELETE — publish a new version instead.
 */
@Repository
public interface LessonVersionRepository extends JpaRepository<LessonVersion, UUID> {

    Optional<LessonVersion> findTopByLessonIdOrderByVersionNoDesc(UUID lessonId);
}
