package com.dauviet.learning.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;

import org.springframework.stereotype.Service;

import com.dauviet.learning.domain.IdempotencyConflictException;
import com.dauviet.learning.domain.IdempotencyRecord;
import com.dauviet.learning.infrastructure.persistence.IdempotencyRecordRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Persistent Idempotency-Key handling on idempotency_records — the table,
 * not memory, is the correctness mechanism (brief §3).
 *
 * Semantics: scoped to (user, operation, key); `operation` is a constant
 * per endpoint (SUBMIT_ACTIVITY / COMPLETE_ATTEMPT) and the caller embeds
 * attempt/activity context in `payloadFingerprint` so a key can never
 * replay across attempts or activities.
 * A claimed record with a NULL response means a request is in-flight — a
 * concurrent duplicate blocks on the attempt's pessimistic row lock and then
 * sees the finished response, so double-writes cannot occur.
 *
 * Replay vs conflict: same key + same request_hash -> return the stored
 * response verbatim; same key + different hash -> IdempotencyConflictException
 * (409 IDEMPOTENCY_CONFLICT). Expired records (expires_at past) are treated
 * as absent and reclaimed; retention is 7 days (IdempotencyRecord.claim).
 *
 * All work happens inside the caller's transaction: the record, the
 * activity_attempts row, the attempt state and the stored response commit
 * or roll back together.
 */
@Service
public class IdempotencyService {

    private final IdempotencyRecordRepository records;
    private final ObjectMapper mapper;
    private final ObjectMapper canonicalMapper;
    private final long ttlSeconds;

    public IdempotencyService(IdempotencyRecordRepository records,
                              ObjectMapper mapper,
                              @org.springframework.beans.factory.annotation.Value(
                                      "${app.learning.idempotency-ttl:86400}")
                              long ttlSeconds) {
        this.records = records;
        this.mapper = mapper;
        this.ttlSeconds = ttlSeconds;
        this.canonicalMapper = mapper.copy()
                .configure(com.fasterxml.jackson.databind.SerializationFeature
                        .ORDER_MAP_ENTRIES_BY_KEYS, true)
                .configure(com.fasterxml.jackson.databind.MapperFeature
                        .SORT_PROPERTIES_ALPHABETICALLY, true);
    }

    /**
     * Execute `operation` once per (userId, operation, key). Returns the
     * stored response on replay instead of re-running `executor`.
     *
     * @param payloadFingerprint stable fingerprint input of the request
     *        (e.g. attemptId + activityId + canonical answer JSON)
     * @param executor produces the response DTO on first execution
     * @param responseType DTO class used to re-read the stored response
     */
    public <T> T execute(UUID userId, String operation, String key,
                         String payloadFingerprint,
                         Supplier<T> executor, Class<T> responseType) {
        if (key == null || key.isBlank()) {
            return executor.get();
        }
        if (key.length() > 160) {
            // idempotency_records.idempotency_key is VARCHAR(160) — reject
            // early instead of surfacing a constraint-violation 500.
            throw new IdempotencyConflictException(
                    "idempotency key exceeds 160 characters");
        }
        String hash = fingerprint(payloadFingerprint);
        Optional<IdempotencyRecord> existing =
                records.findByUserIdAndOperationAndIdempotencyKey(
                        userId, operation, key);
        if (existing.isPresent()) {
            IdempotencyRecord rec = existing.get();
            if (rec.getExpiresAt() != null
                    && rec.getExpiresAt().isBefore(Instant.now())) {
                records.delete(rec);
                records.flush();
            } else {
                if (!rec.getRequestHash().equals(hash)) {
                    throw new IdempotencyConflictException(
                            "idempotency key reused with a different payload: " + key);
                }
                if (rec.getResponseJson() == null) {
                    // Claimed by an in-flight request that has not finished —
                    // cannot happen under the attempt row lock; treat as
                    // conflict rather than executing twice.
                    throw new IdempotencyConflictException(
                            "idempotency key is being processed concurrently: " + key);
                }
                return readStored(rec.getResponseJson(), responseType);
            }
        }

        IdempotencyRecord rec = IdempotencyRecord.claim(
                userId, operation, key, hash, ttlSeconds);
        try {
            records.saveAndFlush(rec);
        } catch (org.springframework.dao.DataIntegrityViolationException dup) {
            // Cross-attempt same-key claim race: another tx already holds
            // (user, operation, key) — the lock-ordering guarantee only covers
            // same-attempt duplicates, so surface the contract conflict.
            throw new IdempotencyConflictException(
                    "idempotency key already claimed: " + key);
        }
        T response = executor.get();
        rec.storeResponse(writeJson(response), 200);
        records.save(rec);
        return response;
    }

    /** SHA-256 of the payload fingerprint — stable across retries. */
    public String fingerprint(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    /** Canonical JSON string for fingerprinting (sorted fields at every level). */
    public String canonical(JsonNode node) {
        if (node == null || node.isNull()) return "null";
        try {
            return canonicalMapper.writeValueAsString(
                    mapper.treeToValue(node, Object.class));
        } catch (Exception e) {
            return node.toString();
        }
    }

    private String writeJson(Object response) {
        try {
            return mapper.writeValueAsString(response);
        } catch (Exception e) {
            throw new IllegalStateException("cannot serialize idempotent response", e);
        }
    }

    private <T> T readStored(String json, Class<T> type) {
        try {
            return mapper.readValue(json, type);
        } catch (Exception e) {
            throw new IllegalStateException("stored idempotent response unreadable", e);
        }
    }
}
