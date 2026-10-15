package com.dauviet.lesson.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Stored binary asset (image/document) referenced by evidence and
 * activity config. Read-only in TASK-0009 — no upload endpoints yet.
 */
@Entity
@Table(name = "assets")
public class Asset {

    @Id
    private UUID id;

    @Column(name = "storage_key", nullable = false, unique = true)
    private String storageKey;

    @Column(name = "original_filename")
    private String originalFilename;

    @Column(name = "mime_type", nullable = false)
    private String mimeType;

    @Column(name = "size_bytes", nullable = false)
    private Long sizeBytes;

    /** DB column is CHAR(64) — map with the CHAR jdbc type to pass schema validation. */
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "checksum_sha256", length = 64)
    private String checksumSha256;

    /** UPLOADING | ACTIVE | RETIRED | FAILED. */
    @Column(nullable = false)
    private String state = "UPLOADING";

    @Column(name = "alt_text")
    private String altText;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    @Column(name = "retired_at")
    private Instant retiredAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public String getStorageKey() { return storageKey; }
    public void setStorageKey(String storageKey) { this.storageKey = storageKey; }
    public String getOriginalFilename() { return originalFilename; }
    public void setOriginalFilename(String n) { this.originalFilename = n; }
    public String getMimeType() { return mimeType; }
    public void setMimeType(String mimeType) { this.mimeType = mimeType; }
    public Long getSizeBytes() { return sizeBytes; }
    public void setSizeBytes(Long sizeBytes) { this.sizeBytes = sizeBytes; }
    public String getChecksumSha256() { return checksumSha256; }
    public void setChecksumSha256(String c) { this.checksumSha256 = c; }
    public String getState() { return state; }
    public void setState(String state) { this.state = state; }
    public String getAltText() { return altText; }
    public void setAltText(String altText) { this.altText = altText; }
    public Instant getCreatedAt() { return createdAt; }
    public UUID getCreatedBy() { return createdBy; }
    public void setCreatedBy(UUID createdBy) { this.createdBy = createdBy; }
    public Instant getRetiredAt() { return retiredAt; }
    public void setRetiredAt(Instant retiredAt) { this.retiredAt = retiredAt; }
}
