package com.dauviet.path.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.dauviet.path.domain.LearningPathStatus;
import com.dauviet.path.domain.LearningPathVersion;

@Repository
public interface LearningPathVersionRepository extends JpaRepository<LearningPathVersion, UUID> {

    Optional<LearningPathVersion> findByPathCodeAndStatus(String pathCode, LearningPathStatus status);

    Optional<LearningPathVersion> findByPathCodeAndVersionNo(String pathCode, int versionNo);

    List<LearningPathVersion> findByPathCodeOrderByVersionNoDesc(String pathCode);
}
