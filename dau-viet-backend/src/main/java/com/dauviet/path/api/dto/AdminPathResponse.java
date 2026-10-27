package com.dauviet.path.api.dto;

import java.util.List;
import java.util.UUID;
import com.dauviet.path.domain.*;

public record AdminPathResponse(LearningPathVersion version, List<Chapter> chapters) {
    public record Chapter(LearningPathChapter chapter, List<Event> events) {}
    public record Event(LearningPathEventNode node, String title, Integer startYear,
                        PathContentStatus contentStatus, UUID publishedPolicyId,
                        Integer publishedPolicyVersion, List<UUID> requiredLessonIds,
                        List<UUID> optionalLessonIds, List<Lesson> lessons,
                        String eventStatus, UUID canonicalEventId, boolean alias) {}
    public record Lesson(LearningPathLessonNode node, String title, String status, UUID coverAssetId) {
        public Lesson(LearningPathLessonNode node, String title, String status) {
            this(node, title, status, null);
        }
    }
}
