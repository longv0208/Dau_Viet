package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * A correctly-signed token whose `sub` is not a UUID reaches the service but
 * must fail as a controlled 401 authentication failure — never a 500 and
 * never an ownership bypass. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class MalformedSubjectIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired JwtEncoder encoder;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String learnerToken;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();
        learnerToken = AttemptItFixture.token(users, jwt, "l@m.vn", UserRole.LEARNER);
    }

    /** Mint a real signed token with an arbitrary (non-UUID) subject. */
    private String tokenWithSubject(String sub) {
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(JwtTokenService.ISSUER)
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(600))
                .subject(sub)
                .claim("role", "LEARNER")
                .build();
        return "Bearer " + encoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    @Test
    void nonUuidSubject_is401_not500_onEveryEndpoint() throws Exception {
        String bad = tokenWithSubject("definitely-not-a-uuid");

        MvcResult r1 = mvc.perform(get("/api/v1/me/attempts")
                        .header("Authorization", bad))
                .andReturn();
        assertThat(r1.getResponse().getStatus()).isEqualTo(401);
        assertThat(r1.getResponse().getContentAsString())
                .doesNotContain("Internal Server Error");

        MvcResult r2 = mvc.perform(get("/api/v1/me/progress")
                        .header("Authorization", bad))
                .andReturn();
        assertThat(r2.getResponse().getStatus()).isEqualTo(401);

        MvcResult r3 = mvc.perform(post("/api/v1/lessons/"
                        + UUID.randomUUID() + "/attempts")
                        .header("Authorization", bad))
                .andReturn();
        assertThat(r3.getResponse().getStatus()).isEqualTo(401);

        MvcResult r4 = mvc.perform(get("/api/v1/attempts/"
                        + UUID.randomUUID() + "/result")
                        .header("Authorization", bad))
                .andReturn();
        assertThat(r4.getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void validToken_stillWorksAfterMalformedOne() throws Exception {
        mvc.perform(get("/api/v1/me/attempts")
                        .header("Authorization", tokenWithSubject("bad-sub")))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/me/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
    }
}
