package com.dauviet.path.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "learning_path_event_nodes")
public class LearningPathEventNode {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "chapter_id", nullable = false)
    private UUID chapterId;

    @Column(name = "path_version_id", nullable = false)
    private UUID pathVersionId;

    @Column(name = "event_id", nullable = false)
    private UUID eventId;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Enumerated(EnumType.STRING)
    @Column(name = "participation_type", nullable = false, length = 24)
    private ParticipationType participationType = ParticipationType.EXPLORATION_ONLY;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected LearningPathEventNode() {}

    public LearningPathEventNode(UUID id, UUID chapterId, UUID pathVersionId,
                                 UUID eventId, int sortOrder) {
        this.id = id != null ? id : UUID.randomUUID();
        this.chapterId = chapterId;
        this.pathVersionId = pathVersionId;
        this.eventId = eventId;
        this.sortOrder = sortOrder;
        this.createdAt = Instant.now();
    }

    public UUID getId() { return id; }
    public UUID getChapterId() { return chapterId; }
    public UUID getPathVersionId() { return pathVersionId; }
    public UUID getEventId() { return eventId; }
    public int getSortOrder() { return sortOrder; }
    public Instant getCreatedAt() { return createdAt; }
    public ParticipationType getParticipationType() { return participationType; }
    public void setParticipationType(ParticipationType value) { participationType = value; }
    public void setSortOrder(int value) { sortOrder = value; }
    public void moveToChapter(UUID value) { chapterId = value; }
}
