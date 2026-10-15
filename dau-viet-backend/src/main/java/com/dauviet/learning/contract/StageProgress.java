package com.dauviet.learning.contract;

import java.util.List;

/** Required-activity completion inside one stage; optional activities do not gate. */
public record StageProgress(
        String stageId,
        List<String> requiredActivityIds,
        List<String> completedRequiredActivityIds,
        boolean complete) {
}
