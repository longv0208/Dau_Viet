package com.dauviet.learning.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.dauviet.learning.domain.LessonResult;

@Repository
public interface LessonResultRepository extends JpaRepository<LessonResult, UUID> {

    Optional<LessonResult> findByLearnerAttemptId(UUID learnerAttemptId);
}
