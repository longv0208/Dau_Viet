package com.dauviet.animation.application;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.animation.api.dto.AnimationDtos.SceneCreateRequest;
import com.dauviet.animation.api.dto.AnimationDtos.SceneResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneSummaryResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneUpdateRequest;
import com.dauviet.animation.api.dto.AnimationDtos.SceneValidationResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneVersionDetail;
import com.dauviet.animation.api.dto.AnimationDtos.SceneVersionSummary;
import com.dauviet.animation.api.mapper.AnimationMapper;
import com.dauviet.animation.domain.AnimationExceptions.InvalidStatusTransitionException;
import com.dauviet.animation.domain.AnimationExceptions.ManifestFieldError;
import com.dauviet.animation.domain.AnimationExceptions.SceneNotFoundException;
import com.dauviet.animation.domain.AnimationExceptions.SceneVersionNotFoundException;
import com.dauviet.animation.domain.AnimationExceptions.TemplateDisabledException;
import com.dauviet.animation.domain.AnimationScene;
import com.dauviet.animation.domain.AnimationSceneHtml;
import com.dauviet.animation.domain.AnimationSceneStatus;
import com.dauviet.animation.domain.AnimationSceneVersion;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneHtmlRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneVersionRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationTemplateRepository;
import com.dauviet.animation.manifest.AnimationManifestValidator;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

import jakarta.persistence.criteria.Predicate;

/**
 * Admin-side scene CRUD + draft management + validate/duplicate/archive.
 * Publishing lives in AnimationScenePublishService (transactional version
 * rotation); version queries live here (read-only).
 */
@Service
public class AnimationSceneService {

    private final AnimationSceneRepository scenes;
    private final AnimationTemplateRepository templates;
    private final AnimationSceneVersionRepository versions;
    private final HistoricalEventRepository events;
    private final AnimationManifestValidator manifestValidator;
    private final AnimationHtmlService htmlService;
    private final AnimationSceneHtmlRepository draftHtml;
    private final AnimationMapper mapper;
    private final ObjectMapper objectMapper;

