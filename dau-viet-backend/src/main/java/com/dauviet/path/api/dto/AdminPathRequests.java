package com.dauviet.path.api.dto;

import java.util.List;
import java.util.UUID;
import com.dauviet.path.domain.ParticipationType;
import com.dauviet.common.heritage.HeritageBackgroundConfigDto;
import jakarta.validation.constraints.*;

public final class AdminPathRequests {
    private AdminPathRequests() {}

    public record Draft(@NotBlank @Size(max = 64) String pathCode,
                        @NotBlank @Size(max = 255) String title, String description) {}
    public record Revision(@NotNull @PositiveOrZero Long expectedRevision) {}
    public record Chapter(@NotNull @PositiveOrZero Long expectedRevision,
                          @NotBlank @Size(max = 64) String code,
                          @NotBlank @Size(max = 255) String title, String description,
                          @NotNull Integer startYear, @NotNull Integer endYear,
                          @NotBlank @Size(max = 120) String periodLabel,
                          @NotBlank @Size(max = 64) String themeKey,
                          @Size(max = 255) String coverImageKey,
                          UUID parentId,
                          String nodeType,
                          HeritageBackgroundConfigDto backgroundConfig) {
        public Chapter(Long expectedRevision, String code, String title, String description,
                       Integer startYear, Integer endYear, String periodLabel, String themeKey) {
            this(expectedRevision, code, title, description, startYear, endYear, periodLabel, themeKey, null, null, null, null);
        }
        public Chapter(Long expectedRevision, String code, String title, String description,
                       Integer startYear, Integer endYear, String periodLabel, String themeKey,
                       String coverImageKey, UUID parentId, String nodeType) {
            this(expectedRevision, code, title, description, startYear, endYear, periodLabel, themeKey, coverImageKey, parentId, nodeType, null);
        }
    }
    public record ChapterPatch(@NotNull @PositiveOrZero Long expectedRevision,
                               @Size(max = 64) String code, @Size(max = 255) String title,
                               String description, Integer startYear, Integer endYear,
                               @Size(max = 120) String periodLabel, @Size(max = 64) String themeKey,
                               @Size(max = 255) String coverImageKey,
                               UUID parentId, Boolean clearParent, String nodeType,
                               Boolean clearCoverImage,
                               HeritageBackgroundConfigDto backgroundConfig,
                               Boolean clearBackgroundConfig) {
        public ChapterPatch(Long expectedRevision, String code, String title,
                            String description, Integer startYear, Integer endYear,
                            String periodLabel, String themeKey) {
            this(expectedRevision, code, title, description, startYear, endYear, periodLabel, themeKey,
                    null, null, null, null, null, null, null);
        }
        public ChapterPatch(Long expectedRevision, String code, String title,
                            String description, Integer startYear, Integer endYear,
                            String periodLabel, String themeKey,
                            String coverImageKey, UUID parentId, Boolean clearParent, String nodeType) {
            this(expectedRevision, code, title, description, startYear, endYear, periodLabel, themeKey,
                    coverImageKey, parentId, clearParent, nodeType, null, null, null);
        }
    }
    public record Event(@NotNull @PositiveOrZero Long expectedRevision, @NotNull UUID eventId,
                        @NotNull ParticipationType participationType) {}
    public record EventPatch(@NotNull @PositiveOrZero Long expectedRevision, UUID chapterId,
                             ParticipationType participationType) {}
    public record Lesson(@NotNull @PositiveOrZero Long expectedRevision, @NotNull UUID lessonId) {}
    public record ChaptersOrder(@NotNull @PositiveOrZero Long expectedRevision,
                                @NotNull List<@NotNull UUID> chapterIds,
                                UUID parentId) {
        public ChaptersOrder(Long expectedRevision, List<UUID> chapterIds) {
            this(expectedRevision, chapterIds, null);
        }
    }
    public record EventsOrder(@NotNull @PositiveOrZero Long expectedRevision,
                              @NotNull List<@NotNull UUID> eventNodeIds) {}
    public record LessonsOrder(@NotNull @PositiveOrZero Long expectedRevision,
                               @NotNull List<@NotNull UUID> lessonNodeIds) {}
}
