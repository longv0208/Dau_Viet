package com.dauviet.animation.manifest;

import java.nio.charset.StandardCharsets;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import com.dauviet.animation.domain.AnimationExceptions.ManifestFieldError;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Unit tests for the self-contained HTML upload contract. */
class HtmlDocumentValidatorTest {

    private HtmlDocumentValidator validator;

    @BeforeEach
    void setUp() {
        validator = new HtmlDocumentValidator(15 * 1024 * 1024);
    }

    private MockMultipartFile file(String name, String body) {
        return new MockMultipartFile(
                "file", name, "text/html", body.getBytes(StandardCharsets.UTF_8));
    }

    private List<ManifestFieldError> check(String name, String body) {
        return validator.validateUpload(name, "text/html",
                body.getBytes(StandardCharsets.UTF_8));
    }

    private static String valid() {
        return """
                <!doctype html><html><head><meta charset="utf-8">
                <style>body{margin:0}</style></head>
                <body><canvas id="c"></canvas>
                <script>document.getElementById('c');</script>
                </body></html>
                """;
    }

    @Test
    void acceptsSelfContainedHtml() {
        List<ManifestFieldError> errs = check("bach-dang.html", valid());
        assertTrue(errs.isEmpty(), () -> "unexpected errors: " + errs);
    }

    @Test
    void rejectsNonHtmlExtension() {
        List<ManifestFieldError> errs = check("anim.zip", valid());
        assertFalse(errs.isEmpty());
    }

    @Test
    void rejectsExternalScriptSrc() {
        String body = "<html><head><script src=\"https://cdn.example.com/x.js\"></script>"
                + "</head><body></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsExternalStylesheetLink() {
        String body = "<html><head><link rel=\"stylesheet\" href=\"https://x.co/a.css\">"
                + "</head><body></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsRemoteImage() {
        String body = "<html><body><img src=\"https://img.example.com/p.png\"></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsRelativeAssetPath() {
        String body = "<html><body><img src=\"./images/map.png\"></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsFetchCall() {
        String body = "<html><body><script>fetch('/api/x');</script></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsIframeAndForm() {
        String body = "<html><body><iframe src=\"x\"></iframe><form></form></body></html>";
        List<ManifestFieldError> errs = check("a.html", body);
        assertFalse(errs.isEmpty());
    }

    @Test
    void rejectsLocalStorage() {
        String body = "<html><body><script>localStorage.setItem('a','b');</script></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void acceptsDataUriMedia() {
        String body = "<html><body><img src=\"data:image/png;base64,iVBOR\">"
                + "<video src=\"data:video/mp4;base64,AAAA\"></video></body></html>";
        assertTrue(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsMissingHtmlRoot() {
        String body = "<div>không phải html</div>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsInvalidUtf8() {
        byte[] bad = {(byte) 0xC3, 0x28}; // invalid UTF-8 seq
        List<ManifestFieldError> errs = validator.validateUpload(
                "a.html", "text/html", bad);
        assertFalse(errs.isEmpty());
    }

    @Test
    void rejectsOversize() {
        HtmlDocumentValidator small = new HtmlDocumentValidator(64);
        List<ManifestFieldError> errs = small.validateUpload(
                "a.html", "text/html",
                valid().getBytes(StandardCharsets.UTF_8));
        assertFalse(errs.isEmpty());
    }

    @Test
    void validatesMultipartAndComputesSha256() throws Exception {
        var result = validator.validate(file("scene.html", valid()));
        assertEquals("scene.html", result.filename());
        assertEquals(64, result.sha256().length());
        assertTrue(result.sizeBytes() > 0);
    }

    @Test
    void capsErrorList() {
        StringBuilder body = new StringBuilder("<html><body>");
        for (int i = 0; i < 30; i++) {
            body.append("<script>fetch('/x").append(i).append("');</script>\n");
        }
        body.append("</body></html>");
        List<ManifestFieldError> errs = check("a.html", body.toString());
        // Cap = 10 lỗi chi tiết + 1 dòng tóm tắt "...và nhiều tham chiếu khác".
        assertTrue(errs.size() <= 11, () -> "errors: " + errs.size());
    }

    /* ---------- FIX-01 regression: skip-line bug + new vectors ---------- */

    @Test
    void doctypeOnSameLineDoesNotMaskExternalScript() {
        // Trước fix: dòng chứa "doctype" bị skip toàn bộ → <script src> lọt.
        String body = "<!doctype html><script src=\"https://evil/x.js\"></script>"
                + "<html><body></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void xmlnsOnSameLineDoesNotMaskScriptSrc() {
        // xmlns hợp lệ nhưng cùng dòng có script external → vẫn phải báo.
        String body = "<html><body>"
                + "<svg xmlns=\"http://www.w3.org/2000/svg\">"
                + "<script src=\"https://evil/x.js\"></script></svg>"
                + "</body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void acceptsInlineSvgWithXmlns() {
        String body = "<html><body>"
                + "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\">"
                + "<circle cx=\"5\" cy=\"5\" r=\"4\"/></svg>"
                + "</body></html>";
        List<ManifestFieldError> errs = check("a.html", body);
        assertTrue(errs.isEmpty(), () -> "unexpected: " + errs);
    }

    @Test
    void acceptsXlinkNamespaceDeclaration() {
        String body = "<html><body>"
                + "<svg xmlns=\"http://www.w3.org/2000/svg\" "
                + "xmlns:xlink=\"http://www.w3.org/1999/xlink\">"
                + "<use xlink:href=\"#shape\"/></svg>"
                + "<defs><path id=\"shape\"/></defs></body></html>";
        assertTrue(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsCssExternalUrl() {
        String body = "<html><head><style>"
                + "body{background:url(https://cdn.example.com/bg.png)}"
                + "</style></head><body></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void acceptsCssDataUriAndFragmentRefs() {
        String body = "<html><head><style>"
                + "a{background:url(data:image/png;base64,iVBOR)}"
                + ".f{filter:url(#blur)}"
                + "</style></head><body></body></html>";
        assertTrue(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsDynamicImport() {
        String body = "<html><body><script>const m = import('./chunk.js');</script>"
                + "</body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsWebSocketAndEventSource() {
        String body = "<html><body><script>"
                + "const ws = new WebSocket('wss://x');"
                + "</script></body></html>";
        assertFalse(check("a.html", body).isEmpty());
        String body2 = "<html><body><script>"
                + "const es = new EventSource('/sse');"
                + "</script></body></html>";
        assertFalse(check("b.html", body2).isEmpty());
    }

    @Test
    void rejectsWindowOpenAndLocationAssign() {
        String body = "<html><body><script>window.open('https://x');</script>"
                + "</body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsObjectEmbed() {
        String body = "<html><body><object data=\"x.swf\"></object>"
                + "<embed src=\"x.swf\"></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void rejectsUnquotedExternalSrc() {
        String body = "<html><body><img src=https://img.example.com/p.png></body></html>";
        assertFalse(check("a.html", body).isEmpty());
    }

    @Test
    void acceptsInlineScriptStyle() {
        String body = "<html><head><style>"
                + "body{margin:0;font-family:system-ui}</style></head>"
                + "<body><canvas id=\"c\"></canvas>"
                + "<script>const c=document.getElementById('c');"
                + "const x=c.getContext('2d');x.fillRect(0,0,9,9);</script>"
                + "</body></html>";
        assertTrue(check("a.html", body).isEmpty());
    }
}
