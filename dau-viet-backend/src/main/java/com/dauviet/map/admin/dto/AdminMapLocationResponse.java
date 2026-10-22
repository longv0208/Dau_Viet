package com.dauviet.map.admin.dto;

import java.time.Instant;
import java.util.UUID;

public record AdminMapLocationResponse(
        UUID id,
        UUID eventId,
        String title,
        String description,
        double latitude,
        double longitude,
        UUID unlockLessonId,
        String unlockLessonTitle,
        int displayOrder,
        String status,
        boolean everPublished,
        long rowVersion,
        Instant createdAt,
        Instant updatedAt
) {
}
