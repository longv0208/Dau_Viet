package com.dauviet.animation.application;

import java.nio.charset.StandardCharsets;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.dauviet.animation.api.dto.AnimationDtos.SceneUpdateRequest;
import com.dauviet.animation.api.mapper.AnimationMapper;
import com.dauviet.animation.domain.AnimationScene;
import com.dauviet.animation.domain.AnimationSceneHtml;
import com.dauviet.animation.domain.AnimationSceneStatus;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneHtmlRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneVersionRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationTemplateRepository;
import com.dauviet.animation.manifest.AnimationManifestValidator;
import com.dauviet.animation.manifest.HtmlDocumentValidator;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

/**
 * FIX-03 PATCH-side integrity: SceneUpdateRequest.draftJson mang html{}
 * do client gửi — phải bị server re-derive từ animation_scene_html, không
 * bao giờ tin checksum của payload. Title edit phải resync manifest.title.
 */
@ExtendWith(MockitoExtension.class)
class AnimationSceneServiceUpdateTest {

    @Mock AnimationSceneRepository scenes;
    @Mock AnimationTemplateRepository templates;
    @Mock AnimationSceneVersionRepository versions;
    @Mock HistoricalEventRepository events;
    @Mock AnimationManifestValidator manifestValidator;
    @Mock AnimationHtmlService htmlService;
    @Mock AnimationSceneHtmlRepository draftHtml;
    @Mock AnimationMapper mapper;

    private AnimationSceneService service;
    private final ObjectMapper om = new ObjectMapper();

    private UUID sceneId;
    private UUID templateId;
    private AnimationScene scene;
    private AnimationTemplate htmlTemplate;

    @BeforeEach
    void setUp() {
        service = new AnimationSceneService(scenes, templates, versions, events,
                manifestValidator, htmlService, draftHtml, mapper, om);
        sceneId = UUID.randomUUID();
        templateId = UUID.randomUUID();
        scene = new AnimationScene();
        scene.setId(sceneId);
        scene.setTemplateId(templateId);
        scene.setTitle("Bạch Đằng");
        scene.setStatus(AnimationSceneStatus.DRAFT);

        htmlTemplate = new AnimationTemplate();
        htmlTemplate.setId(templateId);
        htmlTemplate.setCode(AnimationHtmlService.TEMPLATE_CODE);
        htmlTemplate.setRendererCode(AnimationHtmlService.RENDERER_CODE);

        lenient().when(scenes.findById(sceneId)).thenReturn(Optional.of(scene));
        lenient().when(templates.findById(templateId))
                .thenReturn(Optional.of(htmlTemplate));
        lenient().when(scenes.saveAndFlush(any(AnimationScene.class)))
                .thenAnswer(inv -> inv.getArgument(0));
    }

    /** PATCH gửi html{sha256 giả} → server phải ghi đè bằng giá trị stored. */
    @Test
    void patchDraftJsonResyncsHtmlMetaFromStoredBytes() throws Exception {
        String realContent = "<html><body>real</body></html>";
        byte[] realBytes = realContent.getBytes(StandardCharsets.UTF_8);
        String realSha = HtmlDocumentValidator.sha256(realBytes);
        when(draftHtml.findById(sceneId)).thenReturn(Optional.of(
                new AnimationSceneHtml(sceneId, realContent, realSha,
                        (long) realBytes.length, "bd.html")));

        String spoof = "{\"title\":\"x\",\"html\":{\"sha256\":\""
                + "0".repeat(64) + "\",\"sizeBytes\":1,\"filename\":\"evil.html\"}}";
        service.update(sceneId, new SceneUpdateRequest(null, null, false,
                spoof, null), UUID.randomUUID());

        JsonNode saved = om.readTree(scene.getDraftJson());
        assertEquals(realSha, saved.path("html").path("sha256").asText());
        assertEquals(realBytes.length, saved.path("html").path("sizeBytes").asLong());
        assertEquals("bd.html", saved.path("html").path("filename").asText());
        // Key khác do client gửi vẫn giữ nguyên.
        assertEquals("x", saved.path("title").asText());
    }

    /** PATCH html{} bịa khi chưa có bytes → block phải bị strip, không ship. */
    @Test
    void patchDraftJsonStripsFabricatedHtmlMetaWhenNoStoredBytes() throws Exception {
        when(draftHtml.findById(sceneId)).thenReturn(Optional.empty());
        String fake = "{\"html\":{\"sha256\":\"" + "a".repeat(64) + "\"}}";
        service.update(sceneId, new SceneUpdateRequest(null, null, false,
                fake, null), UUID.randomUUID());
        assertFalse(om.readTree(scene.getDraftJson()).has("html"));
    }

    /** PATCH chỉ sửa title → manifest.title resync, html{} không đổi. */
    @Test
    void titleEditResyncsManifestTitle() throws Exception {
        scene.setDraftJson("{\"title\":\"Cũ\",\"html\":{\"sha256\":\"abc\"}}");
        service.update(sceneId, new SceneUpdateRequest("Trận mới", null,
                false, null, null), UUID.randomUUID());
        JsonNode saved = om.readTree(scene.getDraftJson());
        assertEquals("Trận mới", saved.path("title").asText());
        assertEquals("abc", saved.path("html").path("sha256").asText());
    }

    /** Scene KHÔNG phải HTML_WEBVIEW → PATCH draftJson giữ nguyên payload. */
    @Test
    void nonHtmlSceneKeepsDraftJsonAsSent() throws Exception {
        htmlTemplate.setRendererCode("RIVER_TIDE");
        scene.setDraftJson("{\"v\":1}");
        String sent = "{\"v\":2,\"html\":{\"sha256\":\"whatever\"}}";
        service.update(sceneId, new SceneUpdateRequest(null, null, false,
                sent, null), UUID.randomUUID());
        JsonNode saved = om.readTree(scene.getDraftJson());
        assertEquals(2, saved.path("v").asInt());
        // html{} của non-HTML scene không bị normalize chạm vào.
        assertEquals("whatever", saved.path("html").path("sha256").asText());
    }
}
