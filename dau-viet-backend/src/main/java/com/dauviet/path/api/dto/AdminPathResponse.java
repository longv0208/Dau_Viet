package com.dauviet.path.api.dto;

import java.util.List;
import java.util.UUID;
import com.dauviet.path.domain.*;
import com.dauviet.common.heritage.HeritageBackgroundConfigDto;

public record AdminPathResponse(LearningPathVersion version, List<Chapter> chapters) {
    public record Chapter(LearningPathChapter chapter, List<Event> events) {}
    public record Event(LearningPathEventNode node, String title, Integer startYear,
                        PathContentStatus contentStatus, UUID publishedPolicyId,
                        Integer publishedPolicyVersion, List<UUID> requiredLessonIds,
                        List<UUID> optionalLessonIds, List<Lesson> lessons,
                        String eventStatus, UUID canonicalEventId, boolean alias,
                        String coverAssetKey, HeritageBackgroundConfigDto backgroundConfig) {
        public Event(LearningPathEventNode node, String title, Integer startYear,
                     PathContentStatus contentStatus, UUID publishedPolicyId,
                     Integer publishedPolicyVersion, List<UUID> requiredLessonIds,
                     List<UUID> optionalLessonIds, List<Lesson> lessons,
                     String eventStatus, UUID canonicalEventId, boolean alias) {
            this(node, title, startYear, contentStatus, publishedPolicyId,
                    publishedPolicyVersion, requiredLessonIds, optionalLessonIds,
                    lessons, eventStatus, canonicalEventId, alias, null,
                    HeritageBackgroundConfigDto.defaultConfig());
        }
    }
    public record Lesson(LearningPathLessonNode node, String title, String status,
                         UUID coverAssetId, HeritageBackgroundConfigDto backgroundConfig) {
        public Lesson(LearningPathLessonNode node, String title, String status) {
            this(node, title, status, null, HeritageBackgroundConfigDto.defaultConfig());
        }
        public Lesson(LearningPathLessonNode node, String title, String status, UUID coverAssetId) {
            this(node, title, status, coverAssetId, HeritageBackgroundConfigDto.defaultConfig());
        }
    }
}
