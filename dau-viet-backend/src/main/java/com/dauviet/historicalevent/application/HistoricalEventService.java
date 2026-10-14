package com.dauviet.historicalevent.application;

import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.api.dto.HistoricalEventDetailDto;
import com.dauviet.historicalevent.api.dto.HistoricalEventSummaryDto;
import com.dauviet.historicalevent.api.mapper.HistoricalEventMapper;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;

/**
 * Read-only application service for learner-facing event APIs.
 * Business rule: learners only see PUBLISHED events; anything else is 404
 * (no existence leak between DRAFT and missing resources).
 */
@Service
public class HistoricalEventService {

    private final HistoricalEventRepository repository;
    private final HistoricalEventMapper mapper;

    public HistoricalEventService(HistoricalEventRepository repository,
                                  HistoricalEventMapper mapper) {
        this.repository = repository;
        this.mapper = mapper;
    }

    @Transactional(readOnly = true)
    public Page<HistoricalEventSummaryDto> listPublished(Pageable pageable) {
        return repository.findByStatus(EventStatus.PUBLISHED, pageable)
                .map(mapper::toSummaryDto);
    }

    @Transactional(readOnly = true)
    public HistoricalEventDetailDto getPublishedById(UUID id) {
        return repository.findByIdAndStatus(id, EventStatus.PUBLISHED)
                .map(mapper::toDetailDto)
                .orElseThrow(() -> new ResourceNotFoundException("Historical event not found"));
    }
}
