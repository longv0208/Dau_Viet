package com.dauviet.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.test.web.servlet.MockMvc;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;

/** Expired access token must be rejected -> 401. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class JwtExpiredIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtEncoder encoder;

    @BeforeEach
    void clean() {
        users.deleteAll();
    }

    @Test
    void expiredAccessToken_401() throws Exception {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail("exp@test.vn");
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(UserRole.LEARNER);
        u.setStatus(UserStatus.ACTIVE);
        users.save(u);

        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("dau-viet-backend")
                .issuedAt(now.minusSeconds(120))
                .expiresAt(now.minusSeconds(60)) // already expired
                .subject(u.getId().toString())
                .claim("role", "LEARNER")
                .build();
        String expired = encoder.encode(JwtEncoderParameters
                .from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();

        mvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized());
    }
}
