package com.dauviet.collection.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Hồ sơ lịch sử canonical (GAME-04 Lớp B): nhân vật/địa điểm/hiện vật/bối
 * cảnh do admin tạo + publish kiểm duyệt nguồn. `canonicalCode` là khóa
 * dedup toàn cục ('ngo-quyen', 'song-bach-dang'…) — một nhân vật gắn nhiều
 * sự kiện vẫn chỉ một dossier. `sourceJson` giữ citation; archive dossier
 * không mất nội dung learner đã mở.
 */
@Entity
@Table(name = "historical_dossiers")
public class HistoricalDossier {

    public enum DossierType { PERSON, LOCATION, ARTIFACT, CONTEXT }
    public enum Status { DRAFT, PUBLISHED, ARCHIVED }

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "canonical_code", nullable = false, unique = true,
            length = 120, updatable = false)
    private String canonicalCode;

    @Enumerated(EnumType.STRING)
    @Column(name = "dossier_type", nullable = false, length = 16)
    private DossierType dossierType;

    @Column(name = "title", nullable = false)
    private String title;

    @Column(name = "summary", columnDefinition = "text")
    private String summary;

    @Column(name = "description", columnDefinition = "text")
    private String description;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "source_json", columnDefinition = "jsonb")
    private String sourceJson;

    @Column(name = "asset_id")
    private UUID assetId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 16)
    private Status status = Status.DRAFT;

    @Column(name = "dossier_version", nullable = false)
    private Integer dossierVersion = 1;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public HistoricalDossier() {
    }

    public UUID getId() { return id; }
    public String getCanonicalCode() { return canonicalCode; }
    public DossierType getDossierType() { return dossierType; }
    public String getTitle() { return title; }
    public String getSummary() { return summary; }
    public String getDescription() { return description; }
    public String getSourceJson() { return sourceJson; }
    public UUID getAssetId() { return assetId; }
    public Status getStatus() { return status; }
    public Integer getDossierVersion() { return dossierVersion; }
    public Instant getCreatedAt() { return createdAt; }
}
