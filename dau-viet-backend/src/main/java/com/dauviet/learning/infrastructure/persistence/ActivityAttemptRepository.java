package com.dauviet.learning.infrastructure.persistence;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.dauviet.learning.domain.ActivityAttempt;

@Repository
public interface ActivityAttemptRepository extends JpaRepository<ActivityAttempt, UUID> {

    int countByLearnerAttemptIdAndActivityId(UUID learnerAttemptId, String activityId);
}
