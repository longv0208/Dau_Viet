package com.dauviet.auth.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.dauviet.auth.api.dto.ForgotPasswordRequest;
import com.dauviet.auth.api.dto.LoginRequest;
import com.dauviet.auth.api.dto.RefreshRequest;
import com.dauviet.auth.api.dto.RegisterRequest;
import com.dauviet.auth.api.dto.ResetPasswordRequest;
import com.dauviet.auth.api.dto.TokenResponse;
import com.dauviet.auth.api.dto.VerifyOtpRequest;
import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.auth.domain.EmailTakenException;
import com.dauviet.auth.domain.OtpChallenge;
import com.dauviet.auth.domain.OtpPurpose;
import com.dauviet.auth.domain.RefreshToken;
import com.dauviet.auth.infrastructure.persistence.OtpChallengeRepository;
import com.dauviet.auth.infrastructure.persistence.UserOauthAccountRepository;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.security.jwt.SecurityTokenProperties;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock private UserRepository users;
    @Mock private JwtTokenService jwtTokenService;
    @Mock private RefreshTokenService refreshTokenService;
    @Mock private OtpService otpService;
    @Mock private OtpChallengeRepository otpChallenges;
    @Mock private UserOauthAccountRepository oauthAccounts;

    private final PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    private SecurityTokenProperties props = new SecurityTokenProperties();
    private AuthService service;

    @BeforeEach
    void setUp() {
        props.setAccessTokenTtlSeconds(900);
        props.setRefreshTokenTtlSeconds(1209600);
        service = new AuthService(users, passwordEncoder, jwtTokenService,
                refreshTokenService, props, otpService, otpChallenges,
                oauthAccounts, Optional.empty());
    }

    private RegisterRequest registerReq(String email, String pw) {
        return new RegisterRequest(email, pw, "Tên", null);
    }

    // ── Registration (OTP-challenged) ──────────────────────────────

    @Test
    void registerRequest_issuesOtpChallenge_noUserCreatedYet() {
        when(users.findByEmailIgnoreCase("new@test.vn")).thenReturn(Optional.empty());
        OtpChallenge challenge = new OtpChallenge();
        when(otpService.issue(any(), any(), any())).thenReturn(challenge);

        service.requestRegisterOtp(registerReq("  New@Test.VN ", "password123"));

        ArgumentCaptor<Map<String, String>> payload =
                ArgumentCaptor.forClass(Map.class);
        verify(otpService).assertResendAllowed("  New@Test.VN ", OtpPurpose.REGISTER_VERIFY);
        verify(otpService).issue(eq("  New@Test.VN "), eq(OtpPurpose.REGISTER_VERIFY),
                payload.capture());
        assertThat(payload.getValue()).containsEntry("displayName", "Tên");
        assertThat(passwordEncoder.matches("password123",
                payload.getValue().get("passwordHash"))).isTrue();
        verify(users, never()).saveAndFlush(any());
    }

    @Test
    void registerRequest_duplicateEmail_throwsEmailTaken() {
        when(users.findByEmailIgnoreCase("dup@test.vn")).thenReturn(Optional.of(activeUser()));
        assertThatThrownBy(() -> service.requestRegisterOtp(registerReq("dup@test.vn", "password123")))
                .isInstanceOf(EmailTakenException.class);
    }

    @Test
    void registerRequest_rejectsSuppliedRole() {
        assertThatThrownBy(() -> service.requestRegisterOtp(
                new RegisterRequest("a@b.vn", "password123", null, "CONTENT_ADMIN")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void verifyRegister_createsVerifiedUser_andReturnsTokens() {
        OtpChallenge c = new OtpChallenge();
        c.setPayloadJson("{\"displayName\":\"Tên\",\"passwordHash\":\""
                + passwordEncoder.encode("password123") + "\",\"salt\":\"s\"}");
        when(otpService.verify("v@t.vn", OtpPurpose.REGISTER_VERIFY, "123456")).thenReturn(c);
        when(otpService.readPayload(c)).thenReturn(Map.of(
                "displayName", "Tên",
                "passwordHash", passwordEncoder.encode("password123")));
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> i.getArgument(0));
        when(jwtTokenService.createAccessToken(any())).thenReturn("access");
        when(refreshTokenService.issue(any(), any())).thenAnswer(i -> {
            RefreshToken row = new RefreshToken();
            row.setId(UUID.randomUUID());
            return new RefreshTokenService.IssuedToken("raw", row);
        });

        TokenResponse res = service.verifyRegisterOtp(new VerifyOtpRequest("v@t.vn", "123456"));

        ArgumentCaptor<User> uc = ArgumentCaptor.forClass(User.class);
        verify(users).saveAndFlush(uc.capture());
        assertThat(uc.getValue().getEmailVerifiedAt()).isNotNull();
        assertThat(uc.getValue().getStatus()).isEqualTo(UserStatus.ACTIVE);
        assertThat(uc.getValue().getRole()).isEqualTo(UserRole.LEARNER);
        assertThat(res.accessToken()).isEqualTo("access");
    }

    @Test
    void verifyRegister_concurrentDuplicate_throwsEmailTaken() {
        OtpChallenge c = new OtpChallenge();
        when(otpService.verify("v@t.vn", OtpPurpose.REGISTER_VERIFY, "123456")).thenReturn(c);
        when(otpService.readPayload(c)).thenReturn(Map.of("passwordHash", "h"));
        when(users.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("ux"));

        assertThatThrownBy(() -> service.verifyRegisterOtp(new VerifyOtpRequest("v@t.vn", "123456")))
                .isInstanceOf(EmailTakenException.class);
    }

    // ── Password reset ─────────────────────────────────────────────

    @Test
    void forgotPassword_activeUser_issuesChallenge() {
        User u = activeUser();
        when(users.findByEmailIgnoreCase("u@v.vn")).thenReturn(Optional.of(u));
        service.forgotPassword(new ForgotPasswordRequest("u@v.vn"));
        verify(otpService).issue(eq("u@v.vn"), eq(OtpPurpose.PASSWORD_RESET), any());
    }

    @Test
    void forgotPassword_unknownOrLocked_silentlyNoOps() {
        when(users.findByEmailIgnoreCase("g@v.vn")).thenReturn(Optional.empty());
        service.forgotPassword(new ForgotPasswordRequest("g@v.vn"));

        User locked = activeUser();
        locked.setStatus(UserStatus.LOCKED);
        when(users.findByEmailIgnoreCase("l@v.vn")).thenReturn(Optional.of(locked));
        service.forgotPassword(new ForgotPasswordRequest("l@v.vn"));

        verify(otpService, never()).issue(any(), any(), any());
    }

    @Test
    void resetPassword_verifiesOtp_setsHash_revokesAllRefreshTokens() {
        OtpChallenge c = new OtpChallenge();
        when(otpService.verify("r@t.vn", OtpPurpose.PASSWORD_RESET, "654321")).thenReturn(c);
        User u = activeUser();
        when(users.findByEmailIgnoreCase("r@t.vn")).thenReturn(Optional.of(u));
        when(users.save(any())).thenAnswer(i -> i.getArgument(0));

        service.resetPassword(new ResetPasswordRequest("r@t.vn", "654321", "newpassword1"));

        assertThat(passwordEncoder.matches("newpassword1", u.getPasswordHash())).isTrue();
        verify(refreshTokenService).revokeAllForUser(u.getId());
    }

    // ── Login / refresh / logout ───────────────────────────────────

    @Test
    void login_unknownEmail_uniform401() {
        when(users.findByEmailIgnoreCase("x@y.vn")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.login(new LoginRequest("x@y.vn", "pw")))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void login_wrongPassword_401() {
        User u = activeUser();
        u.setPasswordHash(passwordEncoder.encode("correct"));
        when(users.findByEmailIgnoreCase("u@v.vn")).thenReturn(Optional.of(u));
        assertThatThrownBy(() -> service.login(new LoginRequest("u@v.vn", "wrong")))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void login_oauthOnlyAccount_nullHash_401() {
        User u = activeUser();
        u.setPasswordHash(null); // Google-only account
        when(users.findByEmailIgnoreCase("u@v.vn")).thenReturn(Optional.of(u));
        assertThatThrownBy(() -> service.login(new LoginRequest("u@v.vn", "anything")))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void login_lockedUser_401() {
        User u = activeUser();
        u.setStatus(UserStatus.LOCKED);
        u.setPasswordHash(passwordEncoder.encode("pw123456"));
        when(users.findByEmailIgnoreCase("u@v.vn")).thenReturn(Optional.of(u));
        assertThatThrownBy(() -> service.login(new LoginRequest("u@v.vn", "pw123456")))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void login_success_returnsTokenPair() {
        User u = activeUser();
        u.setPasswordHash(passwordEncoder.encode("pw123456"));
        when(users.findByEmailIgnoreCase("u@v.vn")).thenReturn(Optional.of(u));
        when(jwtTokenService.createAccessToken(u)).thenReturn("access.jwt");
        RefreshToken row = new RefreshToken();
        row.setId(UUID.randomUUID());
        row.setUserId(u.getId());
        when(refreshTokenService.issue(any(User.class), any()))
                .thenReturn(new RefreshTokenService.IssuedToken("raw-refresh", row));

        TokenResponse res = service.login(new LoginRequest("u@v.vn", "pw123456"));
        assertThat(res.accessToken()).isEqualTo("access.jwt");
        assertThat(res.refreshToken()).isEqualTo("raw-refresh");
        assertThat(u.getLastLoginAt()).isNotNull();
    }

    @Test
    void refresh_delegatesRotation() {
        User u = activeUser();
        RefreshToken newToken = new RefreshToken();
        newToken.setId(UUID.randomUUID());
        newToken.setUserId(u.getId());
        when(refreshTokenService.rotate("raw-old"))
                .thenReturn(new RefreshTokenService.IssuedToken("raw-new", newToken));
        when(users.findById(u.getId())).thenReturn(Optional.of(u));
        when(jwtTokenService.createAccessToken(u)).thenReturn("new-access");

        TokenResponse res = service.refresh(new RefreshRequest("raw-old"));
        assertThat(res.accessToken()).isEqualTo("new-access");
        verify(refreshTokenService).rotate("raw-old");
    }

    @Test
    void logout_delegatesRevoke() {
        service.logout(new RefreshRequest("raw-x"));
        verify(refreshTokenService).revoke("raw-x");
    }

    private User activeUser() {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail("u@v.vn");
        u.setRole(UserRole.LEARNER);
        u.setStatus(UserStatus.ACTIVE);
        return u;
    }
}
