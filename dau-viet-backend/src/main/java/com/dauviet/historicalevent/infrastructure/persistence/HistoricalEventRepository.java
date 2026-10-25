package com.dauviet.historicalevent.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;

@Repository
public interface HistoricalEventRepository
        extends JpaRepository<HistoricalEvent, UUID>, JpaSpecificationExecutor<HistoricalEvent> {

    Page<HistoricalEvent> findByStatus(EventStatus status, Pageable pageable);

    Optional<HistoricalEvent> findByIdAndStatus(UUID id, EventStatus status);

    Optional<HistoricalEvent> findBySlug(String slug);

    /**
     * Pessimistic write lock trên event row — serialize hai admin publish
     * policy cùng lúc (GAME-06). Lock theo event vì partial unique index
     * ux_event_policy_published chỉ bắt tại commit.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from HistoricalEvent e where e.id = :id")
    Optional<HistoricalEvent> findForUpdate(@Param("id") UUID id);
}
