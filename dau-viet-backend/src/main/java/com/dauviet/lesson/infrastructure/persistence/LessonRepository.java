package com.dauviet.lesson.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;

@Repository
public interface LessonRepository
        extends JpaRepository<Lesson, UUID>, JpaSpecificationExecutor<Lesson> {

    /** True when any lesson on the event is not yet archived. */
    boolean existsByEventIdAndStatusNot(UUID eventId, LessonStatus status);

    List<Lesson> findByEventIdAndStatusOrderByTitle(UUID eventId, LessonStatus status);

    /**
     * Pessimistic write lock on the lesson row — serializes concurrent
     * publishes so version_no allocation cannot race.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select l from Lesson l where l.id = :id")
    Optional<Lesson> findForUpdate(@Param("id") UUID id);
}
