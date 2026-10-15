package com.dauviet.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.dauviet.security.jwt.JwtTokenService;

/**
 * Role gating: anonymous 401, LEARNER 403, CONTENT_ADMIN 200.
 * Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AdminPingIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwtTokenService;

    @BeforeEach
    void clean() {
        users.deleteAll();
    }

    private String bearer(User u) {
        return "Bearer " + jwtTokenService.createAccessToken(u);
    }

    private User user(String email, UserRole role) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail(email);
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(role);
        u.setStatus(UserStatus.ACTIVE);
        return users.save(u);
    }

    @Test
    void anonymous_401() throws Exception {
        mvc.perform(get("/api/v1/admin/ping"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void learner_403_admin_200() throws Exception {
        User learner = user("l@test.vn", UserRole.LEARNER);
        mvc.perform(get("/api/v1/admin/ping")
                        .header("Authorization", bearer(learner)))
                .andExpect(status().isForbidden());

        User admin = user("a@test.vn", UserRole.CONTENT_ADMIN);
        mvc.perform(get("/api/v1/admin/ping")
                        .header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ok"));
    }
}
