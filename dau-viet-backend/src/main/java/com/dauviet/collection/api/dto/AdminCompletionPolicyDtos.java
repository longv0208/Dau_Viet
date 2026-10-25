package com.dauviet.collection.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * DTOs cho admin completion-policy endpoints (GAME-06 Module A).
 * Response mang lessonIds dạng UUID string (không resolve title — UI join
 * qua /admin/lessons?eventId=... để tránh N+1).
 */
public final class AdminCompletionPolicyDtos {

    private AdminCompletionPolicyDtos() {
    }

    /** Một dòng policy version trong list/detail admin. */
    public record AdminCompletionPolicyResponse(
            UUID id,
            UUID eventId,
            Integer policyVersion,
            String status,
            List<UUID> requiredLessonIds,
            List<UUID> optionalLessonIds,
            Integer masteryThreshold,
            Instant publishedAt,
            Instant createdAt) {
    }

    /** Body tạo/sửa DRAFT. requiredLessonIds bắt buộc >=1 khi publish —
     * create cho phép rỗng tạm thời (admin soạn dở), validate chặn lúc
     * publish. */
    public record AdminCompletionPolicyUpsertRequest(
            List<UUID> requiredLessonIds,
            List<UUID> optionalLessonIds,
            @Min(0) @Max(100) Integer masteryThreshold,
            /** Optimistic guard: version admin đang thấy khi sửa — null = bỏ qua. */
            Integer expectedPolicyVersion) {
    }

    /** Body publish — optimistic guard chống overwrite bằng dữ liệu cũ. */
    public record AdminPolicyPublishRequest(
            Integer expectedPolicyVersion) {
    }

    /** Một lỗi/cảnh báo validation — code ổn định cho UI map tiếng Việt. */
    public record PolicyIssue(String code, String message, String field) {
    }

    /** Kết quả dry-run validate — không ghi DB. */
    public record AdminPolicyValidationResponse(
            boolean valid,
            List<PolicyIssue> errors,
            List<String> warnings,
            /** So sánh với PUBLISHED hiện tại (null khi chưa có). */
            PolicyDiff diff) {
    }

    /** Diff from→to giữa PUBLISHED hiện tại và DRAFT đang soạn. */
    public record PolicyDiff(
            Snapshot from,
            Snapshot to) {
        public record Snapshot(
                Integer policyVersion,
                Integer requiredCount,
                Integer optionalCount,
                Integer masteryThreshold,
                List<UUID> requiredAdded,
                List<UUID> requiredRemoved) {
        }
    }
}
