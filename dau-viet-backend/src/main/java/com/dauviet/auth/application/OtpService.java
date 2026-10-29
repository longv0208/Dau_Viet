package com.dauviet.auth.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.auth.domain.OtpChallenge;
import com.dauviet.auth.domain.OtpException;
import com.dauviet.auth.domain.OtpPurpose;
import com.dauviet.auth.infrastructure.persistence.OtpChallengeRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * OTP lifecycle (Issue #34): issue / verify / resend.
 *
 * Invariants:
 * - At most one active challenge per (email,purpose) — ux_otp_active index;
 *   issue() consumes any prior active row first.
 * - Code = 6 digits via SecureRandom; stored hash is SHA-256(salt + ":" +
 *   code) with a per-challenge random salt inside payload_json, so identical
 *   codes hash differently and DB reads never reveal a code.
 * - verify() increments attempts BEFORE comparing; reaching max_attempts
 *   consumes the challenge and throws MaxAttemptsExceeded.
 * - Resend enforces resendCooldownSeconds measured from the latest
 *   challenge's created_at, then issues a new code (old one dead by design).
 */
@Service
public class OtpService {

    private static final Logger log = LoggerFactory.getLogger(OtpService.class);
    private static final String SALT_KEY = "salt";

    private final OtpChallengeRepository challenges;
    private final OtpSender sender;
    private final AuthOtpProperties props;
    private final ObjectMapper objectMapper;
    private final SecureRandom random = new SecureRandom();

    public OtpService(OtpChallengeRepository challenges, OtpSender sender,
                      AuthOtpProperties props, ObjectMapper objectMapper) {
        this.challenges = challenges;
        this.sender = sender;
        this.props = props;
        this.objectMapper = objectMapper;
    }

    /**
     * Issue a fresh challenge for (email,purpose). Any prior active challenge
     * is consumed. {@code extraPayload} is merged into payload_json alongside
     * the salt — for REGISTER_VERIFY it carries {displayName,passwordHash}.
     *
     * @return the persisted challenge (created_at drives resend cooldown).
     */
    @Transactional
    public OtpChallenge issue(String email, OtpPurpose purpose, Map<String, String> extraPayload) {
        String normalized = AuthService.normalizeEmail(email);
        challenges.consumeActive(normalized, purpose, Instant.now());

        String code = generateCode();
        String salt = UUID.randomUUID().toString();

        OtpChallenge c = new OtpChallenge();
        c.setId(UUID.randomUUID());
        c.setEmail(normalized);
        c.setPurpose(purpose);
        c.setCodeHash(hash(salt, code));
        c.setMaxAttempts(props.getMaxAttempts());
        c.setExpiresAt(Instant.now().plusSeconds(props.getTtlSeconds()));
        c.setPayloadJson(serialize(extraPayload, salt));
        OtpChallenge saved = challenges.save(c);

        sender.sendOtp(normalized, purpose, code);
        return saved;
    }

    /**
     * Verify a submitted code against the active challenge, consuming it on
     * success. Throws Invalid (attempts incremented), Expired, or
     * MaxAttemptsExceeded. NoChallenge when nothing pending.
     *
     * @return the verified, consumed challenge (payload readable by caller).
     */
    @Transactional
    public OtpChallenge verify(String email, OtpPurpose purpose, String code) {
        String normalized = AuthService.normalizeEmail(email);
        OtpChallenge c = challenges.findActiveForUpdate(normalized, purpose)
                .orElseThrow(OtpException.NoChallenge::new);
        Instant now = Instant.now();

        if (c.isExpired(now)) {
            c.setConsumedAt(now);
            challenges.save(c);
            throw new OtpException.Expired();
        }

        String salt = extractSalt(c.getPayloadJson());
        if (!MessageDigest.isEqual(
                c.getCodeHash().getBytes(StandardCharsets.UTF_8),
                hash(salt, code == null ? "" : code).getBytes(StandardCharsets.UTF_8))) {
            int attempts = c.getAttempts() + 1;
            c.setAttempts(attempts);
            if (attempts >= c.getMaxAttempts()) {
                c.setConsumedAt(now);
                challenges.save(c);
                throw new OtpException.MaxAttemptsExceeded();
            }
            challenges.save(c);
            throw new OtpException.Invalid(c.getMaxAttempts() - attempts);
        }

        c.setConsumedAt(now);
        challenges.save(c);
        return c;
    }

    /**
     * Resend guard — caller then invokes issue(). Throws ResendCooldown when
     * the most recent challenge is younger than resendCooldownSeconds. For
     * REGISTER_VERIFY a missing challenge is an error (NoChallenge): there is
     * nothing legitimate to resend to. PASSWORD_RESET may proceed (caller
     * re-validates user existence internally while keeping the 200 response).
     */
    @Transactional(readOnly = true)
    public void assertResendAllowed(String email, OtpPurpose purpose) {
        String normalized = AuthService.normalizeEmail(email);
        var latest = challenges.findLatest(normalized, purpose);
        if (latest.isEmpty()) {
            if (purpose == OtpPurpose.REGISTER_VERIFY) {
                throw new OtpException.NoChallenge();
            }
            return;
        }
        long elapsed = Instant.now().getEpochSecond() - latest.get().getCreatedAt().getEpochSecond();
        long remaining = props.getResendCooldownSeconds() - elapsed;
        if (remaining > 0) {
            throw new OtpException.ResendCooldown(remaining);
        }
    }

    /** Extract purpose-specific payload (without the salt entry). */
    public Map<String, String> readPayload(OtpChallenge challenge) {
        try {
            @SuppressWarnings("unchecked")
            Map<String, String> map = objectMapper.readValue(
                    challenge.getPayloadJson() == null ? "{}" : challenge.getPayloadJson(), Map.class);
            map.remove(SALT_KEY);
            return map;
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("OTP payload corrupt", e);
        }
    }

    private String serialize(Map<String, String> extraPayload, String salt) {
        try {
            var map = new java.util.LinkedHashMap<String, String>();
            if (extraPayload != null) map.putAll(extraPayload);
            map.put(SALT_KEY, salt);
            return objectMapper.writeValueAsString(map);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("OTP payload serialization failed", e);
        }
    }

    private String extractSalt(String payloadJson) {
        try {
            @SuppressWarnings("unchecked")
            Map<String, String> map = objectMapper.readValue(
                    payloadJson == null ? "{}" : payloadJson, Map.class);
            String salt = map.get(SALT_KEY);
            return salt == null ? "" : salt;
        } catch (JsonProcessingException e) {
            return "";
        }
    }

    private String generateCode() {
        return String.format("%06d", random.nextInt(1_000_000));
    }

    static String hash(String salt, String code) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(salt.getBytes(StandardCharsets.UTF_8));
            md.update((byte) ':');
            return HexFormat.of().formatHex(md.digest(code.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
