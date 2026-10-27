package com.dauviet.historicalevent.domain;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
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
 * A historical event (e.g. Bạch Đằng 938) — knowledge metadata only.
 * Lessons referencing this event live in a separate `lessons` table
 * (future migration); this entity deliberately has no lesson coupling.
 */
@Entity
@Table(name = "historical_events")
public class HistoricalEvent {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    /** URL-friendly unique key (e.g. "bach-dang-938"); stable across environments. */
    @Column(name = "slug", nullable = false, unique = true, length = 150)
    private String slug;

    @Column(name = "title", nullable = false)
    private String title;

    /** Canonical era bucket (e.g. "Thời Ngô - Đinh - Tiền Lê (938 - 1009)"). */
    @Column(name = "era", length = 100)
    private String era;

    /** Free-text period label (e.g. "Mùa Đông 938 SCN") shown to learners. */
    @Column(name = "period", length = 100)
    private String period;

    @Column(name = "start_year")
    private Integer startYear;

    @Column(name = "end_year")
    private Integer endYear;

    @Column(name = "date_precision", nullable = false, length = 16)
    private String datePrecision = "EXACT";

    @Column(name = "summary", nullable = false, columnDefinition = "text")
    private String summary;

    @Column(name = "description", columnDefinition = "text")
    private String description;

    @Column(name = "location")
    private String location;

    /**
     * Logical key into object storage (e.g. "events/bach-dang-938/hero.jpg").
     * Deliberately not an FK — the `assets` table arrives in a later migration
     * and can backfill from this key without breaking reads.
     */
    @Column(name = "cover_asset_key", length = 512)
    private String coverAssetKey;

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "tags", columnDefinition = "text[]", nullable = false)
    private List<String> tags = new ArrayList<>();

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 24)
    private EventStatus status = EventStatus.DRAFT;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** Optimistic-lock column added by V5; never expose to public DTOs. */
    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public HistoricalEvent() {
        // JPA + seed/factory use; always assign id via setId before persisting.
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getSlug() { return slug; }
    public void setSlug(String slug) { this.slug = slug; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getEra() { return era; }
    public void setEra(String era) { this.era = era; }

    public String getPeriod() { return period; }
    public void setPeriod(String period) { this.period = period; }

    public Integer getStartYear() { return startYear; }
    public void setStartYear(Integer startYear) { this.startYear = startYear; }

    public Integer getEndYear() { return endYear; }
    public void setEndYear(Integer endYear) { this.endYear = endYear; }

    public String getDatePrecision() { return datePrecision != null ? datePrecision : "EXACT"; }
    public void setDatePrecision(String datePrecision) {
        this.datePrecision = (datePrecision == null || datePrecision.isBlank()) ? "EXACT" : datePrecision;
    }

    public String getSummary() { return summary; }
    public void setSummary(String summary) { this.summary = summary; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public String getCoverAssetKey() { return coverAssetKey; }
    public void setCoverAssetKey(String coverAssetKey) { this.coverAssetKey = coverAssetKey; }

    public List<String> getTags() { return tags; }
    public void setTags(List<String> tags) { this.tags = tags == null ? new ArrayList<>() : tags; }

    public EventStatus getStatus() { return status; }
    public void setStatus(EventStatus status) { this.status = status; }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getRowVersion() { return rowVersion; }
}
