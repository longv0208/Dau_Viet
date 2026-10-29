package com.dauviet.auth.application;

import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.lang.Nullable;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.auth.api.dto.ForgotPasswordRequest;
import com.dauviet.auth.api.dto.GoogleLoginRequest;
import com.dauviet.auth.api.dto.LoginRequest;
import com.dauviet.auth.api.dto.RefreshRequest;
import com.dauviet.auth.api.dto.RegisterRequest;
import com.dauviet.auth.api.dto.ResendOtpRequest;
import com.dauviet.auth.api.dto.ResetPasswordRequest;
import com.dauviet.auth.api.dto.TokenResponse;
import com.dauviet.auth.api.dto.VerifyOtpRequest;
import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.auth.domain.EmailTakenException;
import com.dauviet.auth.domain.GoogleEmailUnverifiedException;
import com.dauviet.auth.domain.OtpChallenge;
import com.dauviet.auth.domain.OtpException;
import com.dauviet.auth.domain.OtpPurpose;
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

/**
 * Auth orchestration (Issue #34): OTP-challenged registration, OTP password
 * reset with full refresh-token revocation, Google sign-in with account
 * linking, plus refresh/logout. All credential failures surface as the same
 * AuthenticationFailedException (401 INVALID_CREDENTIALS) so responses never
 * reveal whether an account exists.
 */
@Service
public class AuthService {

    /**
     * A precomputed BCrypt hash used only to equalize response timing when the
     * email is unknown — prevents user enumeration via response-time probing.
     */
    private static final String DUMMY_BCRYPT =
            "$2a$10$C6UzMDM.H6dfI/f/IKcEeO7Z3OeE3l2BMdG8v0V0xwqJfKQn7rY6i";

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenService jwtTokenService;
    private final RefreshTokenService refreshTokenService;
    private final SecurityTokenProperties props;
    private final OtpService otpService;
    private final OtpChallengeRepository otpChallenges;
    private final UserOauthAccountRepository oauthAccounts;
    /** Null when no Google client-id is configured → /auth/google 503s. */
    @Nullable
    private final GoogleTokenVerifier googleTokenVerifier;

