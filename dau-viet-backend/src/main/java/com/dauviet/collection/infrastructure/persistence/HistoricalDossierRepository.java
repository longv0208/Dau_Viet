package com.dauviet.collection.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.HistoricalDossier;

/**
 * Persistence cho historical_dossiers. Catalog read-side cho learner;
 * admin CMS (GAME-06) them search + canonical lookup + lock publish.
 */
public interface HistoricalDossierRepository
        extends JpaRepository<HistoricalDossier, UUID>,
        JpaSpecificationExecutor<HistoricalDossier> {

    /** Batch lookup dossiers theo id — tranh N+1 khi map list. */
    List<HistoricalDossier> findAllByIdIn(Set<UUID> ids);

    /** Dedup check + resolve canonical khi admin tao/sua. */
    Optional<HistoricalDossier> findByCanonicalCode(String canonicalCode);

    /**
     * Pessimistic write lock tren dossier row — serialize hai admin
     * publish cung luc de dossier_version khong race.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select d from HistoricalDossier d where d.id = :id")
    Optional<HistoricalDossier> findForUpdate(@Param("id") UUID id);
}
