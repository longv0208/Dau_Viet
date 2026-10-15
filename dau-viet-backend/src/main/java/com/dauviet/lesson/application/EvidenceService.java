package com.dauviet.lesson.application;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.api.dto.EvidencePatchRequest;
import com.dauviet.lesson.api.dto.EvidenceResponse;
import com.dauviet.lesson.api.dto.EvidenceUpsertRequest;
import com.dauviet.lesson.domain.AssetNotFoundException;
import com.dauviet.lesson.domain.Evidence;
import com.dauviet.lesson.domain.EvidenceInUseException;
import com.dauviet.lesson.domain.EvidenceNotFoundException;
import com.dauviet.lesson.domain.EvidenceStatus;
import com.dauviet.lesson.domain.InvalidStatusTransitionException;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.dauviet.lesson.infrastructure.persistence.EvidenceRepository;

import jakarta.persistence.criteria.Predicate;

/**
 * Admin CRUD for source-backed evidence. Evidences are never hard-deleted;
 * `archive` is terminal and refuses when a published snapshot still
 * references the evidence (conservative LIKE scan — see repository).
 */
@Service
public class EvidenceService {

    private static final Set<String> RELIABILITIES =
            Set.of("HIGH", "MEDIUM", "LOW", "UNASSESSED");

    private final EvidenceRepository evidences;
    private final AssetRepository assets;
    private final HistoricalEventRepository events;

    public EvidenceService(EvidenceRepository evidences,
                           AssetRepository assets,
                           HistoricalEventRepository events) {
        this.evidences = evidences;
        this.assets = assets;
        this.events = events;
    }

    @Transactional
    public EvidenceResponse create(EvidenceUpsertRequest req, UUID adminId) {
        if (!events.existsById(req.eventId())) {
            throw new ResourceNotFoundException("Event not found: " + req.eventId());
        }
        checkReliability(req.reliability());
        checkAsset(req.assetId());
        Evidence e = new Evidence();
        e.setId(UUID.randomUUID());
        e.setEventId(req.eventId());
        e.setTitle(req.title());
        e.setEvidenceType(req.evidenceType());
        e.setDescription(req.description());
        e.setSourceTitle(req.sourceTitle());
        e.setSourceAuthor(req.sourceAuthor());
        e.setSourceUrl(req.sourceUrl());
        e.setSourceCitation(req.sourceCitation());
        e.setSourcePublishedAt(req.sourcePublishedAt());
        e.setReliability(normalizeReliability(req.reliability()));
        e.setRelevance(req.relevance());
        e.setAssetId(req.assetId());
        e.setStatus(EvidenceStatus.DRAFT);
        e.setCreatedBy(adminId);
        return toResponse(evidences.saveAndFlush(e));
    }

    @Transactional(readOnly = true)
    public Page<EvidenceResponse> list(UUID eventId, EvidenceStatus status,
                                       String q, Pageable pageable) {
        Specification<Evidence> spec = (root, cq, cb) -> {
            List<Predicate> preds = new ArrayList<>();
            if (eventId != null) preds.add(cb.equal(root.get("eventId"), eventId));
            if (status != null) preds.add(cb.equal(root.get("status"), status));
            if (q != null && !q.isBlank()) {
                String like = "%" + q.trim().toLowerCase(Locale.ROOT) + "%";
                preds.add(cb.or(
                        cb.like(cb.lower(root.get("title")), like),
                        cb.like(cb.lower(root.get("sourceTitle")), like)));
            }
            return cb.and(preds.toArray(new Predicate[0]));
        };
        return evidences.findAll(spec, pageable).map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public EvidenceResponse get(UUID id) {
        return toResponse(load(id));
    }

    @Transactional
    public EvidenceResponse update(UUID id, EvidencePatchRequest req) {
        Evidence e = load(id);
        checkVersion(e, req.expectedRowVersion());
        if (e.getStatus() == EvidenceStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived evidence cannot be edited");
        }
        checkReliability(req.reliability());
        if (req.title() != null) e.setTitle(req.title());
        if (req.evidenceType() != null) e.setEvidenceType(req.evidenceType());
        if (req.description() != null) e.setDescription(req.description());
        if (req.sourceTitle() != null) e.setSourceTitle(req.sourceTitle());
        if (req.sourceAuthor() != null) e.setSourceAuthor(req.sourceAuthor());
        if (req.sourceUrl() != null) e.setSourceUrl(req.sourceUrl());
        if (req.sourceCitation() != null) e.setSourceCitation(req.sourceCitation());
        if (req.sourcePublishedAt() != null) e.setSourcePublishedAt(req.sourcePublishedAt());
        if (req.reliability() != null) e.setReliability(normalizeReliability(req.reliability()));
        if (req.relevance() != null) e.setRelevance(req.relevance());
        if (Boolean.TRUE.equals(req.clearAsset())) {
            e.setAssetId(null);
        } else if (req.assetId() != null) {
            checkAsset(req.assetId());
            e.setAssetId(req.assetId());
        }
        return toResponse(evidences.saveAndFlush(e));
    }

    @Transactional
    public EvidenceResponse approve(UUID id) {
        Evidence e = load(id);
        if (e.getStatus() != EvidenceStatus.DRAFT) {
            throw new InvalidStatusTransitionException(
                    "only DRAFT evidence can be approved (current: " + e.getStatus() + ")");
        }
        e.setStatus(EvidenceStatus.APPROVED);
        return toResponse(evidences.saveAndFlush(e));
    }

    @Transactional
    public EvidenceResponse archive(UUID id, Long expectedRowVersion) {
        Evidence e = load(id);
        checkVersion(e, expectedRowVersion);
        if (e.getStatus() == EvidenceStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("evidence already archived");
        }
        List<UUID> referencing = evidences.lessonIdsReferencing(id.toString());
        if (!referencing.isEmpty()) {
            throw new EvidenceInUseException(
                    "evidence " + id + " is referenced by a published lesson snapshot",
                    referencing);
        }
        e.setStatus(EvidenceStatus.ARCHIVED);
        return toResponse(evidences.saveAndFlush(e));
    }

    /* ---------------- helpers ---------------- */

    private Evidence load(UUID id) {
        return evidences.findById(id)
                .orElseThrow(() -> new EvidenceNotFoundException("Evidence not found: " + id));
    }

    private void checkVersion(Evidence e, Long expected) {
        if (expected != null && !expected.equals(e.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    Evidence.class, e.getId());
        }
    }

    private void checkReliability(String reliability) {
        if (reliability == null) return;
        if (!RELIABILITIES.contains(reliability.toUpperCase(Locale.ROOT))) {
            throw new IllegalArgumentException(
                    "reliability must be one of " + RELIABILITIES);
        }
    }

    private String normalizeReliability(String reliability) {
        return reliability == null ? null : reliability.toUpperCase(Locale.ROOT);
    }

    private void checkAsset(UUID assetId) {
        if (assetId == null) return;
        if (!assets.existsById(assetId)) {
            throw new AssetNotFoundException("Asset not found: " + assetId);
        }
    }

    private EvidenceResponse toResponse(Evidence e) {
        return new EvidenceResponse(
                e.getId(), e.getEventId(), e.getTitle(), e.getEvidenceType(),
                e.getDescription(), e.getSourceTitle(), e.getSourceAuthor(),
                e.getSourceUrl(), e.getSourceCitation(), e.getSourcePublishedAt(),
                e.getReliability(), e.getRelevance(), e.getAssetId(),
                e.getStatus().name(), e.getCreatedBy(), e.getCreatedAt(),
                e.getUpdatedAt(), e.getRowVersion());
    }
}
