package com.dauviet.collection.application;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.api.dto.AdminDossierDtos.AdminDossierCreateRequest;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminDossierDetailResponse;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminDossierSummaryResponse;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminDossierUpdateRequest;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminEventDossierLinkRequest;
import com.dauviet.collection.api.dto.AdminDossierDtos.AdminEventDossierLinkResponse;
import com.dauviet.collection.api.dto.AdminDossierDtos.DossierSourceInput;
import com.dauviet.collection.domain.EventDossier;
import com.dauviet.collection.domain.HistoricalDossier;
import com.dauviet.collection.domain.HistoricalDossier.DossierType;
import com.dauviet.collection.domain.HistoricalDossier.Status;
import com.dauviet.collection.domain.HistoricalDossierVersion;
import com.dauviet.collection.domain.DossierNotFoundException;
import com.dauviet.collection.domain.PolicyValidationException;
import com.dauviet.collection.infrastructure.persistence.EventDossierRepository;
import com.dauviet.collection.infrastructure.persistence.HistoricalDossierRepository;
import com.dauviet.collection.infrastructure.persistence.HistoricalDossierVersionRepository;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Asset;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Admin CRUD + publish/archive cho historical_dossiers + event_dossiers
 * links (GAME-06 Module B).
 *
 * Quy uoc:
 * - canonicalCode unique + immutable — chi set luc tao.
 * - Publish tao snapshot trong historical_dossier_versions va tang
 *   dossier_version; learner da unlock pin version cu — khong thu hoi.
 * - Sua PUBLISHED khong tu dong ra version moi — co "pendingChanges"
 *   cho toi khi bam publish.
 * - Event links PUT = replace-list; chi link dossier PUBLISHED.
 */
@Service
public class AdminDossierService {

    private final HistoricalDossierRepository dossiers;
    private final HistoricalDossierVersionRepository versions;
    private final EventDossierRepository links;
    private final HistoricalEventRepository events;
    private final AssetRepository assets;
    private final ObjectMapper mapper;

    public AdminDossierService(HistoricalDossierRepository dossiers,
            HistoricalDossierVersionRepository versions,
            EventDossierRepository links,
            HistoricalEventRepository events,
            AssetRepository assets,
            ObjectMapper mapper) {
        this.dossiers = dossiers;
        this.versions = versions;
        this.links = links;
        this.events = events;
        this.assets = assets;
        this.mapper = mapper;
    }

    /* ---------- list/get ---------- */

    @Transactional(readOnly = true)
    public Page<AdminDossierSummaryResponse> list(String type, String status,
            String q, Pageable pageable) {
        Specification<HistoricalDossier> spec = (root, cq, cb) -> cb.conjunction();
        if (type != null && !type.isBlank()) {
            DossierType t = DossierType.valueOf(type);
            spec = spec.and((root, cq, cb) -> cb.equal(root.get("dossierType"), t));
        }
        if (status != null && !status.isBlank()) {
            Status s = Status.valueOf(status);
            spec = spec.and((root, cq, cb) -> cb.equal(root.get("status"), s));
        }
        if (q != null && !q.isBlank()) {
            String like = "%" + q.trim().toLowerCase(java.util.Locale.ROOT) + "%";
            spec = spec.and((root, cq, cb) -> cb.or(
                    cb.like(cb.lower(root.get("canonicalCode")), like),
                    cb.like(cb.lower(root.get("title")), like)));
        }
        return dossiers.findAll(spec, pageable).map(d ->
                new AdminDossierSummaryResponse(d.getId(), d.getCanonicalCode(),
                        d.getDossierType().name(), d.getTitle(), d.getSummary(),
                        d.getStatus().name(), d.getDossierVersion(),
                        d.getAssetId(), links.countByDossierId(d.getId()),
                        d.getUpdatedAt()));
    }

    @Transactional(readOnly = true)
    public AdminDossierDetailResponse get(UUID id) {
        HistoricalDossier d = requireDossier(id);
        return toDetail(d);
    }

    /* ---------- create/update ---------- */

