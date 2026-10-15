package com.dauviet.historicalevent.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;

@Repository
public interface HistoricalEventRepository
        extends JpaRepository<HistoricalEvent, UUID>, JpaSpecificationExecutor<HistoricalEvent> {

    Page<HistoricalEvent> findByStatus(EventStatus status, Pageable pageable);

    Optional<HistoricalEvent> findByIdAndStatus(UUID id, EventStatus status);

    Optional<HistoricalEvent> findBySlug(String slug);
}
