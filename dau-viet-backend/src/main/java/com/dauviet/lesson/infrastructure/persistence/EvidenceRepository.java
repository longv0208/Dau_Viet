package com.dauviet.lesson.infrastructure.persistence;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.lesson.domain.Evidence;
import com.dauviet.lesson.domain.EvidenceStatus;

public interface EvidenceRepository
        extends JpaRepository<Evidence, UUID>, JpaSpecificationExecutor<Evidence> {

    /** Ids of evidences attached to an event and usable in a published draft. */
    @Query("select e.id from Evidence e where e.eventId = :eventId and e.status in :statuses")
    List<UUID> findIdsByEventIdAndStatusIn(@Param("eventId") UUID eventId,
                                         @Param("statuses") Collection<EvidenceStatus> statuses);

    boolean existsByIdAndEventIdAndStatusIn(UUID id, UUID eventId,
                                            Collection<EvidenceStatus> statuses);

    /**
     * Is this evidence referenced inside any published lesson snapshot?
     * Conservative LIKE scan on snapshot_json::text — admin-side only.
     */
    @Query(value = """
            select count(*) > 0 from lesson_versions lv
            join lessons l on l.current_version_id = lv.id and l.id = lv.lesson_id
            where lv.snapshot_json::text like concat('%', cast(:evidenceId as text), '%')
            """, nativeQuery = true)
    boolean referencedByPublishedSnapshot(@Param("evidenceId") String evidenceId);

    /**
     * Lesson ids whose current published snapshot mentions this evidence.
     * Used to surface `details.lessonIds` on EVIDENCE_IN_USE errors.
     */
    @Query(value = """
            select lv.lesson_id from lesson_versions lv
            join lessons l on l.current_version_id = lv.id and l.id = lv.lesson_id
            where lv.snapshot_json::text like concat('%', cast(:evidenceId as text), '%')
            """, nativeQuery = true)
    List<java.util.UUID> lessonIdsReferencing(@Param("evidenceId") String evidenceId);

    /** All evidence ids referenced anywhere in the given set (for diagnostics). */
    @Query("select e.id from Evidence e where e.id in :ids")
    List<UUID> findExistingIds(@Param("ids") Collection<UUID> ids);
}
