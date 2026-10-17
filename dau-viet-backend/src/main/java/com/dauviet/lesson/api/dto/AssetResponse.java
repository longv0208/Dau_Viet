package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.util.UUID;

/** Admin-facing asset metadata. `contentUrl` is the stable serving path, not a storage path. */
public record AssetResponse(
        UUID id,
        String originalFilename,
        String mimeType,
        Long sizeBytes,
        String state,
        String altText,
        Instant createdAt,
        String contentUrl) {
}
