package com.dauviet.collection.domain;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

/**
 * Liên kết chính thức event ↔ dossier (GAME-04 §9): unlock CHỈ sinh qua
 * bảng này — không so khớp tên/tag (QA-16). V1 chỉ một trigger
 * EVENT_COMPLETED; mở rộng qua cột `unlockOn` nếu GAME-05 cần thêm.
 */
@Entity
@Table(name = "event_dossiers")
@IdClass(EventDossier.PK.class)
public class EventDossier {

    /** Composite PK (event_id, dossier_id). */
    public static class PK implements Serializable {
        private UUID eventId;
        private UUID dossierId;

        public PK() {
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof PK other)) return false;
            return Objects.equals(eventId, other.eventId)
                    && Objects.equals(dossierId, other.dossierId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(eventId, dossierId);
        }
    }

    @Id
    @Column(name = "event_id", nullable = false, updatable = false)
    private UUID eventId;

    @Id
    @Column(name = "dossier_id", nullable = false, updatable = false)
    private UUID dossierId;

    @Column(name = "unlock_on", nullable = false, length = 24)
    private String unlockOn = "EVENT_COMPLETED";

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder = 0;

    public EventDossier() {
    }

    public UUID getEventId() { return eventId; }
    public UUID getDossierId() { return dossierId; }
    public String getUnlockOn() { return unlockOn; }
    public Integer getSortOrder() { return sortOrder; }
}
