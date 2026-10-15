package com.dauviet.lesson.domain;

import java.util.List;
import java.util.UUID;

/** Raised when archiving evidence still referenced by a published lesson snapshot. */
public class EvidenceInUseException extends RuntimeException {
    private final List<UUID> lessonIds;

    public EvidenceInUseException(String message) {
        this(message, List.of());
    }

    public EvidenceInUseException(String message, List<UUID> lessonIds) {
        super(message);
        this.lessonIds = lessonIds == null ? List.of() : List.copyOf(lessonIds);
    }

    public List<UUID> getLessonIds() { return lessonIds; }
}
