package com.dauviet.auth.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.auth.domain.RefreshToken;
import com.dauviet.auth.infrastructure.persistence.RefreshTokenRepository;
import com.dauviet.security.jwt.SecurityTokenProperties;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;

/**
 * Refresh-token lifecycle. Raw tokens are 256-bit random values shown to the
 * client exactly once; only the SHA-256 hash is persisted. Rotation revokes
 * the old token inside the same family; replaying a revoked token revokes the
 * entire family (theft containment).
 */
@Service
public class RefreshTokenService {

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenService.class);
    private static final int RAW_TOKEN_BYTES = 32;

    private final RefreshTokenRepository tokens;
    private final SecurityTokenProperties props;
    private final Function<UUID, User> userLoader;
    private final RefreshTokenFamilyService familyService;
    private final SecureRandom random = new SecureRandom();

    public RefreshTokenService(RefreshTokenRepository tokens, SecurityTokenProperties props,
                               UserRepository userRepository,
                               RefreshTokenFamilyService familyService) {
        this.tokens = tokens;
        this.props = props;
        this.userLoader = id -> userRepository.findById(id).orElse(null);
        this.familyService = familyService;
    }

    /** Result of issue/rotate: raw value for the client + the stored row. */
    public record IssuedToken(String raw, RefreshToken token) {}

    /** Issue a fresh token. previous == null starts a new family. */
    @Transactional
    public IssuedToken issue(User user, RefreshToken previous) {
        byte[] rawBytes = new byte[RAW_TOKEN_BYTES];
        random.nextBytes(rawBytes);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(rawBytes);

        RefreshToken token = new RefreshToken();
        token.setId(UUID.randomUUID());
        token.setUserId(user.getId());
        token.setTokenHash(hash(raw));
        token.setTokenFamilyId(previous == null ? UUID.randomUUID() : previous.getTokenFamilyId());
        token.setPreviousTokenId(previous == null ? null : previous.getId());
        token.setExpiresAt(Instant.now().plusSeconds(props.getRefreshTokenTtlSeconds()));
        return new IssuedToken(raw, tokens.save(token));
    }

    /**
     * Rotate: validate the presented token, revoke it, issue its successor.
     * All failure modes are a uniform AuthenticationFailedException (401) —
     * replay detection logs token/family ids only, never the raw value.
     */
    @Transactional
    public IssuedToken rotate(String raw) {
        RefreshToken current = tokens.findByTokenHashForUpdate(hash(raw))
                .orElseThrow(AuthenticationFailedException::new);
        Instant now = Instant.now();

        if (current.isRevoked()) {
            // Reuse of a rotated/revoked token: assume theft, kill the family.
            // REQUIRES_NEW so the revoke commits even though this method then
            // throws and the outer transaction rolls back. Excludes `current`:
            // the outer tx holds its FOR UPDATE lock while suspended, and the
            // bulk update would otherwise block on it (self-deadlock).
            familyService.revokeFamily(current.getTokenFamilyId(), current.getId());
            log.warn("refresh token replay detected familyId={} tokenId={}",
                    current.getTokenFamilyId(), current.getId());
            throw new AuthenticationFailedException();
        }
        if (current.isExpired(now)) {
            throw new AuthenticationFailedException();
        }

        // Revoke first, then verify the account: even if the user lookup
        // throws, the consumed token stays dead (fail-safe ordering).
        current.setRevokedAt(now);
        current.setLastUsedAt(now);
        tokens.save(current);

        User user = userLoader.apply(current.getUserId());
        if (user == null || user.getStatus() != UserStatus.ACTIVE) {
            // Account locked/disabled since issue — contain the family too
            // (REQUIRES_NEW: must commit despite the exception we then throw;
            // excludes `current` which the suspended outer tx has locked).
            familyService.revokeFamily(current.getTokenFamilyId(), current.getId());
            throw new AuthenticationFailedException();
        }
        return issue(user, current);
    }

    /** Idempotent logout: revoke the presented token if it is still active. */
    @Transactional
    public void revoke(String raw) {
        findByRaw(raw).ifPresent(t -> {
            if (!t.isRevoked()) {
                t.setRevokedAt(Instant.now());
                tokens.save(t);
            }
        });
    }

    /**
    * Password reset / account-recovery containment: revoke every active
    * refresh token the user holds, all families (Issue #34). Runs inside the
    * caller's transaction so it commits or rolls back with the password
    * update.
    */
    @Transactional
    public int revokeAllForUser(java.util.UUID userId) {
        return tokens.revokeActiveByUser(userId, Instant.now());
    }

    public Optional<RefreshToken> findByRaw(String raw) {
        return tokens.findByTokenHash(hash(raw));
    }

    public static String hash(String raw) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(raw.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
