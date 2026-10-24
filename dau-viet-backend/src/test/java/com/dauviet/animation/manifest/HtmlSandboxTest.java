package com.dauviet.animation.manifest;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * FIX-01B: CSP must travel INSIDE the stored bytes — response-header CSP
 * doesn't apply once bytes go through loadHtmlString/blob URL.
 */
class HtmlSandboxTest {

    @Test
    void injectsMetaAsFirstHeadChild() {
        String out = HtmlSandbox.apply(
                "<!doctype html><html><head><meta charset=\"utf-8\">"
                        + "<title>t</title></head><body></body></html>");
        int headEnd = out.indexOf("<head>") + "<head>".length();
        assertTrue(out.substring(headEnd).startsWith(
                "<meta http-equiv=\"Content-Security-Policy\""),
                () -> "meta not first in head: " + out.substring(headEnd));
    }

    @Test
    void injectsHeadWhenMissing() {
        String out = HtmlSandbox.apply(
                "<html><body><canvas></canvas></body></html>");
        assertTrue(out.contains("<head><meta http-equiv=\"Content-Security-Policy\""));
    }

    @Test
    void prependsWhenNoHtmlTag() {
        String out = HtmlSandbox.apply("<div>fragment</div>");
        assertTrue(out.startsWith("<meta http-equiv=\"Content-Security-Policy\""));
    }

    @Test
    void stripsAuthorDeclaredCsp() {
        // Author CSP can only widen — never let it stand.
        String body = "<html><head>"
                + "<meta http-equiv=\"Content-Security-Policy\" "
                + "content=\"default-src *\">"
                + "</head><body></body></html>";
        String out = HtmlSandbox.apply(body);
        assertFalse(out.contains("default-src *"));
        assertTrue(out.contains("connect-src 'none'"));
        // Exactly one CSP meta remains (ours).
        int first = out.indexOf("Content-Security-Policy");
        assertEquals(-1, out.indexOf("Content-Security-Policy", first + 1));
    }

    @Test
    void policyCoversRequiredDirectives() {
        String c = HtmlSandbox.CSP;
        for (String d : new String[]{
                "default-src 'none'", "script-src", "style-src", "img-src data:",
                "media-src data:", "font-src data:", "connect-src 'none'",
                "frame-src 'none'", "object-src 'none'", "form-action 'none'",
                "base-uri 'none'", "frame-ancestors 'none'"}) {
            assertTrue(c.contains(d), () -> "missing directive: " + d);
        }
    }

    @Test
    void blankPassthrough() {
        assertEquals("", HtmlSandbox.apply(""));
        assertEquals(null, HtmlSandbox.apply(null));
    }

    @Test
    void idempotent() {
        String once = HtmlSandbox.apply(
                "<html><head></head><body></body></html>");
        String twice = HtmlSandbox.apply(once);
        int first = twice.indexOf("Content-Security-Policy");
        assertEquals(-1, twice.indexOf("Content-Security-Policy", first + 1));
    }
}