    @Transactional
    public AdminDossierDetailResponse create(AdminDossierCreateRequest req,
            UUID adminId) {
        dossiers.findByCanonicalCode(req.canonicalCode()).ifPresent(x -> {
            throw new IllegalArgumentException(
                    "canonicalCode already exists: " + req.canonicalCode());
        });
        validateAsset(req.assetId());
        HistoricalDossier d = HistoricalDossier.draft(
                req.canonicalCode(), DossierType.valueOf(req.dossierType()),
                req.title(), req.summary(), req.description(),
                toSourceJson(req.source()), req.assetId(), adminId);
        try {
            dossiers.saveAndFlush(d);
        } catch (DataIntegrityViolationException e) {
            throw new IllegalArgumentException(
                    "canonicalCode already exists: " + req.canonicalCode());
        }
        return toDetail(d);
    }

    @Transactional
    public AdminDossierDetailResponse update(UUID id,
            AdminDossierUpdateRequest req) {
        HistoricalDossier d = requireDossier(id);
        checkRowVersion(d, req.expectedRowVersion());

        if (req.dossierType() != null) {
            d.setDossierType(DossierType.valueOf(req.dossierType()));
        }
        if (req.title() != null) {
            d.setTitle(req.title());
        }
        if (req.summary() != null) {
            d.setSummary(req.summary());
        }
        if (req.description() != null) {
            d.setDescription(req.description());
        }
        if (req.source() != null) {
            d.setSourceJson(toSourceJson(req.source()));
        }
        if (Boolean.TRUE.equals(req.clearAsset())) {
            d.setAssetId(null);
        } else if (req.assetId() != null) {
            validateAsset(req.assetId());
            d.setAssetId(req.assetId());
        }
        dossiers.save(d);
        return toDetail(d);
    }

    /* ---------- publish/archive ---------- */

    /**
     * Atomic publish: lock row -> validate -> dossier_version++ ->
     * PUBLISHED -> snapshot vao historical_dossier_versions.
     */
    @Transactional
    public AdminDossierDetailResponse publish(UUID id, UUID adminId) {
        HistoricalDossier d = dossiers.findForUpdate(id)
                .orElseThrow(() -> new DossierNotFoundException(
                        "dossier not found: " + id));
        List<String> errors = validateForPublish(d);
        if (!errors.isEmpty()) {
            throw new PolicyValidationException(errors);
        }
        Integer max = versions.findMaxVersion(id);
        int next = (max == null ? 0 : max) + 1;
        d.setDossierVersion(next);
        d.setStatus(Status.PUBLISHED);
        dossiers.save(d);
        versions.save(HistoricalDossierVersion.snapshotOf(d, adminId));
        return toDetail(d);
    }

    /**
     * Archive: learner da unlock van doc duoc (DossierService giu) —
     * khong dong event_dossiers hay user_dossier_unlocks.
     */
    @Transactional
    public AdminDossierDetailResponse archive(UUID id) {
        HistoricalDossier d = requireDossier(id);
        if (d.getStatus() == Status.ARCHIVED) {
            return toDetail(d);
        }
        d.setStatus(Status.ARCHIVED);
        dossiers.save(d);
        return toDetail(d);
    }

    /* ---------- event links ---------- */

    @Transactional(readOnly = true)
    public List<AdminEventDossierLinkResponse> listEventLinks(UUID eventId) {
        requireEvent(eventId);
        List<EventDossier> rows = links.findByEventIdOrderBySortOrderAsc(eventId);
        if (rows.isEmpty()) {
            return List.of();
        }
        Map<UUID, HistoricalDossier> byId = dossiers.findAllByIdIn(
                rows.stream().map(EventDossier::getDossierId)
                        .collect(Collectors.toSet()))
                .stream().collect(Collectors.toMap(HistoricalDossier::getId,
                        d -> d));
        List<AdminEventDossierLinkResponse> out = new ArrayList<>();
        for (EventDossier ed : rows) {
            HistoricalDossier d = byId.get(ed.getDossierId());
            if (d == null) {
                continue;
            }
            out.add(new AdminEventDossierLinkResponse(d.getId(),
                    d.getCanonicalCode(), d.getTitle(),
                    d.getDossierType().name(), d.getStatus().name(),
                    ed.getSortOrder()));
        }
        return out;
    }

