package com.dauviet.auth.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.dauviet.auth.api.dto.GoogleLoginRequest;
import com.dauviet.auth.api.dto.TokenResponse;
import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.auth.domain.GoogleEmailUnverifiedException;
import com.dauviet.auth.domain.GoogleTokenInvalidException;
import com.dauviet.auth.domain.RefreshToken;
import com.dauviet.auth.domain.UserOauthAccount;
import com.dauviet.auth.infrastructure.persistence.OtpChallengeRepository;
import com.dauviet.auth.infrastructure.persistence.UserOauthAccountRepository;
import com.dauviet.common.error.FeatureDisabledException;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.security.jwt.SecurityTokenProperties;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;

@ExtendWith(MockitoExtension.class)
class GoogleAuthServiceTest {

    @Mock private UserRepository users;
    @Mock private JwtTokenService jwtTokenService;
    @Mock private RefreshTokenService refreshTokenService;
    @Mock private OtpService otpService;
    @Mock private OtpChallengeRepository otpChallenges;
    @Mock private UserOauthAccountRepository oauthAccounts;
    @Mock private GoogleTokenVerifier googleVerifier;

    private final PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    private SecurityTokenProperties props = new SecurityTokenProperties();
    private AuthService service;

    @BeforeEach
    void setUp() {
        props.setAccessTokenTtlSeconds(900);
        props.setRefreshTokenTtlSeconds(1209600);
        service = new AuthService(users, passwordEncoder, jwtTokenService,
                refreshTokenService, props, otpService, otpChallenges,
                oauthAccounts, Optional.of(googleVerifier));
    }

    private void stubTokenIssue() {
        when(jwtTokenService.createAccessToken(any())).thenReturn("access.jwt");
        when(refreshTokenService.issue(any(User.class), any())).thenAnswer(i -> {
            RefreshToken row = new RefreshToken();
            row.setId(UUID.randomUUID());
            User u = i.getArgument(0);
            row.setUserId(u.getId());
            return new RefreshTokenService.IssuedToken("raw-refresh", row);
        });
    }

    private GoogleTokenVerifier.VerifiedGoogleUser googleUser(String sub, String email) {
        return new GoogleTokenVerifier.VerifiedGoogleUser(sub, email, "Tên Người Dùng");
    }

    @Test
    void google_newEmail_createsVerifiedLearner_linksAndIssuesTokens() {
        stubTokenIssue();
        when(googleVerifier.verify("good-token", null)).thenReturn(googleUser("sub-1", "new@gmail.com"));
        when(oauthAccounts.findByProviderAndProviderSubject("GOOGLE", "sub-1"))
                .thenReturn(Optional.empty());
        when(users.findByEmailIgnoreCase("new@gmail.com")).thenReturn(Optional.empty());
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> i.getArgument(0));

        TokenResponse res = service.loginWithGoogle(new GoogleLoginRequest("good-token", null));

        ArgumentCaptor<User> uc = ArgumentCaptor.forClass(User.class);
        verify(users).saveAndFlush(uc.capture());
        User created = uc.getValue();
        assertThat(created.getEmail()).isEqualTo("new@gmail.com");
        assertThat(created.getRole()).isEqualTo(UserRole.LEARNER);
        assertThat(created.getStatus()).isEqualTo(UserStatus.ACTIVE);
        assertThat(created.getEmailVerifiedAt()).isNotNull();
        assertThat(created.getPasswordHash()).isNull();

        ArgumentCaptor<UserOauthAccount> lc = ArgumentCaptor.forClass(UserOauthAccount.class);
        verify(oauthAccounts).save(lc.capture());
        assertThat(lc.getValue().getProvider()).isEqualTo("GOOGLE");
        assertThat(lc.getValue().getProviderSubject()).isEqualTo("sub-1");
        assertThat(lc.getValue().getUserId()).isEqualTo(created.getId());

