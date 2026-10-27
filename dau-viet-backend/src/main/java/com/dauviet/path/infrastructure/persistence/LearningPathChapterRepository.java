package com.dauviet.path.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.dauviet.path.domain.LearningPathChapter;

@Repository
public interface LearningPathChapterRepository extends JpaRepository<LearningPathChapter, UUID> {

    List<LearningPathChapter> findByPathVersionIdOrderBySortOrderAsc(UUID pathVersionId);

    Optional<LearningPathChapter> findByPathVersionIdAndCode(UUID pathVersionId, String code);
}
