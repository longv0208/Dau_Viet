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
@Table(name = "map_location_events")
public class MapLocationEvent {

    @Embeddable
    public static class Id implements Serializable {
        @Column(name = "location_id", nullable = false)
        private UUID locationId;

        @Column(name = "event_id", nullable = false)
        private UUID eventId;

        protected Id() {}

        public Id(UUID locationId, UUID eventId) {
            this.locationId = locationId;
            this.eventId = eventId;
        }

        public UUID getLocationId() { return locationId; }
        public UUID getEventId() { return eventId; }

        @Override
        public boolean equals(Object o) {
            return o instanceof Id other
                    && Objects.equals(locationId, other.locationId)
                    && Objects.equals(eventId, other.eventId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(locationId, eventId);
        }
    }

    @EmbeddedId
    private Id id;

    @Column(name = "role", nullable = false, length = 24)
    private String role = "PRIMARY";

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    protected MapLocationEvent() {}

    public MapLocationEvent(UUID locationId, UUID eventId, String role, int sortOrder) {
        this.id = new Id(locationId, eventId);
        this.role = (role == null || role.isBlank()) ? "PRIMARY" : role.trim().toUpperCase();
        this.sortOrder = sortOrder;
    }

    public Id getId() { return id; }
    public UUID getLocationId() { return id.getLocationId(); }
    public UUID getEventId() { return id.getEventId(); }
    public String getRole() { return role; }
    public int getSortOrder() { return sortOrder; }
}
