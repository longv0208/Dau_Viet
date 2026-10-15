package com.dauviet.learning.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Persistent idempotency record (idempotency_records). Scoped to
 * (user_id, operation, idempotency_key) via the DB UNIQUE constraint; the
 * operation string embeds the attempt context so the same key on a
 * different attempt/activity never collides or replays across scopes.
 * request_hash fingerprints the payload — a reused key with a different
 * payload is a 409 conflict, never a silent replay.
 */
@Entity
@Table(name = "idempotency_records")
public class IdempotencyRecord {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "idempotency_key", nullable = false, updatable = false, length = 160)
    private String idempotencyKey;

    @Column(name = "operation", nullable = false, updatable = false, length = 100)
    private String operation;

    @Column(name = "request_hash", nullable = false, updatable = false, length = 128)
    private String requestHash;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "response_json", columnDefinition = "jsonb")
    private String responseJson;

    @Column(name = "http_status")
    private Integer httpStatus;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "expires_at")
    private Instant expiresAt;

    public IdempotencyRecord() {
    }

    /** A claimed key whose response has not been persisted yet (in-flight). */
    public static IdempotencyRecord claim(UUID userId, String operation,
                                        String key, String requestHash,
                                        long ttlSeconds) {
        IdempotencyRecord r = new IdempotencyRecord();
        r.id = UUID.randomUUID();
        r.userId = userId;
        r.operation = operation;
        r.idempotencyKey = key;
        r.requestHash = requestHash;
        r.createdAt = Instant.now();
        // Retention: expired keys are treated as absent (new execution
        // allowed); the record may be reclaimed by a later request.
        r.expiresAt = r.createdAt.plusSeconds(ttlSeconds);
        return r;
    }

    public void storeResponse(String responseJson, int httpStatus) {
        this.responseJson = responseJson;
        this.httpStatus = httpStatus;
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public String getIdempotencyKey() { return idempotencyKey; }
    public String getOperation() { return operation; }
    public String getRequestHash() { return requestHash; }
    public String getResponseJson() { return responseJson; }
    public Integer getHttpStatus() { return httpStatus; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getExpiresAt() { return expiresAt; }
}
