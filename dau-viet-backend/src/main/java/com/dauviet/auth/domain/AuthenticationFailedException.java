package com.dauviet.auth.domain;

/**
 * Authentication/refresh-token failure. Always maps to 401
 * INVALID_CREDENTIALS so callers cannot distinguish "no such user",
 * "wrong password", "locked account", or "bad token" from the response.
 */
public class AuthenticationFailedException extends RuntimeException {

    public AuthenticationFailedException() {
        super("Invalid credentials");
    }
}
