package com.dauviet.animation.application;

import java.nio.charset.StandardCharsets;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import com.dauviet.animation.api.mapper.AnimationMapper;
import com.dauviet.animation.domain.AnimationExceptions.InvalidStatusTransitionException;
import com.dauviet.animation.domain.AnimationScene;
import com.dauviet.animation.domain.AnimationSceneHtml;
import com.dauviet.animation.domain.AnimationSceneVersionHtml;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneHtmlRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneVersionHtmlRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneVersionRepository;
import com.dauviet.animation.infrastructure.persistence.AnimationTemplateRepository;
import com.dauviet.animation.manifest.HtmlDocumentValidator;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * FIX-03: checksum integrity + publish-time verification + duplicate.
 * Mockito-only (no Spring context / DB) — IT covering real Postgres
 * TEXT mapping stays BLOCKED without Docker.
 */
@ExtendWith(MockitoExtension.class)
class AnimationHtmlServiceTest {

    @Mock AnimationSceneRepository scenes;
    @Mock AnimationTemplateRepository templates;
    @Mock AnimationSceneVersionRepository versions;
    @Mock AnimationSceneHtmlRepository draftHtml;
    @Mock AnimationSceneVersionHtmlRepository versionHtml;
    @Mock HistoricalEventRepository events;
    @Mock AnimationMapper mapper;

    private AnimationHtmlService service;
    private final ObjectMapper om = new ObjectMapper();

    private static final String HTML = """
            <!doctype html><html><head><style>body{margin:0}</style></head>
            <body><canvas id="c"></canvas><script>void 0</script></body></html>
            """;

    @BeforeEach
    void setUp() {
        service = new AnimationHtmlService(scenes, templates, versions,
                draftHtml, versionHtml, events,
                new HtmlDocumentValidator(15 * 1024 * 1024), mapper, om);
    }

    private AnimationTemplate htmlTemplate(UUID id) {
        AnimationTemplate t = new AnimationTemplate();
        t.setId(id);
        t.setCode(AnimationHtmlService.TEMPLATE_CODE);
        t.setRendererCode(AnimationHtmlService.RENDERER_CODE);
        t.setRendererVersion(1);
        t.setSchemaVersion(2);
        t.setEnabled(true);
        return t;
    }

    /* ---------- FIX-03: publish verifies stored bytes vs manifest pin ---- */

    @Test
    void publishRejectsWhenStoredChecksumDrifted() {
        // Kẻ tấn công ghi html.sha256 vào cột nhưng sửa content ở chỗ khác —
        // rehash phải bắt được (stored col không còn tin cậy một chiều).
        UUID sceneId = UUID.randomUUID();
        AnimationSceneHtml drifted = new AnimationSceneHtml(sceneId,
                HTML + "<!--tampered-->",
                HtmlDocumentValidator.sha256(HTML.getBytes(StandardCharsets.UTF_8)),
                (long) HTML.getBytes(StandardCharsets.UTF_8).length, "a.html");
        when(draftHtml.findById(sceneId)).thenReturn(Optional.of(drifted));
        JsonNode manifest = om.createObjectNode();
        assertThrows(InvalidStatusTransitionException.class, () ->
                service.snapshotHtmlForVersion(sceneId, UUID.randomUUID(), manifest));
    }

    @Test
    void publishRejectsWhenManifestChecksumEdited() {
        // FIX-03 tâm điểm: manifest pin sha256/sizeBytes BỊ SỬA ngoài luồng
        // (PATCH draftJson trước khi normalize chạy, hoặc bug UI) — publish
        // phải refuse thay vì ship version mà Flutter sẽ reject.
        UUID sceneId = UUID.randomUUID();
        String content = com.dauviet.animation.manifest.HtmlSandbox.apply(HTML);
        byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
        String realSha = HtmlDocumentValidator.sha256(bytes);
        AnimationSceneHtml stored = new AnimationSceneHtml(sceneId, content,
                realSha, (long) bytes.length, "a.html");
        when(draftHtml.findById(sceneId)).thenReturn(Optional.of(stored));

        ObjectNode manifest = om.createObjectNode();
        ObjectNode html = manifest.putObject("html");
        html.put("sha256", "0".repeat(64));     // spoofed
        html.put("sizeBytes", bytes.length);
        assertThrows(InvalidStatusTransitionException.class, () ->
                service.snapshotHtmlForVersion(sceneId, UUID.randomUUID(), manifest));
    }

