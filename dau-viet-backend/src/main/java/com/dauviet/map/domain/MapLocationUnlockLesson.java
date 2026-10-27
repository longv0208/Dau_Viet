package com.dauviet.map.domain;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "map_location_unlock_lessons")
public class MapLocationUnlockLesson {

    @Embeddable
    public static class Id implements Serializable {
        @Column(name = "location_id", nullable = false)
        private UUID locationId;

        @Column(name = "lesson_id", nullable = false)
        private UUID lessonId;

        protected Id() {}

        public Id(UUID locationId, UUID lessonId) {
            this.locationId = locationId;
            this.lessonId = lessonId;
        }

        public UUID getLocationId() { return locationId; }
        public UUID getLessonId() { return lessonId; }

        @Override
        public boolean equals(Object o) {
            return o instanceof Id other
                    && Objects.equals(locationId, other.locationId)
                    && Objects.equals(lessonId, other.lessonId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(locationId, lessonId);
        }
    }

    @EmbeddedId
    private Id id;

    protected MapLocationUnlockLesson() {}

    public MapLocationUnlockLesson(UUID locationId, UUID lessonId) {
        this.id = new Id(locationId, lessonId);
    }

    public Id getId() { return id; }
    public UUID getLocationId() { return id.getLocationId(); }
    public UUID getLessonId() { return id.getLessonId(); }
}
