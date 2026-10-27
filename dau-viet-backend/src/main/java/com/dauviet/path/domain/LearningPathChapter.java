package com.dauviet.path.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "learning_path_chapters")
public class LearningPathChapter {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "path_version_id", nullable = false)
    private UUID pathVersionId;

    @Column(name = "code", nullable = false, length = 64)
    private String code;

    @Column(name = "title", nullable = false, length = 255)
    private String title;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "start_year", nullable = false)
    private int startYear;

    @Column(name = "end_year", nullable = false)
    private int endYear;

    @Column(name = "period_label", nullable = false, length = 120)
    private String periodLabel;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "theme_key", nullable = false, length = 64)
    private String themeKey;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected LearningPathChapter() {}

    public LearningPathChapter(UUID id, UUID pathVersionId, String code, String title,
                               String description, int startYear, int endYear,
                               String periodLabel, int sortOrder, String themeKey) {
        this.id = id != null ? id : UUID.randomUUID();
        this.pathVersionId = pathVersionId;
        this.code = code;
        this.title = title;
        this.description = description;
        this.startYear = startYear;
        this.endYear = endYear;
        this.periodLabel = periodLabel;
        this.sortOrder = sortOrder;
        this.themeKey = themeKey;
        this.createdAt = Instant.now();
    }

    public UUID getId() { return id; }
    public UUID getPathVersionId() { return pathVersionId; }
    public String getCode() { return code; }
    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public int getStartYear() { return startYear; }
    public int getEndYear() { return endYear; }
    public String getPeriodLabel() { return periodLabel; }
    public int getSortOrder() { return sortOrder; }
    public String getThemeKey() { return themeKey; }
    public Instant getCreatedAt() { return createdAt; }

    public void setSortOrder(int sortOrder) { this.sortOrder = sortOrder; }

    public void update(String code, String title, String description, int startYear,
                       int endYear, String periodLabel, String themeKey) {
        this.code = code;
        this.title = title;
        this.description = description;
        this.startYear = startYear;
        this.endYear = endYear;
        this.periodLabel = periodLabel;
        this.themeKey = themeKey;
    }
}
