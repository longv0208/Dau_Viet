package com.dauviet.collection.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.EventCompletionPolicy;

/**
 * Persistence cho event_completion_policies (GAME-04). Lookup policy
 * PUBLISHED — max-one-PUBLISHED enforce bởi partial unique index
 * ux_event_policy_published ở tầng DB. GAME-06 thêm list/version lookup
 * cho admin editor.
 */
public interface EventCompletionPolicyRepository
        extends JpaRepository<EventCompletionPolicy, UUID> {

    /** Policy PUBLISHED duy nhất của event; empty = NOT_CONFIGURED. */
    @Query("select p from EventCompletionPolicy p "
         + "where p.eventId = :eventId and p.status = 'PUBLISHED'")
    Optional<EventCompletionPolicy> findPublishedByEventId(
            @Param("eventId") UUID eventId);

    /** Các policy PUBLISHED của danh sách event. */
    @Query("select p from EventCompletionPolicy p "
         + "where p.eventId in :eventIds and p.status = 'PUBLISHED'")
    List<EventCompletionPolicy> findPublishedByEventIdIn(
            @Param("eventIds") java.util.Collection<UUID> eventIds);

    /** Mọi version của event, mới nhất trước — admin history list. */
    List<EventCompletionPolicy> findByEventIdOrderByPolicyVersionDesc(
            UUID eventId);

    /** Version cao nhất hiện có của event — tính version kế tiếp. */
    @Query("select max(p.policyVersion) from EventCompletionPolicy p "
         + "where p.eventId = :eventId")
    Integer findMaxVersion(@Param("eventId") UUID eventId);

    /** DRAFT đang mở của event (tối đa một theo convention service). */
    @Query("select p from EventCompletionPolicy p "
         + "where p.eventId = :eventId and p.status = 'DRAFT'")
    Optional<EventCompletionPolicy> findDraftByEventId(
            @Param("eventId") UUID eventId);
}
