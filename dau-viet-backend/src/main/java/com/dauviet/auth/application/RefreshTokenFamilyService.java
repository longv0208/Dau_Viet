package com.dauviet.auth.application;

import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.auth.infrastructure.persistence.RefreshTokenRepository;

/**
 * Separate bean owning family-revocation so it can commit independently of
 * the rotate() transaction (which always ends in a rollback-inducing
 * AuthenticationFailedException on replay/locked-user paths).
 */
@Service
public class RefreshTokenFamilyService {

    private final RefreshTokenRepository tokens;

    public RefreshTokenFamilyService(RefreshTokenRepository tokens) {
        this.tokens = tokens;
    }

    /**
     * Revokes every still-active token of the family in its own transaction.
     * {@code excludeId} is the row rotate() currently holds a FOR UPDATE lock
     * on; updating it here would block on the suspended outer transaction.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int revokeFamily(UUID familyId, UUID excludeId) {
        return tokens.revokeActiveByFamily(familyId, Instant.now(), excludeId);
    }
}