    public AuthService(UserRepository users, PasswordEncoder passwordEncoder,
                       JwtTokenService jwtTokenService, RefreshTokenService refreshTokenService,
                       SecurityTokenProperties props, OtpService otpService,
                       OtpChallengeRepository otpChallenges,
                       UserOauthAccountRepository oauthAccounts,
                       java.util.Optional<GoogleTokenVerifier> googleTokenVerifier) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenService = jwtTokenService;
        this.refreshTokenService = refreshTokenService;
        this.props = props;
        this.otpService = otpService;
        this.otpChallenges = otpChallenges;
        this.oauthAccounts = oauthAccounts;
        this.googleTokenVerifier = googleTokenVerifier.orElse(null);
    }

    /**
    * Registration start (Issue #34): no user row yet — create a
    * REGISTER_VERIFY challenge and mail the code. Email-taken check happens
    * here so the client can render the dedicated message; timing equalized
    * via a dummy bcrypt on the taken path... actually no — EMAIL_TAKEN is an
    * explicit 409 contract (was already the case), not a secret.
    *
    * @return ttl/cooldown info for the client countdown UI.
    */
    @Transactional
    public OtpChallenge requestRegisterOtp(RegisterRequest req) {
        if (req.role() != null && !req.role().isBlank()) {
            throw new IllegalArgumentException("role is not accepted on registration");
        }
        if (users.findByEmailIgnoreCase(normalizeEmail(req.email())).isPresent()) {
            throw new EmailTakenException();
        }
        // Re-request on an existing challenge = resend: cooldown applies.
        otpService.assertResendAllowed(req.email(), OtpPurpose.REGISTER_VERIFY);
        return otpService.issue(req.email(), OtpPurpose.REGISTER_VERIFY, Map.of(
                "displayName", req.displayName() == null ? "" : req.displayName(),
                "passwordHash", passwordEncoder.encode(req.password())));
    }

    /**
    * Registration completion: verify OTP → create the ACTIVE user with
    * email_verified_at=now() → issue the token pair. The bcrypt hash was
    * computed at request time and travels inside the challenge payload, so
    * the plaintext password never sits in the challenges table.
    */
    @Transactional
    public TokenResponse verifyRegisterOtp(VerifyOtpRequest req) {
        OtpChallenge c = otpService.verify(req.email(), OtpPurpose.REGISTER_VERIFY, req.otpCode());
        Map<String, String> payload = otpService.readPayload(c);

        User user = new User();
        user.setId(UUID.randomUUID());
        user.setEmail(normalizeEmail(req.email()));
        String displayName = payload.get("displayName");
        user.setDisplayName(displayName == null || displayName.isBlank() ? null : displayName);
        user.setPasswordHash(payload.get("passwordHash"));
        user.setRole(UserRole.LEARNER);
        user.setStatus(UserStatus.ACTIVE);
        user.setEmailVerifiedAt(Instant.now());
        user.setLastLoginAt(Instant.now());
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            // Concurrent register won the email between request and verify.
            throw new EmailTakenException();
        }
        return buildTokenResponse(user);
    }

    /**
    * Resend an OTP. REGISTER_VERIFY requires an existing challenge chain
    * (assertResendAllowed enforces); PASSWORD_RESET proceeds only when an
    * ACTIVE account exists — unknown/disabled emails silently no-op so the
    * endpoint can't enumerate accounts (same contract as /password/forgot).
    */
    @Transactional
    public OtpChallenge resendOtp(ResendOtpRequest req) {
        otpService.assertResendAllowed(req.email(), req.purpose());
        if (req.purpose() == OtpPurpose.PASSWORD_RESET) {
            Optional<User> user = users.findByEmailIgnoreCase(normalizeEmail(req.email()));
            if (user.isEmpty() || user.get().getStatus() != UserStatus.ACTIVE) {
                // Can't issue a real challenge; return null and let the
                // controller answer 202 regardless (anti-enumeration).
                return null;
            }
            return otpService.issue(req.email(), OtpPurpose.PASSWORD_RESET,
                    Map.of("userId", user.get().getId().toString()));
        }
        // REGISTER_VERIFY: pointless once the account exists (e.g. user
        // already verified then hit resend) — surface as EMAIL_TAKEN rather
        // than issuing a challenge that can never succeed.
        if (users.findByEmailIgnoreCase(normalizeEmail(req.email())).isPresent()) {
            throw new EmailTakenException();
        }
        // Re-issue with the stored pending payload.
        var latest = otpChallenges.findLatest(normalizeEmail(req.email()), OtpPurpose.REGISTER_VERIFY)
                .orElseThrow(OtpException.NoChallenge::new);
        Map<String, String> payload = otpService.readPayload(latest);
        payload.remove("salt");
        return otpService.issue(req.email(), OtpPurpose.REGISTER_VERIFY, payload);
    }

    /**
    * Forgot password kickoff — ALWAYS silent about account existence. Issues
    * PASSWORD_RESET only for a matching ACTIVE user.
    */
    @Transactional
    public void forgotPassword(ForgotPasswordRequest req) {
        users.findByEmailIgnoreCase(normalizeEmail(req.email()))
                .filter(u -> u.getStatus() == UserStatus.ACTIVE)
                .ifPresent(u -> otpService.issue(u.getEmail(), OtpPurpose.PASSWORD_RESET,
                        Map.of("userId", u.getId().toString())));
    }

    /**
    * Password reset: verify OTP → set new BCrypt hash → revoke ALL of the
    * user's refresh tokens (every family). Unknown account surfaces as
    * NoChallenge (400 OTP_NO_CHALLENGE) — same as a never-requested reset.
    */
    @Transactional
    public void resetPassword(ResetPasswordRequest req) {
        OtpChallenge c = otpService.verify(req.email(), OtpPurpose.PASSWORD_RESET, req.otpCode());
        User user = users.findByEmailIgnoreCase(normalizeEmail(req.email()))
                .orElseThrow(OtpException.NoChallenge::new);
        user.setPasswordHash(passwordEncoder.encode(req.newPassword()));
        users.save(user);
        refreshTokenService.revokeAllForUser(user.getId());
    }

    /**
    * Google sign-in: verified claims → resolve (oauth link → email link →
    * auto-create) → token pair. Linking to an existing account requires the
    * local email to already be verified; otherwise a Google account could
    * capture a pending local registration.
    */
    @Transactional
    public TokenResponse loginWithGoogle(GoogleLoginRequest req) {
        if (googleTokenVerifier == null) {
            throw new FeatureDisabledException("google sign-in not configured");
        }
        GoogleTokenVerifier.VerifiedGoogleUser g = googleTokenVerifier.verify(req.idToken());

        User user = oauthAccounts.findByProviderAndProviderSubject("GOOGLE", g.subject())
                .map(link -> users.findById(link.getUserId()).orElse(null))
                .orElse(null);

        if (user == null) {
            Optional<User> byEmail = users.findByEmailIgnoreCase(g.email());
            if (byEmail.isPresent()) {
                User existing = byEmail.get();
                if (existing.getEmailVerifiedAt() == null) {
                    throw new GoogleEmailUnverifiedException();
                }
                user = existing;
                linkGoogle(user, g);
            } else {
                user = createGoogleUser(g);
            }
        }

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new AuthenticationFailedException();
        }
        user.setLastLoginAt(Instant.now());
        users.save(user);
        return buildTokenResponse(user);
    }

    private User createGoogleUser(GoogleTokenVerifier.VerifiedGoogleUser g) {
        User user = new User();
        user.setId(UUID.randomUUID());
        user.setEmail(g.email());
        user.setDisplayName(g.displayName());
        user.setPasswordHash(null);
        user.setRole(UserRole.LEARNER);
        user.setStatus(UserStatus.ACTIVE);
        user.setEmailVerifiedAt(Instant.now());
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw new EmailTakenException();
        }
        linkGoogle(user, g);
        return user;
    }

    private void linkGoogle(User user, GoogleTokenVerifier.VerifiedGoogleUser g) {
        UserOauthAccount link = new UserOauthAccount();
        link.setId(UUID.randomUUID());
        link.setUserId(user.getId());
        link.setProvider("GOOGLE");
        link.setProviderSubject(g.subject());
        link.setProviderEmail(g.email());
        oauthAccounts.save(link);
    }

    @Transactional
    public TokenResponse login(LoginRequest req) {
        User user = users.findByEmailIgnoreCase(normalizeEmail(req.email())).orElse(null);
        if (user == null) {
            // Equalize timing against the "user exists" path.
            passwordEncoder.matches(req.password(), DUMMY_BCRYPT);
            throw new AuthenticationFailedException();
        }
        // OAuth-only accounts have no password; equalize timing then fail.
        boolean passwordOk = user.getPasswordHash() != null
                && passwordEncoder.matches(req.password(), user.getPasswordHash());
        if (!passwordOk) {
            if (user.getPasswordHash() == null) {
                passwordEncoder.matches(req.password(), DUMMY_BCRYPT);
            }
            throw new AuthenticationFailedException();
        }
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new AuthenticationFailedException();
        }
        user.setLastLoginAt(Instant.now());
        users.save(user);
        return buildTokenResponse(user);
    }

    @Transactional
    public TokenResponse refresh(RefreshRequest req) {
        // rotate() enforces user existence + ACTIVE status and revokes the
        // family when the account is no longer usable.
        RefreshTokenService.IssuedToken issued = refreshTokenService.rotate(req.refreshToken());
        User user = users.findById(issued.token().getUserId())
                .orElseThrow(AuthenticationFailedException::new);
        return tokenResponse(jwtTokenService.createAccessToken(user), issued.raw());
    }

    @Transactional
    public void logout(RefreshRequest req) {
        refreshTokenService.revoke(req.refreshToken());
    }

    private TokenResponse buildTokenResponse(User user) {
        RefreshTokenService.IssuedToken issued = refreshTokenService.issue(user, null);
        return tokenResponse(jwtTokenService.createAccessToken(user), issued.raw());
    }

    private TokenResponse tokenResponse(String accessToken, String rawRefresh) {
        return new TokenResponse(accessToken, "Bearer",
                props.getAccessTokenTtlSeconds(), rawRefresh, props.getRefreshTokenTtlSeconds());
    }

    static String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }
}
