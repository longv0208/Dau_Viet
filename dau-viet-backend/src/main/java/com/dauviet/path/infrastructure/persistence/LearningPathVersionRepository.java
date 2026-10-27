package com.dauviet.path.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

import com.dauviet.path.domain.LearningPathStatus;
import com.dauviet.path.domain.LearningPathVersion;

@Repository
public interface LearningPathVersionRepository extends JpaRepository<LearningPathVersion, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select v from LearningPathVersion v where v.id = :id")
    Optional<LearningPathVersion> findLockedById(@Param("id") UUID id);

    Optional<LearningPathVersion> findByPathCodeAndStatus(String pathCode, LearningPathStatus status);

    Optional<LearningPathVersion> findByPathCodeAndVersionNo(String pathCode, int versionNo);

    List<LearningPathVersion> findByPathCodeOrderByVersionNoDesc(String pathCode);
}
