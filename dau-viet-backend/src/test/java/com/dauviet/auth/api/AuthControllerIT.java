package com.dauviet.auth.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.auth.application.OtpSender;
import com.dauviet.auth.domain.OtpPurpose;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * End-to-end auth flows on a real Postgres container (Issue #34 contract:
 * register is now a 2-step OTP challenge). Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired ObjectMapper om;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

    /** Capture outbound OTPs so tests can drive the real verify path. */
    @MockitoBean
    OtpSender otpSender;

    @BeforeEach
    void clean() {
        clearAuthoringTables(jdbc);
        users.deleteAll();
    }

    /** Register → capture the OTP sent → verify → returns tokens. */
    private String registerVerifyAndGetRefreshToken(String email, String pw) throws Exception {
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"%s","displayName":"N"}
                                """.formatted(email, pw)))
                .andExpect(status().isAccepted());

        org.mockito.ArgumentCaptor<String> code = org.mockito.ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(otpSender).sendOtp(
                org.mockito.ArgumentMatchers.eq(email), org.mockito.ArgumentMatchers.eq(OtpPurpose.REGISTER_VERIFY),
                code.capture());

        MvcResult res = mvc.perform(post("/api/v1/auth/register/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","otpCode":"%s"}
                                """.formatted(email, code.getValue())))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        return body.get("refreshToken").asText();
    }

    @Test
    void register_returns202Challenge_notAProfile() throws Exception {
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"learner@test.vn","password":"password123","displayName":"L"}
                                """))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.email").value("learner@test.vn"))
                .andExpect(jsonPath("$.otpPurpose").value("REGISTER_VERIFY"))
                .andExpect(jsonPath("$.otpTtlSeconds").value(300))
                .andExpect(jsonPath("$.resendCooldownSeconds").value(60))
                .andExpect(jsonPath("$.accessToken").doesNotExist());
        // User NOT created until OTP verify.
        assertThat(users.findByEmailIgnoreCase("learner@test.vn")).isEmpty();
    }

    @Test
    void registerVerify_fullFlow_createsVerifiedUser_andTokens() throws Exception {
        String refresh = registerVerifyAndGetRefreshToken("flow@test.vn", "password123");
        assertThat(refresh).isNotBlank();
        User u = users.findByEmailIgnoreCase("flow@test.vn").orElseThrow();
        assertThat(u.getEmailVerifiedAt()).isNotNull();
        assertThat(u.getStatus()).isEqualTo(UserStatus.ACTIVE);
    }

    @Test
    void registerVerify_wrongOtp_400() throws Exception {
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"w@test.vn","password":"password123"}
                                """))
                .andExpect(status().isAccepted());
        mvc.perform(post("/api/v1/auth/register/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"w@test.vn","otpCode":"000000"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("OTP_INVALID"));
    }

    @Test
    void register_duplicateVerifiedEmail_409() throws Exception {
        registerVerifyAndGetRefreshToken("dup@test.vn", "password123");
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
                                {"email":"not-an-email","password":"pw"}
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
    void resend_withinCooldown_429() throws Exception {
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"cd@test.vn","password":"password123"}
                                """))
                .andExpect(status().isAccepted());
        mvc.perform(post("/api/v1/auth/otp/resend")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"cd@test.vn","purpose":"REGISTER_VERIFY"}
                                """))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("OTP_RESEND_COOLDOWN"))
                .andExpect(jsonPath("$.details.retryAfterSeconds").isNumber());
    }

    @Test
    void forgotPassword_unknownEmail_still200() throws Exception {
        mvc.perform(post("/api/v1/auth/password/forgot")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"ghost@test.vn"}
                                """))
                .andExpect(status().isOk());
        org.mockito.Mockito.verify(otpSender, org.mockito.Mockito.never())
                .sendOtp(org.mockito.ArgumentMatchers.anyString(),
                        org.mockito.ArgumentMatchers.eq(OtpPurpose.PASSWORD_RESET),
                        org.mockito.ArgumentMatchers.anyString());
    }

    @Test
    void login_valid_200Tokens() throws Exception {
        registerVerifyAndGetRefreshToken("login@test.vn", "password123");
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"login@test.vn","password":"password123"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty());
    }

    @Test
    void login_wrongPassword_401() throws Exception {
        registerVerifyAndGetRefreshToken("wp@test.vn", "password123");
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
        registerVerifyAndGetRefreshToken("locked@test.vn", "password123");
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

    @Test
    void resetPassword_revokesAllRefreshTokens() throws Exception {
        String oldRefresh = registerVerifyAndGetRefreshToken("reset@test.vn", "password123");
        // Second session → second active token.
        String secondRefresh = registerVerifyAndGetRefreshToken("reset2@test.vn", "password123");

        mvc.perform(post("/api/v1/auth/password/forgot")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"reset@test.vn"}
                                """))
                .andExpect(status().isOk());

        org.mockito.ArgumentCaptor<String> code = org.mockito.ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(otpSender).sendOtp(
                org.mockito.ArgumentMatchers.eq("reset@test.vn"),
                org.mockito.ArgumentMatchers.eq(OtpPurpose.PASSWORD_RESET),
                code.capture());

        mvc.perform(post("/api/v1/auth/password/reset")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"reset@test.vn","otpCode":"%s","newPassword":"newpassword9"}
                                """.formatted(code.getValue())))
                .andExpect(status().isNoContent());

        // Old refresh token must now be dead.
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(oldRefresh)))
                .andExpect(status().isUnauthorized());
        // Unrelated user's token is untouched.
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(secondRefresh)))
                .andExpect(status().isOk());
        // New password works.
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"reset@test.vn","password":"newpassword9"}
                                """))
                .andExpect(status().isOk());
    }
}
