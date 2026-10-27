package com.dauviet.path.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "learning_path_lesson_nodes")
public class LearningPathLessonNode {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "event_node_id", nullable = false)
    private UUID eventNodeId;

    @Column(name = "event_id", nullable = false)
    private UUID eventId;

    @Column(name = "lesson_id", nullable = false)
    private UUID lessonId;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected LearningPathLessonNode() {}

    public LearningPathLessonNode(UUID id, UUID eventNodeId, UUID eventId,
                                  UUID lessonId, int sortOrder) {
        this.id = id != null ? id : UUID.randomUUID();
        this.eventNodeId = eventNodeId;
        this.eventId = eventId;
        this.lessonId = lessonId;
        this.sortOrder = sortOrder;
        this.createdAt = Instant.now();
    }

    public UUID getId() { return id; }
    public UUID getEventNodeId() { return eventNodeId; }
    public UUID getEventId() { return eventId; }
    public UUID getLessonId() { return lessonId; }
    public int getSortOrder() { return sortOrder; }
    public Instant getCreatedAt() { return createdAt; }
    public void setSortOrder(int value) { sortOrder = value; }
}