    /**
     * Replace toan bo list link cua event. Validate: dossier ton tai +
     * PUBLISHED, dossierId khong trung, displayOrder khong trung >= 0.
     * Lazy reconcile (EventReconcileService) pick up link moi khi learner
     * mo dossier list — khong can fan-out thu cong.
     */
    @Transactional
    public List<AdminEventDossierLinkResponse> replaceEventLinks(UUID eventId,
            List<AdminEventDossierLinkRequest> req) {
        requireEvent(eventId);
        List<AdminEventDossierLinkRequest> in = req == null ? List.of() : req;

        Set<UUID> seenDossier = new HashSet<>();
        Set<Integer> seenOrder = new HashSet<>();
        List<String> errors = new ArrayList<>();
        for (AdminEventDossierLinkRequest l : in) {
            if (l.dossierId() == null || !seenDossier.add(l.dossierId())) {
                errors.add("duplicate dossierId " + l.dossierId());
            }
            if (l.displayOrder() == null || l.displayOrder() < 0
                    || !seenOrder.add(l.displayOrder())) {
                errors.add("displayOrder must be unique and >= 0: "
                        + l.displayOrder());
            }
        }
        List<HistoricalDossier> found = dossiers.findAllByIdIn(
                in.stream().map(AdminEventDossierLinkRequest::dossierId)
                        .collect(Collectors.toSet()));
        Map<UUID, HistoricalDossier> byId = found.stream()
                .collect(Collectors.toMap(HistoricalDossier::getId, d -> d));
        for (AdminEventDossierLinkRequest l : in) {
            HistoricalDossier d = byId.get(l.dossierId());
            if (d == null) {
                errors.add("dossier not found: " + l.dossierId());
            } else if (d.getStatus() != Status.PUBLISHED) {
                errors.add("dossier " + l.dossierId()
                        + " is not PUBLISHED (current: " + d.getStatus() + ")");
            }
        }
        if (!errors.isEmpty()) {
            throw new PolicyValidationException(errors);
        }

        // Replace: xoa tat ca link cu roi insert list moi (transactional).
        List<EventDossier> current = links.findByEventIdOrderBySortOrderAsc(eventId);
        links.deleteAll(current);
        links.flush();
        List<EventDossier> fresh = in.stream()
                .map(l -> EventDossier.link(eventId, l.dossierId(),
                        l.displayOrder()))
                .toList();
        links.saveAll(fresh);
        return listEventLinks(eventId);
    }

    /* ---------- helpers ---------- */

    private HistoricalDossier requireDossier(UUID id) {
        return dossiers.findById(id)
                .orElseThrow(() -> new DossierNotFoundException(
                        "dossier not found: " + id));
    }

