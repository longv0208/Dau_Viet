package com.dauviet.collection.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.EventCompletionPolicy;

/**
 * Persistence cho event_completion_policies (GAME-04). Chỉ cần lookup
 * policy PUBLISHED — max-one-PUBLISHED được enforce bởi partial unique
 * index ux_event_policy_published ở tầng DB.
 */
public interface EventCompletionPolicyRepository
        extends JpaRepository<EventCompletionPolicy, UUID> {

    /** Policy PUBLISHED duy nhất của event; empty = NOT_CONFIGURED. */
    @Query("select p from EventCompletionPolicy p "
         + "where p.eventId = :eventId and p.status = 'PUBLISHED'")
    Optional<EventCompletionPolicy> findPublishedByEventId(
            @Param("eventId") UUID eventId);
}
