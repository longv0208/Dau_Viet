package com.dauviet.user.api.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Learner-safe account profile. The record type has no passwordHash or
 * token fields at all — leaking credentials is impossible by construction.
 */
public record UserProfileDto(
        UUID id,
        String email,
        String displayName,
        String role,
        String status,
        Instant emailVerifiedAt,
        Instant createdAt
) {}
