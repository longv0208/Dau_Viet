package com.dauviet.path.application;

import java.util.List;
import java.util.UUID;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Component;
import com.dauviet.path.domain.*;
import com.dauviet.path.domain.LearningPathExceptions.*;
import com.dauviet.path.infrastructure.persistence.*;
import jakarta.persistence.EntityManager;

/** Draft row locks serialize changes; the revision rejects stale client edits. */
@Component
public class AdminPathAccess {
    private final LearningPathVersionRepository versions;
    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository events;
    private final EntityManager em;

    public AdminPathAccess(LearningPathVersionRepository versions, LearningPathChapterRepository chapters,
                           LearningPathEventNodeRepository events, EntityManager em) {
        this.versions = versions;
        this.chapters = chapters;
        this.events = events;
        this.em = em;
    }

    public LearningPathVersion version(UUID id) {
        return versions.findById(id).orElseThrow(() -> new PathNotFoundException(id.toString()));
    }

    public LearningPathVersion draft(UUID id, Long expectedRevision) {
        LearningPathVersion v = versions.findLockedById(id)
                .orElseThrow(() -> new PathNotFoundException(id.toString()));
        em.refresh(v, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        require(v.getStatus() == LearningPathStatus.DRAFT, "Only DRAFT learning paths can be changed");
        if (expectedRevision == null || expectedRevision != v.getRevision()) {
            throw new OptimisticLockingFailureException("Learning path revision changed; reload and retry");
        }
        v.bumpRevision();
        return v;
    }

    public LearningPathChapter chapter(UUID versionId, UUID id) {
        LearningPathChapter c = chapters.findById(id)
                .orElseThrow(() -> new PathNotFoundException("chapter " + id));
        require(versionId.equals(c.getPathVersionId()), "Chapter belongs to another version");
        return c;
    }

    public LearningPathEventNode event(UUID versionId, UUID id) {
        LearningPathEventNode e = events.findById(id)
                .orElseThrow(() -> new PathNotFoundException("event node " + id));
        require(versionId.equals(e.getPathVersionId()), "Event node belongs to another version");
        return e;
    }

    public void lockPath(String pathCode) {
        em.createNativeQuery("select pg_advisory_xact_lock(hashtextextended(cast(:code as text), 0))")
                .setParameter("code", pathCode).getSingleResult();
    }

    public void refresh(LearningPathVersion version) {
        em.refresh(version, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
    }

    public void deferSortConstraints() {
        em.createNativeQuery("SET CONSTRAINTS ux_path_chapter_version_sort, "
                + "ux_path_event_node_chapter_sort, ux_path_lesson_node_sort DEFERRED").executeUpdate();
    }

    public static void require(boolean valid, String message) {
        if (!valid) throw new PathValidationException(List.of(message));
    }
}
