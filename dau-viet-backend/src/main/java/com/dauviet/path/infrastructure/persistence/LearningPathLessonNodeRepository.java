package com.dauviet.path.infrastructure.persistence;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.path.domain.LearningPathLessonNode;

@Repository
public interface LearningPathLessonNodeRepository extends JpaRepository<LearningPathLessonNode, UUID> {

    List<LearningPathLessonNode> findByEventNodeIdOrderBySortOrderAsc(UUID eventNodeId);

    @Query("SELECT l FROM LearningPathLessonNode l WHERE l.eventNodeId IN :eventNodeIds ORDER BY l.sortOrder ASC")
    List<LearningPathLessonNode> findByEventNodeIdInOrderBySortOrderAsc(@Param("eventNodeIds") Collection<UUID> eventNodeIds);

    Optional<LearningPathLessonNode> findByEventNodeIdAndLessonId(UUID eventNodeId, UUID lessonId);
}
