package com.dauviet.learning.api.dto;

import java.util.List;

/**
 * Response of GET /me/progress — the mobile resume surface: the learner's
 * IN_PROGRESS attempts (bounded, newest first) plus a completed count.
 */
public record MyProgressResponse(
        List<AttemptSummaryResponse> inProgress,
        long completedCount) {
}
