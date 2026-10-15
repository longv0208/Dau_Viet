package com.dauviet.user.domain;

/**
 * Account lifecycle states, matching V2 chk_users_status.
 * LOCKED = temporary security lock; DISABLED = administratively off.
 */
public enum UserStatus {
    ACTIVE,
    LOCKED,
    DISABLED
}
