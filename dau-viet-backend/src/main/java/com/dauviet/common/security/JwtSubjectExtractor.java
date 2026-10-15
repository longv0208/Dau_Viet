package com.dauviet.common.security;

import java.util.UUID;

import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import com.dauviet.auth.domain.AuthenticationFailedException;

/**
 * Shared JWT subject -> user UUID extraction. A token that passed
 * signature/expiry checks but carries a malformed subject is still an
 * authentication failure — controlled 401, never a 500.
 */
@Component
public class JwtSubjectExtractor {

    public UUID userId(Jwt jwt) {
        try {
            return UUID.fromString(jwt.getSubject());
        } catch (RuntimeException ex) {
            throw new AuthenticationFailedException();
        }
    }
}
