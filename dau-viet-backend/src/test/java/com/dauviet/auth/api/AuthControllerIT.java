package com.dauviet.auth.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * End-to-end auth flows on a real Postgres container. Requires Docker —
 * NOT VERIFIED locally when Docker Desktop is down.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired ObjectMapper om;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

    @BeforeEach
    void clean() {
        clearAuthoringTables(jdbc);
        users.deleteAll();
    }

    private MvcResult register(String email, String pw) throws Exception {
        return mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"%s","displayName":"N"}
                                """.formatted(email, pw)))
                .andReturn();
    }

    private String registerAndLogin(String email, String pw) throws Exception {
        register(email, pw);
        MvcResult res = mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"%s"}
                                """.formatted(email, pw)))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        return body.get("refreshToken").asText();
    }

    @Test
    void register_created_returns201Profile_noHash() throws Exception {
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"learner@test.vn","password":"password123","displayName":"L"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.email").value("learner@test.vn"))
                .andExpect(jsonPath("$.role").value("LEARNER"))
                .andExpect(jsonPath("$.passwordHash").doesNotExist());
        assertThat(users.findByEmailIgnoreCase("LEARNER@test.vn")).isPresent();
    }

    @Test
    void register_duplicateEmail_409() throws Exception {
        register("dup@test.vn", "password123");
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"DUP@test.vn","password":"password123"}
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_TAKEN"));
    }

    @Test
    void register_invalid_400() throws Exception {
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"not-an-email","password":"pw","displayName":""}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void register_roleSupplied_400() throws Exception {
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"r@test.vn","password":"password123","role":"CONTENT_ADMIN"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void login_valid_200Tokens() throws Exception {
        register("login@test.vn", "password123");
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"login@test.vn","password":"password123"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.tokenType").value("Bearer"));
    }

    @Test
    void login_wrongPassword_401() throws Exception {
        register("wp@test.vn", "password123");
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"wp@test.vn","password":"wrong-password"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void login_unknownEmail_401_sameEnvelope() throws Exception {
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"ghost@test.vn","password":"password123"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void login_lockedUser_401() throws Exception {
        register("locked@test.vn", "password123");
        User u = users.findByEmailIgnoreCase("locked@test.vn").orElseThrow();
        u.setStatus(UserStatus.LOCKED);
        users.save(u);
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"locked@test.vn","password":"password123"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }
}
