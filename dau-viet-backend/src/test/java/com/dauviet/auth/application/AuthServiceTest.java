package com.dauviet.auth.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.dauviet.auth.api.dto.LoginRequest;
import com.dauviet.auth.api.dto.RefreshRequest;
import com.dauviet.auth.api.dto.RegisterRequest;
import com.dauviet.auth.api.dto.TokenResponse;
import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.auth.domain.EmailTakenException;
import com.dauviet.auth.domain.RefreshToken;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.security.jwt.SecurityTokenProperties;
import com.dauviet.user.api.mapper.UserMapper;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock private UserRepository users;
    @Mock private JwtTokenService jwtTokenService;
    @Mock private RefreshTokenService refreshTokenService;
    @Mock private UserMapper mapper;

    private PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    private SecurityTokenProperties props = new SecurityTokenProperties();

    private AuthService service;

    @BeforeEach
    void setUp() {
        props.setAccessTokenTtlSeconds(900);
        props.setRefreshTokenTtlSeconds(1209600);
        service = new AuthService(users, passwordEncoder, jwtTokenService,
                refreshTokenService, props, mapper);
    }

    private RegisterRequest registerReq(String email, String pw) {
        return new RegisterRequest(email, pw, "Tên", null);
    }

    @Test
    void register_normalizesEmailAndForcesLearnerRole() {
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> i.getArgument(0));
        when(mapper.toProfileDto(any())).thenReturn(null);
        service.register(registerReq("  Learner@Example.VN ", "password123"));
        org.mockito.ArgumentCaptor<User> captor =
                org.mockito.ArgumentCaptor.forClass(User.class);
        verify(users).saveAndFlush(captor.capture());
        assertThat(captor.getValue().getEmail()).isEqualTo("learner@example.vn");
        assertThat(captor.getValue().getRole()).isEqualTo(UserRole.LEARNER);
        assertThat(captor.getValue().getStatus()).isEqualTo(UserStatus.ACTIVE);
        assertThat(passwordEncoder.matches("password123",
                captor.getValue().getPasswordHash())).isTrue();
    }

    @Test
    void register_rejectsSuppliedRole() {
        assertThatThrownBy(() -> service.register(
                new RegisterRequest("a@b.vn", "password123", null, "CONTENT_ADMIN")))
                .isInstanceOf(IllegalArgumentException.class);
        verify(users, never()).saveAndFlush(any());
    }

    @Test
    void register_duplicateEmail_throwsEmailTaken() {
        when(users.saveAndFlush(any(User.class)))
                .thenThrow(new DataIntegrityViolationException("ux_users_email_lower"));
        assertThatThrownBy(() -> service.register(registerReq("a@b.vn", "password123")))
                .isInstanceOf(EmailTakenException.class);
    }

    @Test
    void login_unknownEmail_uniform401_withTimingBlunting() {
        when(users.findByEmailIgnoreCase("x@y.vn")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.login(new LoginRequest("x@y.vn", "pw")))
                .isInstanceOf(AuthenticationFailedException.class);
        verify(users, never()).save(any());
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
    void login_lockedUser_401() {
        User u = activeUser();
        u.setStatus(UserStatus.LOCKED);
        u.setPasswordHash(passwordEncoder.encode("pw123456"));
        when(users.findByEmailIgnoreCase("u@v.vn")).thenReturn(Optional.of(u));
        assertThatThrownBy(() -> service.login(new LoginRequest("u@v.vn", "pw123456")))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void login_success_returnsTokenPair_andUpdatesLastLogin() {
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
        assertThat(res.tokenType()).isEqualTo("Bearer");
        assertThat(res.refreshToken()).isEqualTo("raw-refresh");
        assertThat(res.expiresIn()).isEqualTo(900);
        assertThat(u.getLastLoginAt()).isNotNull();
    }

    @Test
    void refresh_delegatesRotation_andBuildsResponse() {
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
        assertThat(res.refreshToken()).isEqualTo("raw-new");
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
