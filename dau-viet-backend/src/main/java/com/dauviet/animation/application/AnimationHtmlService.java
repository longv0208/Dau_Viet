package com.dauviet.animation.application;

import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.dauviet.animation.api.dto.AnimationDtos.SceneResponse;
import com.dauviet.animation.api.mapper.AnimationMapper;
import com.dauviet.animation.domain.AnimationExceptions.InvalidStatusTransitionException;
import com.dauviet.animation.domain.AnimationExceptions.SceneNotFoundException;
import com.dauviet.animation.domain.AnimationExceptions.SceneVersionNotFoundException;
import com.dauviet.animation.domain.AnimationExceptions.TemplateNotFoundException;
import com.dauviet.animation.domain.AnimationScene;
import com.dauviet.animation.domain.AnimationSceneHtml;
import com.dauviet.animation.domain.AnimationSceneStatus;
import com.dauviet.animation.domain.AnimationSceneVersion;
import com.dauviet.animation.domain.AnimationSceneVersionHtml;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneHtmlRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneVersionHtmlRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneVersionRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationTemplateRepository;
import com.dauviet.animation.manifest.HtmlDocumentValidator;
import com.dauviet.animation.manifest.HtmlDocumentValidator.ValidatedHtml;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * HTML_WEBVIEW scenes: import a self-contained .html file, replace the draft,
 * serve draft/published bytes. The scene's draft_json stays a minimal
 * auto-generated manifest (rendererCode + html metadata) — real content lives
 * in animation_scene_html / animation_scene_version_html, never inside
 * snapshot_json.
 */
@Service
public class AnimationHtmlService {

    public static final String TEMPLATE_CODE = "html-webview";
    public static final String RENDERER_CODE = "HTML_WEBVIEW";

    private static final String DEFAULT_DISCLAIMER =
            "Hoạt họa tải lên bởi quản trị viên; nội dung do tác giả HTML chịu trách nhiệm.";

    private final AnimationSceneRepository scenes;
    private final AnimationTemplateRepository templates;
    private final AnimationSceneVersionRepository versions;
    private final AnimationSceneHtmlRepository draftHtml;
    private final AnimationSceneVersionHtmlRepository versionHtml;
    private final HistoricalEventRepository events;
    private final HtmlDocumentValidator htmlValidator;
    private final AnimationMapper mapper;
    private final ObjectMapper objectMapper;

    public AnimationHtmlService(AnimationSceneRepository scenes,
                                AnimationTemplateRepository templates,
                                AnimationSceneVersionRepository versions,
                                AnimationSceneHtmlRepository draftHtml,
                                AnimationSceneVersionHtmlRepository versionHtml,
                                HistoricalEventRepository events,
                                HtmlDocumentValidator htmlValidator,
                                AnimationMapper mapper,
                                ObjectMapper objectMapper) {
        this.scenes = scenes;
        this.templates = templates;
        this.versions = versions;
        this.draftHtml = draftHtml;
        this.versionHtml = versionHtml;
        this.events = events;
        this.htmlValidator = htmlValidator;
        this.mapper = mapper;
        this.objectMapper = objectMapper;
    }

    /**
     * Import one .html file → new HTML_WEBVIEW scene in DRAFT status.
     * Title defaults to the file name (without extension) when not given.
     */
    @Transactional
    public SceneResponse importHtml(MultipartFile file, String title,
                                    UUID eventId, UUID adminId) {
        ValidatedHtml html = htmlValidator.validate(file);
        AnimationTemplate template = templates.findByCode(TEMPLATE_CODE)
                .orElseThrow(() -> new TemplateNotFoundException(
                        "Template '" + TEMPLATE_CODE + "' missing — V19 not applied"));
        if (eventId != null && !events.existsById(eventId)) {
            throw new ResourceNotFoundException("Event not found: " + eventId);
        }
        String sceneTitle = (title == null || title.isBlank())
                ? titleFromFilename(html.filename()) : title.trim();

        AnimationScene s = new AnimationScene();
        s.setId(UUID.randomUUID());
        s.setTemplateId(template.getId());
        s.setEventId(eventId);
        s.setTitle(sceneTitle);
        s.setStatus(AnimationSceneStatus.DRAFT);
        s.setCreatedBy(adminId);
        s.setUpdatedBy(adminId);
        s.setDraftJson(draftManifest(sceneTitle, html));
        AnimationScene saved = scenes.saveAndFlush(s);

        draftHtml.save(new AnimationSceneHtml(saved.getId(), html.content(),
                html.sha256(), html.sizeBytes(), html.filename()));
        return mapper.toSceneResponse(saved, template, versions);
    }

