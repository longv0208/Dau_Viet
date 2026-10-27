package com.dauviet.path.api.dto;

import java.util.List;
import java.util.Map;
import java.util.UUID;

public record PathAuditReport(
        String pathCode,
        int pathVersion,
        String status,
        int totalChapters,
        int totalEvents,
        int totalLessons,
        Map<String, Long> contentStatusCounts,
        List<AuditIssue> issues,
        List<DuplicateAliasReport> duplicateAliases,
        List<String> emptyChapters
) {
    public record AuditIssue(
            String level, // ERROR, WARNING, INFO
            String code,
            String message,
            UUID targetId
    ) {}

    public record DuplicateAliasReport(
            String canonicalSlug,
            UUID canonicalEventId,
            String aliasSlug,
            UUID aliasEventId,
            String note
    ) {}
}
