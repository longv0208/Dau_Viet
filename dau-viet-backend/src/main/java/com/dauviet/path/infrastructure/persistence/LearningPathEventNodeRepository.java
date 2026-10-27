package com.dauviet.path.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.dauviet.path.domain.LearningPathEventNode;

@Repository
public interface LearningPathEventNodeRepository extends JpaRepository<LearningPathEventNode, UUID> {

    List<LearningPathEventNode> findByPathVersionIdOrderBySortOrderAsc(UUID pathVersionId);

    List<LearningPathEventNode> findByChapterIdOrderBySortOrderAsc(UUID chapterId);

    Optional<LearningPathEventNode> findByPathVersionIdAndEventId(UUID pathVersionId, UUID eventId);
}
