package com.dauviet.lesson.infrastructure.persistence;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;

@Repository
public interface LessonRepository
        extends JpaRepository<Lesson, UUID>, JpaSpecificationExecutor<Lesson> {

    /** True when any lesson on the event is not yet archived. */
    boolean existsByEventIdAndStatusNot(UUID eventId, LessonStatus status);
}
