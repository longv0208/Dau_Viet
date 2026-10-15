package com.dauviet.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.auth.application.RefreshTokenService;
import com.dauviet.auth.domain.RefreshToken;
import com.dauviet.auth.infrastructure.persistence.RefreshTokenRepository;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Refresh rotation / replay / expiry / logout flows on real Postgres.
 * Requires Docker — NOT VERIFIED locally when Docker Desktop is down.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AuthRefreshIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired RefreshTokenRepository tokens;
    @Autowired RefreshTokenService refreshTokenService;
    @Autowired ObjectMapper om;

    @BeforeEach
    void clean() {
        tokens.deleteAll();
        users.deleteAll();
    }

    private User activeUser(String email) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail(email);
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(UserRole.LEARNER);
        u.setStatus(UserStatus.ACTIVE);
        return users.save(u);
    }

    private String rawTokenFor(User u) throws Exception {
        // Simulate login: issue a real stored token and return the raw value.
        var issued = refreshTokenService.issue(u, null);
        return issued.raw();
    }

    private String rotateRaw(String raw) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(raw)))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        return body.get("refreshToken").asText();
    }

    @Test
    void rotate_returnsNewPair_oldRevoked() throws Exception {
        User u = activeUser("rot@test.vn");
        String raw = rawTokenFor(u);
        String newRaw = rotateRaw(raw);
        assertThat(newRaw).isNotEqualTo(raw);
        RefreshToken old = tokens.findByTokenHash(RefreshTokenService.hash(raw)).orElseThrow();
        assertThat(old.isRevoked()).isTrue();
        assertThat(old.getLastUsedAt()).isNotNull();
        RefreshToken next = tokens.findByTokenHash(RefreshTokenService.hash(newRaw)).orElseThrow();
        assertThat(next.getPreviousTokenId()).isEqualTo(old.getId());
        assertThat(next.getTokenFamilyId()).isEqualTo(old.getTokenFamilyId());
    }

    @Test
    void replay_oldToken_401_familyRevoked() throws Exception {
        User u = activeUser("replay@test.vn");
        String raw = rawTokenFor(u);
        String newRaw = rotateRaw(raw); // rotates, raw now revoked
        // Attacker replays the rotated-away token:
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(raw)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
        // And the *new* token is now dead too (family revoked):
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(newRaw)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void expiredRefresh_401() throws Exception {
        User u = activeUser("exp@test.vn");
        var issued = refreshTokenService.issue(u, null);
        RefreshToken t = tokens.findByTokenHash(RefreshTokenService.hash(issued.raw())).orElseThrow();
        t.setExpiresAt(Instant.now().minusSeconds(60));
        tokens.save(t);
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(issued.raw())))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logout_204_thenRefresh401_retryStill204() throws Exception {
        User u = activeUser("out@test.vn");
        String raw = rawTokenFor(u);
        mvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(raw)))
                .andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(raw)))
                .andExpect(status().isUnauthorized());
        // Retry logout — idempotent.
        mvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(raw)))
                .andExpect(status().isNoContent());
    }
}