    @Test
    void publishSucceedsWhenChecksumMatches() {
        UUID sceneId = UUID.randomUUID();
        String content = com.dauviet.animation.manifest.HtmlSandbox.apply(HTML);
        byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
        String realSha = HtmlDocumentValidator.sha256(bytes);
        AnimationSceneHtml stored = new AnimationSceneHtml(sceneId, content,
                realSha, (long) bytes.length, "a.html");
        when(draftHtml.findById(sceneId)).thenReturn(Optional.of(stored));
        ObjectNode manifest = om.createObjectNode();
        ObjectNode html = manifest.putObject("html");
        html.put("sha256", realSha);
        html.put("sizeBytes", bytes.length);

        UUID versionId = UUID.randomUUID();
        service.snapshotHtmlForVersion(sceneId, versionId, manifest);
        ArgumentCaptor<AnimationSceneVersionHtml> cap =
                ArgumentCaptor.forClass(AnimationSceneVersionHtml.class);
        verify(versionHtml).save(cap.capture());
        assertEquals(versionId, cap.getValue().getVersionId());
        assertEquals(realSha, cap.getValue().getSha256());
        assertEquals((long) bytes.length, cap.getValue().getSizeBytes());
        assertEquals(content, cap.getValue().getContent());
    }

    @Test
    void publishRejectsMissingDraft() {
        UUID sceneId = UUID.randomUUID();
        when(draftHtml.findById(sceneId)).thenReturn(Optional.empty());
        assertThrows(InvalidStatusTransitionException.class, () ->
                service.snapshotHtmlForVersion(sceneId, UUID.randomUUID(),
                        om.createObjectNode()));
    }

    /* ---------- Duplicate keeps bytes + checksum ---------- */

    @Test
    void duplicateCopiesSameBytesAndChecksum() {
        UUID from = UUID.randomUUID(), to = UUID.randomUUID();
        String content = com.dauviet.animation.manifest.HtmlSandbox.apply(HTML);
        byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
        String sha = HtmlDocumentValidator.sha256(bytes);
        AnimationSceneHtml d = new AnimationSceneHtml(from, content, sha,
                (long) bytes.length, "a.html");
        when(draftHtml.findById(from)).thenReturn(Optional.of(d));
        service.copyDraftHtml(from, to);
        ArgumentCaptor<AnimationSceneHtml> cap =
                ArgumentCaptor.forClass(AnimationSceneHtml.class);
        verify(draftHtml).save(cap.capture());
        assertEquals(to, cap.getValue().getSceneId());
        assertEquals(content, cap.getValue().getContent());
        assertEquals(sha, cap.getValue().getSha256());
        assertEquals((long) bytes.length, cap.getValue().getSizeBytes());
    }

    /* ---------- Import: CSP meta injected into stored bytes ---------- */

    @Test
    void importStoresSandboxedBytesAndManifestPinMatches() {
        AnimationTemplate t = htmlTemplate(UUID.randomUUID());
        when(templates.findByCode(AnimationHtmlService.TEMPLATE_CODE))
                .thenReturn(Optional.of(t));
        when(scenes.saveAndFlush(any(AnimationScene.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(mapper.toSceneResponse(any(), any(), any())).thenReturn(null);

        MockMultipartFile file = new MockMultipartFile("file", "scene.html",
                "text/html", HTML.getBytes(StandardCharsets.UTF_8));
        service.importHtml(file, "Bạch Đằng", null, UUID.randomUUID());

        ArgumentCaptor<AnimationSceneHtml> cap =
                ArgumentCaptor.forClass(AnimationSceneHtml.class);
        verify(draftHtml).save(cap.capture());
        String stored = cap.getValue().getContent();
        assertTrue(stored.contains("Content-Security-Policy"),
                () -> "CSP meta phải nằm trong bytes lưu");
        // sha256/sizeBytes phải hash trên STORED form (đã inject), không
        // phải upload gốc — Flutter verify đúng bytes nó render.
        String expectSha = HtmlDocumentValidator.sha256(
                stored.getBytes(StandardCharsets.UTF_8));
        assertEquals(expectSha, cap.getValue().getSha256());
    }
}
