package com.dauviet.collection.application;

import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;

/**
 * Lookup policy hoàn thành sự kiện (GAME-04). Không cache trong JVM —
 * republish policy phải hiệu lực ngay (admin flow); truy vấn đơn giản
 * trên partial unique index.
 */
@Service
public class EventCompletionPolicyService {

    private final EventCompletionPolicyRepository policies;

    public EventCompletionPolicyService(EventCompletionPolicyRepository policies) {
        this.policies = policies;
    }

    /**
     * Policy PUBLISHED của event; empty = NOT_CONFIGURED (EVT-07 — không
     * suy "1 lesson = event done").
     */
    @Transactional(readOnly = true)
    public Optional<EventCompletionPolicy> publishedPolicyOf(UUID eventId) {
        return policies.findPublishedByEventId(eventId);
    }
}
