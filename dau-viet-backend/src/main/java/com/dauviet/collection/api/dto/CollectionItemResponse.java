package com.dauviet.collection.api.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Một mục trong Bộ sưu tập của learner (TASK-0022). `evidence` giữ nguyên
 * bản embedded từ pinned snapshot tại thời điểm collect — không bị thay
 * đổi khi admin sửa/lưu trữ evidence gốc.
 */
public record CollectionItemResponse(
        UUID evidenceId,
        String evidenceType,
        Instant collectedAt,
        UUID eventId,
        String eventTitle,
        UUID lessonId,
        String lessonTitle,
        EvidenceSnapshot evidence
) {
    /** Nội dung evidence như đã nhúng trong snapshot khi collect. */
    public record EvidenceSnapshot(
            String title,
            String description,
            String assetId,
            SourceDto source
    ) {
    }

    public record SourceDto(
            String title,
            String author,
            String url,
            String citation,
            String publishedAt
    ) {
    }
}