    /**
     * Replace the draft HTML of an existing HTML_WEBVIEW scene. Published
     * versions stay untouched — new bytes ship on the next publish.
     */
    @Transactional
    public SceneResponse replaceHtmlDraft(UUID sceneId, MultipartFile file,
                                          Long expectedRowVersion, UUID adminId) {
        AnimationScene s = loadHtmlScene(sceneId);
        if (expectedRowVersion != null && !expectedRowVersion.equals(s.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    AnimationScene.class, s.getId());
        }
        if (s.getStatus() == AnimationSceneStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived scene cannot be edited");
        }
        ValidatedHtml html = htmlValidator.validate(file);
        draftHtml.save(new AnimationSceneHtml(sceneId, html.content(),
                html.sha256(), html.sizeBytes(), html.filename()));
        s.setDraftJson(draftManifest(s.getTitle(), html));
        s.setUpdatedBy(adminId);
        AnimationTemplate t = templates.findById(s.getTemplateId()).orElse(null);
        return mapper.toSceneResponse(scenes.saveAndFlush(s), t, versions);
    }

    /** Draft HTML for the admin sandboxed preview (CONTENT_ADMIN only). */
    @Transactional(readOnly = true)
    public AnimationSceneHtml getDraftHtml(UUID sceneId) {
        loadHtmlScene(sceneId);
        return draftHtml.findById(sceneId).orElseThrow(
                () -> new SceneNotFoundException(
                        "No HTML draft for scene: " + sceneId));
    }

    /** Published HTML bytes for the learner WebView — any authenticated user. */
    @Transactional(readOnly = true)
    public AnimationSceneVersionHtml getPublishedHtml(UUID versionId) {
        AnimationSceneVersion v = versions.findById(versionId).orElseThrow(
                () -> new SceneVersionNotFoundException(
                        "Version not found: " + versionId));
        if (!RENDERER_CODE.equals(v.getRendererCode())) {
            throw new SceneVersionNotFoundException(
                    "Not an HTML scene version: " + versionId);
        }
        return versionHtml.findById(versionId).orElseThrow(
                () -> new SceneVersionNotFoundException(
                        "No HTML stored for version: " + versionId));
    }

    /**
     * Copy published draft html → immutable version row. Called inside the
     * publish transaction by AnimationScenePublishService.
     */
    public void snapshotHtmlForVersion(UUID sceneId, UUID versionId) {
        AnimationSceneHtml draft = draftHtml.findById(sceneId).orElseThrow(
                () -> new InvalidStatusTransitionException(
                        "HTML draft missing for scene: " + sceneId));
        versionHtml.save(new AnimationSceneVersionHtml(versionId,
                draft.getContent(), draft.getSha256(), draft.getSizeBytes(),
                draft.getOriginalFilename()));
    }

    /** Copy draft html when a scene is duplicated — drafts never share rows. */
    public void copyDraftHtml(UUID fromSceneId, UUID toSceneId) {
        draftHtml.findById(fromSceneId).ifPresent(d ->
                draftHtml.save(new AnimationSceneHtml(toSceneId, d.getContent(),
                        d.getSha256(), d.getSizeBytes(), d.getOriginalFilename())));
    }

    /* ---------- internals ---------- */

    private AnimationScene loadHtmlScene(UUID sceneId) {
        AnimationScene s = scenes.findById(sceneId).orElseThrow(
                () -> new SceneNotFoundException("Animation scene not found: " + sceneId));
        String renderer = templates.findById(s.getTemplateId())
                .map(AnimationTemplate::getRendererCode).orElse(null);
        if (!RENDERER_CODE.equals(renderer)) {
            throw new InvalidStatusTransitionException(
                    "scene " + sceneId + " is not an HTML_WEBVIEW scene");
        }
        return s;
    }

    /** Minimal auto-generated manifest — bytes live in the html side table. */
    private String draftManifest(String title, ValidatedHtml html) {
        try {
            ObjectNode root = objectMapper.createObjectNode();
            root.put("schemaVersion", 2);
            root.put("rendererCode", RENDERER_CODE);
            root.put("rendererVersion", 1);
            root.put("title", title);
            root.put("disclaimer", DEFAULT_DISCLAIMER);
            root.putArray("sourceReferences");
            ObjectNode meta = root.putObject("html");
            if (html.filename() != null) meta.put("filename", html.filename());
            meta.put("sizeBytes", html.sizeBytes());
            meta.put("sha256", html.sha256());
            return objectMapper.writeValueAsString(root);
        } catch (Exception e) {
            throw new IllegalStateException("draft manifest build failed", e);
        }
    }

    private static String titleFromFilename(String filename) {
        if (filename == null || filename.isBlank()) return "Hoạt họa HTML";
        String base = filename.replaceAll("(?i)\\.html?$", "");
        return base.isBlank() ? "Hoạt họa HTML" : base;
    }
}
