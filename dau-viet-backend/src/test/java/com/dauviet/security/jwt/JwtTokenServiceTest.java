package com.dauviet.security.jwt;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.nimbusds.jose.jwk.source.ImmutableSecret;

/** Pure unit test — no Spring context, no DB. */
class JwtTokenServiceTest {

    private static final String SECRET =
            "test-secret-key-32-bytes-minimum-0123456789abcdef";

    private JwtTokenService service;
    private JwtDecoder decoder;
    private SecurityTokenProperties props;

    @BeforeEach
    void setUp() {
        SecretKey key = new SecretKeySpec(SECRET.getBytes(), "HmacSHA256");
        JwtEncoder encoder = new NimbusJwtEncoder(new ImmutableSecret<>(key));
        decoder = NimbusJwtDecoder.withSecretKey(key).build();
        props = new SecurityTokenProperties();
        props.setJwtSecret(SECRET);
        service = new JwtTokenService(encoder, props);
    }

    private User user(UserRole role) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail("a@b.vn");
        u.setRole(role);
        return u;
    }

    @Test
    void accessToken_carriesSubRoleAndExpiry() {
        User u = user(UserRole.CONTENT_ADMIN);
        String token = service.createAccessToken(u);
        Jwt decoded = decoder.decode(token);
        assertThat(decoded.getSubject()).isEqualTo(u.getId().toString());
        assertThat(decoded.getClaimAsString("role")).isEqualTo("CONTENT_ADMIN");
        assertThat(decoded.getClaimAsString("iss")).isEqualTo(JwtTokenService.ISSUER);
        long ttl = decoded.getExpiresAt().getEpochSecond()
                 - decoded.getIssuedAt().getEpochSecond();
        assertThat(ttl).isEqualTo(props.getAccessTokenTtlSeconds());
    }

    @Test
    void accessToken_expiresAfterConfiguredTtl() {
        props.setAccessTokenTtlSeconds(60);
        User u = user(UserRole.LEARNER);
        Jwt decoded = decoder.decode(service.createAccessToken(u));
        assertThat(decoded.getExpiresAt())
                .isAfter(Instant.now().plusSeconds(50))
                .isBefore(Instant.now().plusSeconds(70));
    }

    @Test
    void tamperedToken_failsVerification() {
        User u = user(UserRole.LEARNER);
        String token = service.createAccessToken(u);
        String tampered = token.substring(0, token.length() - 4) + "AAAA";
        org.junit.jupiter.api.Assertions.assertThrows(
                org.springframework.security.oauth2.jwt.JwtException.class,
                () -> decoder.decode(tampered));
    }
}
