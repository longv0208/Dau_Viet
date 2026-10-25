package com.dauviet.collection.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Snapshot append-only cua moi lan publish dossier (GAME-06 V28).
 * user_dossier_unlocks.dossier_version pin vao mot row o day — admin co
 * the doi noi dung dossier PUBLISHED ma khong lam mat version learner
 * da mo khoa. Khong update/xoa row sau insert.
 */
@Entity
@Table(name = "historical_dossier_versions")
public class HistoricalDossierVersion {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "dossier_id", nullable = false, updatable = false)
    private UUID dossierId;

    @Column(name = "dossier_version", nullable = false, updatable = false)
    private Integer dossierVersion;

    @Enumerated(EnumType.STRING)
    @Column(name = "dossier_type", nullable = false, length = 16,
            updatable = false)
    private HistoricalDossier.DossierType dossierType;

    @Column(name = "title", nullable = false, updatable = false)
    private String title;

    @Column(name = "summary", columnDefinition = "text", updatable = false)
    private String summary;

    @Column(name = "description", columnDefinition = "text",
            updatable = false)
    private String description;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "source_json", columnDefinition = "jsonb",
            updatable = false)
    private String sourceJson;

    @Column(name = "asset_id", updatable = false)
    private UUID assetId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 16,
            updatable = false)
    private HistoricalDossier.Status status;

    @Column(name = "published_at", nullable = false, updatable = false)
    private Instant publishedAt;

    @Column(name = "published_by", updatable = false)
    private UUID publishedBy;

    public HistoricalDossierVersion() {
    }

    /** Snapshot nguyen trang tu dossier hien tai tai luc publish. */
    public static HistoricalDossierVersion snapshotOf(HistoricalDossier d,
            UUID publishedBy) {
        HistoricalDossierVersion v = new HistoricalDossierVersion();
        v.id = UUID.randomUUID();
        v.dossierId = d.getId();
        v.dossierVersion = d.getDossierVersion();
        v.dossierType = d.getDossierType();
        v.title = d.getTitle();
        v.summary = d.getSummary();
        v.description = d.getDescription();
        v.sourceJson = d.getSourceJson();
        v.assetId = d.getAssetId();
        v.status = d.getStatus();
        v.publishedAt = Instant.now();
        v.publishedBy = publishedBy;
        return v;
    }

    public UUID getId() { return id; }
    public UUID getDossierId() { return dossierId; }
    public Integer getDossierVersion() { return dossierVersion; }
    public HistoricalDossier.DossierType getDossierType() { return dossierType; }
    public String getTitle() { return title; }
    public String getSummary() { return summary; }
    public String getDescription() { return description; }
    public String getSourceJson() { return sourceJson; }
    public UUID getAssetId() { return assetId; }
    public HistoricalDossier.Status getStatus() { return status; }
    public Instant getPublishedAt() { return publishedAt; }
    public UUID getPublishedBy() { return publishedBy; }
}