    public AnimationSceneService(AnimationSceneRepository scenes,
                                 AnimationTemplateRepository templates,
                                 AnimationSceneVersionRepository versions,
                                 HistoricalEventRepository events,
                                 AnimationManifestValidator manifestValidator,
                                 AnimationHtmlService htmlService,
                                 AnimationSceneHtmlRepository draftHtml,
                                 AnimationMapper mapper,
                                 ObjectMapper objectMapper) {
        this.scenes = scenes;
        this.templates = templates;
        this.versions = versions;
        this.events = events;
        this.manifestValidator = manifestValidator;
        this.htmlService = htmlService;
        this.draftHtml = draftHtml;
        this.mapper = mapper;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public SceneResponse create(SceneCreateRequest req, UUID adminId) {
        UUID templateId = parseUuid(req.templateId(), "templateId");
        AnimationTemplate t = templates.findById(templateId)
                .orElseThrow(() -> new com.dauviet.animation.domain.AnimationExceptions
                        .TemplateNotFoundException("Template not found: " + templateId));
        if (!Boolean.TRUE.equals(t.getEnabled())) {
            throw new TemplateDisabledException("Template disabled: " + t.getCode());
        }
        if (req.eventId() != null && !events.existsById(req.eventId())) {
            throw new ResourceNotFoundException("Event not found: " + req.eventId());
        }
        AnimationScene s = new AnimationScene();
        s.setId(UUID.randomUUID());
        s.setTemplateId(templateId);
        s.setEventId(req.eventId());
        s.setTitle(req.title());
        // Default: template's default_config_json seeds the draft.
        String draft = req.draftJson() == null
                ? t.getDefaultConfigJson() : requireJsonObject(req.draftJson());
        s.setDraftJson(draft);
        s.setStatus(AnimationSceneStatus.DRAFT);
        s.setCreatedBy(adminId);
        s.setUpdatedBy(adminId);
        return mapper.toSceneResponse(scenes.saveAndFlush(s), t, versions);
    }

    @Transactional(readOnly = true)
    public Page<SceneSummaryResponse> list(UUID templateId, UUID eventId,
                                           AnimationSceneStatus status,
                                           String q, Pageable pageable) {
        Specification<AnimationScene> spec = (root, cq, cb) -> {
            List<Predicate> preds = new ArrayList<>();
            if (templateId != null) preds.add(cb.equal(root.get("templateId"), templateId));
            if (eventId != null) preds.add(cb.equal(root.get("eventId"), eventId));
            if (status != null) preds.add(cb.equal(root.get("status"), status));
            if (q != null && !q.isBlank()) {
                String like = "%" + q.trim().toLowerCase() + "%";
                preds.add(cb.like(cb.lower(root.get("title")), like));
            }
            return cb.and(preds.toArray(new Predicate[0]));
        };
        Page<AnimationScene> page = scenes.findAll(spec, pageable);
        // Batch-load renderer codes to avoid N+1 template lookups per row.
        java.util.Set<UUID> templateIds = page.getContent().stream()
                .map(AnimationScene::getTemplateId)
                .collect(java.util.stream.Collectors.toSet());
        java.util.Map<UUID, String> rendererByTemplate = templates.findAllById(templateIds)
                .stream()
                .collect(java.util.stream.Collectors.toMap(
                        AnimationTemplate::getId, AnimationTemplate::getRendererCode));
        return page.map(s -> mapper.toSceneSummary(
                s, rendererByTemplate.get(s.getTemplateId()), versions));
    }

    @Transactional(readOnly = true)
    public SceneResponse get(UUID id) {
        AnimationScene s = load(id);
        AnimationTemplate t = templates.findById(s.getTemplateId()).orElse(null);
        return mapper.toSceneResponse(s, t, versions);
    }

    @Transactional
    public SceneResponse update(UUID id, SceneUpdateRequest req, UUID adminId) {
        AnimationScene s = load(id);
        checkVersion(s, req.expectedRowVersion());
        if (s.getStatus() == AnimationSceneStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived scene cannot be edited");
        }
        if (req.title() != null) s.setTitle(req.title());
        if (req.clearEvent()) {
            s.setEventId(null);
        } else if (req.eventId() != null) {
            if (!events.existsById(req.eventId())) {
                throw new ResourceNotFoundException("Event not found: " + req.eventId());
            }
            s.setEventId(req.eventId());
        }
        if (req.draftJson() != null) {
            String next = requireJsonObject(req.draftJson());
            // FIX-03: for HTML_WEBVIEW scenes the manifest's html{} block is
            // server-owned metadata (sha256/sizeBytes of the REAL stored
            // file). Re-derive it from animation_scene_html rather than
            // trusting the payload, so PATCH can't fake a checksum.
            if (isHtmlScene(s)) {
                next = normalizeHtmlDraftMeta(s, next);
            }
            s.setDraftJson(next);
        }
        // Title edits resync the display title inside the HTML manifest so
        // the learner-facing label stays consistent (html{} meta untouched).
        if (req.title() != null && isHtmlScene(s)) {
            s.setDraftJson(syncHtmlManifestTitle(s.getDraftJson(), req.title()));
        }
        s.setUpdatedBy(adminId);
        AnimationTemplate t = templates.findById(s.getTemplateId()).orElse(null);
        return mapper.toSceneResponse(scenes.saveAndFlush(s), t, versions);
    }

    /**
     * Deep-copies a scene (new id, DRAFT status, no versions) — a cheap way
     * to fork a manifest for another event.
     */
    @Transactional
    public SceneResponse duplicate(UUID id, UUID adminId) {
        AnimationScene src = load(id);
        AnimationScene copy = new AnimationScene();
        copy.setId(UUID.randomUUID());
        copy.setTemplateId(src.getTemplateId());
        copy.setEventId(src.getEventId());
        copy.setTitle(src.getTitle() + " (bản sao)");
        copy.setDraftJson(src.getDraftJson());
        copy.setStatus(AnimationSceneStatus.DRAFT);
        copy.setCreatedBy(adminId);
        copy.setUpdatedBy(adminId);
        AnimationTemplate t = templates.findById(src.getTemplateId()).orElse(null);
        AnimationScene saved = scenes.saveAndFlush(copy);
        // HTML_WEBVIEW: fork the draft html row too — duplicated scenes must
        // never share one mutable draft document.
        htmlService.copyDraftHtml(id, saved.getId());
        return mapper.toSceneResponse(saved, t, versions);
    }

    @Transactional
    public SceneResponse archive(UUID id, UUID adminId) {
        AnimationScene s = load(id);
        if (s.getStatus() == AnimationSceneStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("scene already archived");
        }
        s.setStatus(AnimationSceneStatus.ARCHIVED);
        s.setUpdatedBy(adminId);
        AnimationTemplate t = templates.findById(s.getTemplateId()).orElse(null);
        return mapper.toSceneResponse(scenes.saveAndFlush(s), t, versions);
    }

    /**
     * Read-only manifest validation probe — always 200 with structured errors.
     * Never writes animation_scene_versions.
     */
    @Transactional(readOnly = true)
    public SceneValidationResponse validate(UUID id) {
        AnimationScene s = load(id);
        AnimationTemplate t = templates.findById(s.getTemplateId()).orElse(null);
        if (t == null) {
            return new SceneValidationResponse(false, List.of(new ManifestFieldError(
                    "templateId", "TEMPLATE_NOT_FOUND", "template missing")));
        }
        JsonNode manifest;
        try {
            manifest = objectMapper.readTree(s.getDraftJson() == null ? "{}" : s.getDraftJson());
        } catch (Exception e) {
            return new SceneValidationResponse(false, List.of(new ManifestFieldError(
                    "draftJson", "INVALID_JSON", "draft_json is not parseable")));
        }
        List<ManifestFieldError> errors = manifestValidator.validate(manifest, t);
        return new SceneValidationResponse(errors.isEmpty(), errors);
    }

    /* ---------- versions (read-only) ---------- */

    @Transactional(readOnly = true)
    public List<SceneVersionSummary> listVersions(UUID sceneId) {
        load(sceneId);
        return versions.findBySceneIdOrderByVersionNoDesc(sceneId).stream()
                .map(mapper::toVersionSummary).toList();
    }

    @Transactional(readOnly = true)
    public SceneVersionDetail getVersion(UUID sceneId, UUID versionId) {
        load(sceneId);
        AnimationSceneVersion v = versions.findById(versionId)
                .filter(x -> x.getSceneId().equals(sceneId))
                .orElseThrow(() -> new SceneVersionNotFoundException(
                        "Version not found: " + versionId));
        return mapper.toVersionDetail(v);
    }

    /* ---------- internals ---------- */

    public AnimationScene load(UUID id) {
        return scenes.findById(id).orElseThrow(() -> new SceneNotFoundException(
                "Animation scene not found: " + id));
    }

    private void checkVersion(AnimationScene s, Long expected) {
        if (expected != null && !expected.equals(s.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    AnimationScene.class, s.getId());
        }
    }

    private String requireJsonObject(String json) {
        try {
            JsonNode node = objectMapper.readTree(json);
            if (node == null || !node.isObject()) {
                throw new IllegalArgumentException("draftJson must be a JSON object");
            }
            return objectMapper.writeValueAsString(node);
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalArgumentException("draftJson is not valid JSON");
        }
    }

    /* ---------- FIX-03: HTML_WEBVIEW manifest integrity ---------- */

    /** True when the scene's template renders as HTML_WEBVIEW. */
    private boolean isHtmlScene(AnimationScene s) {
        return templates.findById(s.getTemplateId())
                .map(t -> AnimationHtmlService.RENDERER_CODE.equals(t.getRendererCode()))
                .orElse(false);
    }

    /**
     * Re-derive html{} from the stored draft row — PATCH can't spoof
     * sha256/sizeBytes/filename. Preserves the caller's other keys
     * (title, disclaimer, learningObjective, sourceReferences).
     */
    private String normalizeHtmlDraftMeta(AnimationScene s, String draftJson) {
        AnimationSceneHtml stored = draftHtml.findById(s.getId()).orElse(null);
        try {
            ObjectNode node = (ObjectNode) objectMapper.readTree(draftJson);
            ObjectNode html = node.putObject("html");
            if (stored != null) {
                if (stored.getOriginalFilename() != null) {
                    html.put("filename", stored.getOriginalFilename());
                }
                html.put("sizeBytes", stored.getSizeBytes());
                html.put("sha256", stored.getSha256());
            } else {
                // No stored bytes yet — strip a fabricated html{} entirely
                // so validation at publish flags it instead of trusting it.
                node.remove("html");
            }
            return objectMapper.writeValueAsString(node);
        } catch (Exception e) {
            return draftJson;
        }
    }

    /** Keep manifest.title in step with the scene's display title. */
    private String syncHtmlManifestTitle(String draftJson, String title) {
        if (draftJson == null || title == null) return draftJson;
        try {
            ObjectNode node = (ObjectNode) objectMapper.readTree(draftJson);
            node.put("title", title);
            return objectMapper.writeValueAsString(node);
        } catch (Exception e) {
            return draftJson;
        }
    }

    private UUID parseUuid(UUID id, String field) {
        if (id == null) {
            throw new IllegalArgumentException(field + " is required");
        }
        return id;
    }
}
