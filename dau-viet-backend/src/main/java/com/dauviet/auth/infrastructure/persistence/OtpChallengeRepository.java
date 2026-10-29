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

import com.dauviet.auth.domain.OtpChallenge;
import com.dauviet.auth.domain.OtpPurpose;

public interface OtpChallengeRepository extends JpaRepository<OtpChallenge, UUID> {

    /**
     * The single active (unconsumed) challenge for (email,purpose) — the
     * ux_otp_active partial unique index guarantees at most one row. PESSIMISTIC
     *_WRITE so verify() attempts++ and consume are atomic vs. concurrent
     * verify/resend of the same challenge.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from OtpChallenge c where lower(c.email) = lower(:email) "
         + "and c.purpose = :purpose and c.consumedAt is null")
    Optional<OtpChallenge> findActiveForUpdate(@Param("email") String email,
                                               @Param("purpose") OtpPurpose purpose);

    @Query("select c from OtpChallenge c where lower(c.email) = lower(:email) "
         + "and c.purpose = :purpose and c.consumedAt is null")
    Optional<OtpChallenge> findActive(@Param("email") String email,
                                      @Param("purpose") OtpPurpose purpose);

    /**
     * Invalidate any active challenge before issuing a fresh one — a resend
     * can never leave two live codes for the same (email,purpose).
     */
    @Modifying
    @Query("update OtpChallenge c set c.consumedAt = :now "
         + "where lower(c.email) = lower(:email) and c.purpose = :purpose "
         + "and c.consumedAt is null")
    int consumeActive(@Param("email") String email,
                      @Param("purpose") OtpPurpose purpose,
                      @Param("now") Instant now);

    /** Latest challenge (any state) — for resend cooldown measurement. */
    @Query("select c from OtpChallenge c where lower(c.email) = lower(:email) "
         + "and c.purpose = :purpose order by c.createdAt desc limit 1")
    Optional<OtpChallenge> findLatest(@Param("email") String email,
                                      @Param("purpose") OtpPurpose purpose);
}
