package com.dauviet.lesson.domain;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Source-backed evidence attached to a historical event.
 * Bound to an event_id (required) and optionally an asset_id.
 * Never hard-deleted; ARCHIVED is the terminal state. References from
 * lesson drafts/snapshots are validated by the lesson authoring layer.
 */
@Entity
@Table(name = "evidences")
public class Evidence {

    @Id
    private UUID id;

    @Column(name = "event_id", nullable = false, updatable = false)
    private UUID eventId;

    @Column(nullable = false)
    private String title;

    @Column(name = "evidence_type", nullable = false)
    private String evidenceType;

    private String description;

    @Column(name = "source_title", nullable = false)
    private String sourceTitle;

    @Column(name = "source_author")
    private String sourceAuthor;

    @Column(name = "source_url")
    private String sourceUrl;

    @Column(name = "source_citation")
    private String sourceCitation;

    @Column(name = "source_published_at")
    private LocalDate sourcePublishedAt;

    /** HIGH | MEDIUM | LOW | UNASSESSED | null — matches chk_evidence_reliability. */
    private String reliability;

    private String relevance;

    @Column(name = "asset_id")
    private UUID assetId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EvidenceStatus status = EvidenceStatus.DRAFT;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public UUID getEventId() { return eventId; }
    public void setEventId(UUID eventId) { this.eventId = eventId; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getEvidenceType() { return evidenceType; }
    public void setEvidenceType(String evidenceType) { this.evidenceType = evidenceType; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getSourceTitle() { return sourceTitle; }
    public void setSourceTitle(String sourceTitle) { this.sourceTitle = sourceTitle; }
    public String getSourceAuthor() { return sourceAuthor; }
    public void setSourceAuthor(String sourceAuthor) { this.sourceAuthor = sourceAuthor; }
    public String getSourceUrl() { return sourceUrl; }
    public void setSourceUrl(String sourceUrl) { this.sourceUrl = sourceUrl; }
    public String getSourceCitation() { return sourceCitation; }
    public void setSourceCitation(String sourceCitation) { this.sourceCitation = sourceCitation; }
    public LocalDate getSourcePublishedAt() { return sourcePublishedAt; }
    public void setSourcePublishedAt(LocalDate d) { this.sourcePublishedAt = d; }
    public String getReliability() { return reliability; }
    public void setReliability(String reliability) { this.reliability = reliability; }
    public String getRelevance() { return relevance; }
    public void setRelevance(String relevance) { this.relevance = relevance; }
    public UUID getAssetId() { return assetId; }
    public void setAssetId(UUID assetId) { this.assetId = assetId; }
    public EvidenceStatus getStatus() { return status; }
    public void setStatus(EvidenceStatus status) { this.status = status; }
    public UUID getCreatedBy() { return createdBy; }
    public void setCreatedBy(UUID createdBy) { this.createdBy = createdBy; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getRowVersion() { return rowVersion; }
}
