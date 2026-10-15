package com.dauviet.user.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.dauviet.security.jwt.JwtTokenService;

/** /users/me: valid JWT -> profile; invalid/missing -> 401. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class UserControllerIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwtTokenService;
    @Autowired JdbcTemplate jdbc;

    @BeforeEach
    void clean() {
        // Lessons/evidences carry created_by FKs to users; clear dependents first.
        clearAuthoringTables(jdbc);
        users.deleteAll();
    }

    private User user(String email) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail(email);
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(UserRole.LEARNER);
        u.setStatus(UserStatus.ACTIVE);
        return users.save(u);
    }

    @Test
    void me_validJwt_200_profileWithoutSecrets() throws Exception {
        User u = user("me@test.vn");
        mvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + jwtTokenService.createAccessToken(u)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(u.getId().toString()))
                .andExpect(jsonPath("$.email").value("me@test.vn"))
                .andExpect(jsonPath("$.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.password").doesNotExist());
    }

    @Test
    void me_noToken_401() throws Exception {
        mvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void me_malformedToken_401() throws Exception {
        mvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer not-a-jwt"))
                .andExpect(status().isUnauthorized());
    }
}
