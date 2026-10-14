package com.dauviet.common.api;

import java.util.Map;

/**
 * Unified API error envelope per docs/CODING_RULES.md.
 * Never include stack traces; details is for structured context only.
 */
public record ApiError(
        String code,
        String message,
        Map<String, Object> details,
        String traceId
) {
    public static ApiError of(String code, String message) {
        return new ApiError(code, message, Map.of(), null);
    }

    public static ApiError of(String code, String message, Map<String, Object> details, String traceId) {
        return new ApiError(code, message, details == null ? Map.of() : details, traceId);
    }
}
