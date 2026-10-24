package com.dauviet.collection.domain;

import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

/**
 * Quyền mở hồ sơ của learner (GAME-04): unique theo canonical dossier
 * (user, dossier) — một nhân vật mở qua nhiều event vẫn chỉ một quyền sở
 * hữu. `eventId` + `dossierVersion` giữ provenance lần mở đầu (ITEM-03);
 * `grantedAt` giữ lần đầu, insert sau ON CONFLICT DO NOTHING không đè.
 */
@Entity
@Table(name = "user_dossier_unlocks")
@IdClass(UserDossierUnlock.PK.class)
public class UserDossierUnlock {

    /** Composite PK (user_id, dossier_id). */
    public static class PK implements Serializable {
        private UUID userId;
        private UUID dossierId;

        public PK() {
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof PK other)) return false;
            return Objects.equals(userId, other.userId)
                    && Objects.equals(dossierId, other.dossierId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, dossierId);
        }
    }

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Id
    @Column(name = "dossier_id", nullable = false, updatable = false)
    private UUID dossierId;

    @Column(name = "event_id", nullable = false, updatable = false)
    private UUID eventId;

    @Column(name = "dossier_version", nullable = false, updatable = false)
    private Integer dossierVersion;

    @Column(name = "granted_at", nullable = false, updatable = false)
    private Instant grantedAt;

    public UserDossierUnlock() {
    }

    public UUID getUserId() { return userId; }
    public UUID getDossierId() { return dossierId; }
    public UUID getEventId() { return eventId; }
    public Integer getDossierVersion() { return dossierVersion; }
    public Instant getGrantedAt() { return grantedAt; }
}
