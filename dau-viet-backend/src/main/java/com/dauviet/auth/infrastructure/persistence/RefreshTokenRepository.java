package com.dauviet.auth.infrastructure.persistence;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.auth.domain.RefreshToken;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /**
     * Locked lookup used by rotation so two concurrent refreshes of the same
     * token cannot both pass the revoked check.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from RefreshToken t where t.tokenHash = :tokenHash")
    Optional<RefreshToken> findByTokenHashForUpdate(@Param("tokenHash") String tokenHash);

    /**
     * Theft containment: when a revoked token is replayed, revoke every
     * still-active token in its family in one statement. {@code excludeId}
     * skips the row the calling rotate() transaction already holds a
     * FOR UPDATE lock on: rotate() suspends while the REQUIRES_NEW family
     * revoke runs, so touching that row would wait on a lock only the
     * suspended transaction can release (self-deadlock).
     */
    @Modifying
    @Query("update RefreshToken t set t.revokedAt = :now "
         + "where t.tokenFamilyId = :familyId and t.revokedAt is null "
         + "and t.id <> :excludeId")
    int revokeActiveByFamily(@Param("familyId") UUID familyId, @Param("now") Instant now,
                             @Param("excludeId") UUID excludeId);
}
