package com.dauviet.auth.application;

import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.auth.api.dto.LoginRequest;
import com.dauviet.auth.api.dto.RefreshRequest;
import com.dauviet.auth.api.dto.RegisterRequest;
import com.dauviet.auth.api.dto.TokenResponse;
import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.auth.domain.EmailTakenException;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.security.jwt.SecurityTokenProperties;
import com.dauviet.user.api.dto.UserProfileDto;
import com.dauviet.user.api.mapper.UserMapper;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;

/**
 * Register/login/refresh/logout orchestration. All authentication failures
 * surface as the same AuthenticationFailedException (401 INVALID_CREDENTIALS)
 * so responses never reveal whether an account exists.
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
    private final UserMapper mapper;

    public AuthService(UserRepository users, PasswordEncoder passwordEncoder,
                       JwtTokenService jwtTokenService, RefreshTokenService refreshTokenService,
                       SecurityTokenProperties props, UserMapper mapper) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenService = jwtTokenService;
        this.refreshTokenService = refreshTokenService;
        this.props = props;
        this.mapper = mapper;
    }

    @Transactional
    public UserProfileDto register(RegisterRequest req) {
        if (req.role() != null && !req.role().isBlank()) {
            throw new IllegalArgumentException("role is not accepted on registration");
        }
        User user = new User();
        user.setId(UUID.randomUUID());
        user.setEmail(normalizeEmail(req.email()));
        user.setDisplayName(req.displayName());
        user.setPasswordHash(passwordEncoder.encode(req.password()));
        user.setRole(UserRole.LEARNER);
        user.setStatus(UserStatus.ACTIVE);
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw new EmailTakenException();
        }
        return mapper.toProfileDto(user);
    }

    @Transactional
    public TokenResponse login(LoginRequest req) {
        User user = users.findByEmailIgnoreCase(normalizeEmail(req.email())).orElse(null);
        if (user == null) {
            // Equalize timing against the "user exists" path.
            passwordEncoder.matches(req.password(), DUMMY_BCRYPT);
            throw new AuthenticationFailedException();
        }
        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())
                || user.getStatus() != UserStatus.ACTIVE) {
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
