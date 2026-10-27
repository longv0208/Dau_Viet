package com.dauviet.path.api.dto;

import java.util.List;
import java.util.UUID;
import com.dauviet.path.domain.ParticipationType;
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
                          @NotBlank @Size(max = 64) String themeKey) {}
    public record ChapterPatch(@NotNull @PositiveOrZero Long expectedRevision,
                               @Size(max = 64) String code, @Size(max = 255) String title,
                               String description, Integer startYear, Integer endYear,
                               @Size(max = 120) String periodLabel, @Size(max = 64) String themeKey) {}
    public record Event(@NotNull @PositiveOrZero Long expectedRevision, @NotNull UUID eventId,
                        @NotNull ParticipationType participationType) {}
    public record EventPatch(@NotNull @PositiveOrZero Long expectedRevision, UUID chapterId,
                             ParticipationType participationType) {}
    public record Lesson(@NotNull @PositiveOrZero Long expectedRevision, @NotNull UUID lessonId) {}
    public record ChaptersOrder(@NotNull @PositiveOrZero Long expectedRevision,
                                @NotNull List<@NotNull UUID> chapterIds) {}
    public record EventsOrder(@NotNull @PositiveOrZero Long expectedRevision,
                              @NotNull List<@NotNull UUID> eventNodeIds) {}
    public record LessonsOrder(@NotNull @PositiveOrZero Long expectedRevision,
                               @NotNull List<@NotNull UUID> lessonNodeIds) {}
}