        assertThat(res.accessToken()).isEqualTo("access.jwt");
        assertThat(res.refreshToken()).isEqualTo("raw-refresh");
    }

    @Test
    void google_existingVerifiedEmail_linksAccountAndLogsIn() {
        stubTokenIssue();
        User existing = new User();
        existing.setId(UUID.randomUUID());
        existing.setEmail("ex@gmail.com");
        existing.setStatus(UserStatus.ACTIVE);
        existing.setEmailVerifiedAt(Instant.now());
        when(googleVerifier.verify("tok", null)).thenReturn(googleUser("sub-2", "ex@gmail.com"));
        when(oauthAccounts.findByProviderAndProviderSubject("GOOGLE", "sub-2"))
                .thenReturn(Optional.empty());
        when(users.findByEmailIgnoreCase("ex@gmail.com")).thenReturn(Optional.of(existing));

        TokenResponse res = service.loginWithGoogle(new GoogleLoginRequest("tok", null));

        verify(oauthAccounts).save(any(UserOauthAccount.class));
        assertThat(res.accessToken()).isNotEmpty();
        verify(users, never()).saveAndFlush(any()); // no new user created
    }

    @Test
    void google_existingUnverifiedEmail_refusesLink_403() {
        User pending = new User();
        pending.setId(UUID.randomUUID());
        pending.setEmail("p@gmail.com");
        pending.setStatus(UserStatus.ACTIVE);
        pending.setEmailVerifiedAt(null);
        when(googleVerifier.verify("tok", null)).thenReturn(googleUser("sub-3", "p@gmail.com"));
        when(oauthAccounts.findByProviderAndProviderSubject("GOOGLE", "sub-3"))
                .thenReturn(Optional.empty());
        when(users.findByEmailIgnoreCase("p@gmail.com")).thenReturn(Optional.of(pending));

        assertThatThrownBy(() -> service.loginWithGoogle(new GoogleLoginRequest("tok", null)))
                .isInstanceOf(GoogleEmailUnverifiedException.class);
        verify(oauthAccounts, never()).save(any());
    }

    @Test
    void google_linkedSub_signsInDirectly() {
        stubTokenIssue();
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail("linked@gmail.com");
        u.setStatus(UserStatus.ACTIVE);
        UserOauthAccount link = new UserOauthAccount();
        link.setUserId(u.getId());
        when(googleVerifier.verify("tok", null)).thenReturn(googleUser("sub-4", "linked@gmail.com"));
        when(oauthAccounts.findByProviderAndProviderSubject("GOOGLE", "sub-4"))
                .thenReturn(Optional.of(link));
        when(users.findById(u.getId())).thenReturn(Optional.of(u));

        TokenResponse res = service.loginWithGoogle(new GoogleLoginRequest("tok", null));
        assertThat(res.refreshToken()).isEqualTo("raw-refresh");
        verify(oauthAccounts, never()).save(any()); // already linked
    }

    @Test
    void google_lockedUser_401() {
        User locked = new User();
        locked.setId(UUID.randomUUID());
        locked.setEmail("lock@gmail.com");
        locked.setStatus(UserStatus.LOCKED);
        UserOauthAccount link = new UserOauthAccount();
        link.setUserId(locked.getId());
        when(googleVerifier.verify("tok", null)).thenReturn(googleUser("sub-5", "lock@gmail.com"));
        when(oauthAccounts.findByProviderAndProviderSubject("GOOGLE", "sub-5"))
                .thenReturn(Optional.of(link));
        when(users.findById(locked.getId())).thenReturn(Optional.of(locked));

        assertThatThrownBy(() -> service.loginWithGoogle(new GoogleLoginRequest("tok", null)))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void google_invalidToken_propagates401() {
        when(googleVerifier.verify("bad", null)).thenThrow(new GoogleTokenInvalidException("bad sig"));
        assertThatThrownBy(() -> service.loginWithGoogle(new GoogleLoginRequest("bad", null)))
                .isInstanceOf(GoogleTokenInvalidException.class);
    }

    // Issue #41 — Flutter Web sends an OAuth2 accessToken (idToken is null
    // on web); it must flow to the verifier's accessToken branch and log in
    // identically to the idToken path.
    @Test
    void google_accessToken_newEmail_createsLearnerAndIssuesTokens() {
        when(googleVerifier.verify(null, "ya29.web-token"))
                .thenReturn(googleUser("sub-web", "web@gmail.com"));
        when(users.findByEmailIgnoreCase("web@gmail.com")).thenReturn(Optional.empty());
        when(oauthAccounts.findByProviderAndProviderSubject("GOOGLE", "sub-web"))
                .thenReturn(Optional.empty());
        stubTokenIssue();

        TokenResponse res =
                service.loginWithGoogle(new GoogleLoginRequest(null, "ya29.web-token"));

        ArgumentCaptor<User> uc = ArgumentCaptor.forClass(User.class);
        verify(users).saveAndFlush(uc.capture());
        assertThat(uc.getValue().getRole()).isEqualTo(UserRole.LEARNER);
        assertThat(uc.getValue().getStatus()).isEqualTo(UserStatus.ACTIVE);
        verify(oauthAccounts).save(any(UserOauthAccount.class));
        assertThat(res.accessToken()).isEqualTo("access.jwt");
    }

    @Test
    void google_noVerifierBean_503() {
        AuthService noGoogle = new AuthService(users, passwordEncoder, jwtTokenService,
                refreshTokenService, props, otpService, otpChallenges,
                oauthAccounts, Optional.empty());
        assertThatThrownBy(() -> noGoogle.loginWithGoogle(new GoogleLoginRequest("tok", null)))
                .isInstanceOf(FeatureDisabledException.class);
    }
}
