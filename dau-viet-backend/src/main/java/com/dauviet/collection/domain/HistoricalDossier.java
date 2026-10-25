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
import jakarta.persistence.Version;

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

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /**
     * Optimistic-lock column them o V28 — admin PUT gui expectedRowVersion
     * de chan two-tab overwrite. Khong expose len learner DTO.
     */
    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public HistoricalDossier() {
    }

    /**
     * Tao DRAFT moi (GAME-06). canonicalCode set mot lan — updatable=false
     * + UNIQUE giu la khóa dedup toan cuc.
     */
    public static HistoricalDossier draft(String canonicalCode,
            DossierType type, String title, String summary,
            String description, String sourceJson, UUID assetId,
            UUID createdBy) {
        HistoricalDossier d = new HistoricalDossier();
        d.id = UUID.randomUUID();
        d.canonicalCode = canonicalCode;
        d.dossierType = type;
        d.title = title;
        d.summary = summary;
        d.description = description;
        d.sourceJson = sourceJson;
        d.assetId = assetId;
        d.status = Status.DRAFT;
        d.dossierVersion = 1;
        d.createdBy = createdBy;
        return d;
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
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getRowVersion() { return rowVersion; }
    public UUID getCreatedBy() { return createdBy; }

    /* ---- mutable fields (admin edit; publish khong thu hoi unlock cu) ---- */

    public void setDossierType(DossierType t) { this.dossierType = t; }
    public void setTitle(String title) { this.title = title; }
    public void setSummary(String summary) { this.summary = summary; }
    public void setDescription(String description) {
        this.description = description;
    }
    public void setSourceJson(String sourceJson) {
        this.sourceJson = sourceJson;
    }
    public void setAssetId(UUID assetId) { this.assetId = assetId; }
    public void setStatus(Status status) { this.status = status; }
    public void setDossierVersion(Integer v) { this.dossierVersion = v; }
    public void setCreatedBy(UUID createdBy) { this.createdBy = createdBy; }
}
