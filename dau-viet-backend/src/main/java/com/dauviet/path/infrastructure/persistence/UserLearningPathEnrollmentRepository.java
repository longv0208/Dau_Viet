package com.dauviet.path.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import com.dauviet.path.domain.UserLearningPathEnrollment;

public interface UserLearningPathEnrollmentRepository extends JpaRepository<UserLearningPathEnrollment, UserLearningPathEnrollment.Key> {
    Optional<UserLearningPathEnrollment> findByIdUserIdAndIdPathCode(UUID userId, String pathCode);
}
