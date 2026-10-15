package com.dauviet.common.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;

import com.dauviet.auth.domain.AuthenticationFailedException;

/**
 * Malformed JWT subject handling: a signed token whose `sub` is not a UUID
 * must surface as AuthenticationFailedException (-> 401), never a 500.
 */
class JwtSubjectExtractorTest {

    private final JwtSubjectExtractor extractor = new JwtSubjectExtractor();

    private Jwt jwtWithSubject(String sub) {
        return Jwt.withTokenValue("t")
                .header("alg", "none")
                .subject(sub)
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(60))
                .build();
    }

    @Test
    void validUuidSubject_returnsId() {
        UUID id = UUID.randomUUID();
        assertThat(extractor.userId(jwtWithSubject(id.toString()))).isEqualTo(id);
    }

    @Test
    void nonUuidSubject_throwsAuthenticationFailed() {
        assertThatThrownBy(() -> extractor.userId(jwtWithSubject("not-a-uuid")))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void nullSubject_throwsAuthenticationFailed() {
        assertThatThrownBy(() -> extractor.userId(jwtWithSubject(null)))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void emptySubject_throwsAuthenticationFailed() {
        assertThatThrownBy(() -> extractor.userId(jwtWithSubject("")))
                .isInstanceOf(AuthenticationFailedException.class);
    }
}