    private HistoricalEvent requireEvent(UUID eventId) {
        return events.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "event not found: " + eventId));
    }

    private void checkRowVersion(HistoricalDossier d, Long expected) {
        if (expected == null) {
            return;
        }
        long current = d.getRowVersion() == null ? 0L : d.getRowVersion();
        if (current != expected) {
            throw new OptimisticLockingFailureException(
                    "dossier rowVersion mismatch: expected " + expected
                    + " but current is " + current + " — reload and retry");
        }
    }

    private void validateAsset(UUID assetId) {
        if (assetId == null) {
            return;
        }
        Asset a = assets.findById(assetId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "asset not found: " + assetId));
        if (!"ACTIVE".equals(a.getState())) {
            throw new IllegalArgumentException(
                    "asset " + assetId + " is not ACTIVE (current: "
                    + a.getState() + ")");
        }
    }

    /** Validate noi dung truoc publish — title, type, source.title. */
    private List<String> validateForPublish(HistoricalDossier d) {
        List<String> errors = new ArrayList<>();
        if (d.getTitle() == null || d.getTitle().isBlank()) {
            errors.add("title must not be blank");
        }
        if (d.getDossierType() == null) {
            errors.add("dossierType is required");
        }
        if (d.getAssetId() != null
                && !assets.existsByIdAndState(d.getAssetId(), "ACTIVE")) {
            errors.add("asset " + d.getAssetId()
                    + " does not exist or is not ACTIVE");
        }
        if (d.getSourceJson() != null) {
            try {
                var node = mapper.readTree(d.getSourceJson());
                var src = node.path("source");
                if (!src.isObject()
                        || src.path("title").asText("").isBlank()) {
                    errors.add("source.title must not be blank");
                }
                String rel = src.path("reliability").asText(null);
                if (rel != null && !Set.of("HIGH", "MEDIUM", "LOW",
                        "UNASSESSED").contains(rel)) {
                    errors.add("source.reliability must be HIGH, MEDIUM, "
                            + "LOW or UNASSESSED");
                }
            } catch (Exception e) {
                errors.add("sourceJson is not valid JSON object");
            }
        }
        return errors;
    }

    private String toSourceJson(DossierSourceInput src) {
        if (src == null) {
            return null;
        }
        ObjectNode s = mapper.createObjectNode();
        s.put("title", src.title());
        if (src.author() != null) s.put("author", src.author());
        if (src.citation() != null) s.put("citation", src.citation());
        if (src.url() != null) s.put("url", src.url());
        if (src.reliability() != null) s.put("reliability", src.reliability());
        ObjectNode root = mapper.createObjectNode();
        root.set("source", s);
        return root.toString();
    }

    private DossierSourceInput parseSource(String sourceJson) {
        if (sourceJson == null) {
            return null;
        }
        try {
            var src = mapper.readTree(sourceJson).path("source");
            if (!src.isObject()) {
                return null;
            }
            return new DossierSourceInput(
                    src.path("title").asText(null),
                    src.path("author").asText(null),
                    src.path("citation").asText(null),
                    src.path("url").asText(null),
                    src.path("reliability").asText(null));
        } catch (Exception e) {
            return null;
        }
    }

    private AdminDossierDetailResponse toDetail(HistoricalDossier d) {
        List<EventDossier> linkRows =
                links.findByDossierIdOrderBySortOrderAsc(d.getId());
        List<AdminDossierDetailResponse.LinkedEvent> linkedEvents =
                new ArrayList<>();
        if (!linkRows.isEmpty()) {
            Map<UUID, String> titles = new HashMap<>();
            events.findAllById(linkRows.stream().map(EventDossier::getEventId)
                    .toList()).forEach(e -> titles.put(e.getId(), e.getTitle()));
            for (EventDossier ed : linkRows) {
                linkedEvents.add(new AdminDossierDetailResponse.LinkedEvent(
                        ed.getEventId(), titles.get(ed.getEventId()),
                        ed.getSortOrder()));
            }
        }

        List<HistoricalDossierVersion> history =
                versions.findByDossierIdOrderByDossierVersionDesc(d.getId());
        boolean pendingChanges = d.getStatus() == Status.PUBLISHED
                && !history.isEmpty()
                && d.getDossierVersion() > history.get(0).getDossierVersion();
        // Voi dossier DRAFT chua publish: pending = false (chua co gi de
        // khac biet). Voi PUBLISHED: doi chieu noi dung snapshot moi nhat.
        if (d.getStatus() == Status.PUBLISHED && !history.isEmpty()
                && history.get(0).getDossierVersion()
                        .equals(d.getDossierVersion())) {
            HistoricalDossierVersion v = history.get(0);
            pendingChanges = !(safeEq(v.getTitle(), d.getTitle())
                    && safeEq(v.getSummary(), d.getSummary())
                    && safeEq(v.getDescription(), d.getDescription())
                    && safeEq(v.getSourceJson(), d.getSourceJson())
                    && safeEq(v.getAssetId(), d.getAssetId()));
        }

        List<AdminDossierDetailResponse.VersionEntry> ves = history.stream()
                .map(v -> new AdminDossierDetailResponse.VersionEntry(
                        v.getDossierVersion(), v.getStatus().name(),
                        v.getPublishedAt(), v.getPublishedBy()))
                .toList();

        return new AdminDossierDetailResponse(d.getId(), d.getCanonicalCode(),
                d.getDossierType().name(), d.getTitle(), d.getSummary(),
                d.getDescription(), parseSource(d.getSourceJson()),
                d.getAssetId(), d.getStatus().name(), d.getDossierVersion(),
                d.getRowVersion(), pendingChanges, linkedEvents, ves,
                d.getCreatedAt(), d.getUpdatedAt());
    }

    private boolean safeEq(Object a, Object b) {
        return java.util.Objects.equals(a, b);
    }
}
