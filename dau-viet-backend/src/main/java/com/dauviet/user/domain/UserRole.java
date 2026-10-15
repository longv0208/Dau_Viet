package com.dauviet.user.domain;

/**
 * Account roles, matching the CHECK constraint in V2 (chk_users_role).
 * Never rename without a schema migration.
 */
public enum UserRole {
    LEARNER,
    CONTENT_ADMIN
}
