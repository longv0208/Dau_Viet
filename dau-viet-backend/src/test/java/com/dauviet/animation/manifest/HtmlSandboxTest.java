package com.dauviet.animation.manifest;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * FIX-01: CSP position must be resolved by DOM structure, not text.
 * Every test RE-PARSES the serialized output and asserts the meta is
 * head's first element child — `contains()` is not proof.
 */
class HtmlSandboxTest {

    /** Assert: output parses, head exists, first element child is our meta. */
    private static Document assertCspFirstInHead(String out) {
        Document doc = Jsoup.parse(out);
        Element head = doc.head();
        assertNotNull(head, () -> "no <head> in output: " + out);
        assertFalse(head.children().isEmpty(), () -> "empty <head>");
        Element first = head.children().get(0);
        assertEquals("meta", first.tagName().toLowerCase());
        assertEquals("content-security-policy",
                first.attr("http-equiv").toLowerCase());
        assertEquals(HtmlSandbox.CSP, first.attr("content"));
        // Exactly one CSP meta in the whole document.
        assertEquals(1, cspMetas(doc).size());
        return doc;
    }

    private static Elements cspMetas(Document doc) {
        Elements out = new Elements();
        for (Element m : doc.select("meta[http-equiv]")) {
            if ("content-security-policy".equalsIgnoreCase(
                    m.attr("http-equiv").trim())) {
                out.add(m);
            }
        }
        return out;
    }

    @Test
    void normalHead_injectsFirst() {
        String out = HtmlSandbox.apply(
                "<!doctype html><html><head><meta charset=\"utf-8\">"
                        + "<title>t</title></head><body></body></html>");
        Document doc = assertCspFirstInHead(out);
        // charset meta survives, right after our CSP meta.
        assertEquals("utf-8",
                doc.head().children().get(1).attr("charset").toLowerCase());
    }

    @Test
    void missingHead_isSynthesized() {
        String out = HtmlSandbox.apply(
                "<html><body><canvas></canvas></body></html>");
        Document doc = assertCspFirstInHead(out);
        assertEquals(1, doc.select("canvas").size());
    }

    @Test
    void commentContainingFakeHead_doesNotFoolInjection() {
        String out = HtmlSandbox.apply(
                "<html><!-- <head><meta http-equiv=\"x\"> --><head>"
                        + "<title>real</title></head><body></body></html>");
        Document doc = assertCspFirstInHead(out);
        // Comment text stays a comment — no meta got planted inside it.
        assertEquals(1, cspMetas(doc).size());
    }

    @Test
    void scriptStringContainingHead_doesNotBreakInjection() {
        String out = HtmlSandbox.apply(
                "<html><body><script>const s = \"<head>fake</head>\";</script>"
                        + "</body></html>");
        assertCspFirstInHead(out);
        assertTrue(out.contains("\"<head>fake</head>\""),
                () -> "JS string must survive verbatim");
    }

    @Test
    void templateLiteralContainingHead_verbatim() {
        String out = HtmlSandbox.apply(
                "<html><body><script>const t = `<head>x</head>`;</script>"
                        + "</body></html>");
        assertCspFirstInHead(out);
        assertTrue(out.contains("`<head>x</head>`"));
    }

    @Test
    void manyCommentsBeforeRealHead_stillFirstChild() {
        String out = HtmlSandbox.apply(
                "<html><!-- a <head> --><!-- b </head> --><!-- c --><head>"
                        + "<style>body{}</style></head><body></body></html>");
        assertCspFirstInHead(out);
    }

    @Test
    void authorDeclaredCsp_isReplaced() {
        String out = HtmlSandbox.apply(
                "<html><head><meta http-equiv=\"Content-Security-Policy\" "
                        + "content=\"default-src *\"></head><body></body></html>");
        Document doc = assertCspFirstInHead(out);
        assertFalse(doc.html().contains("default-src *"));
    }

    @Test
    void inlineSvgAndDataUri_survive() {
        String out = HtmlSandbox.apply(
                "<html><body><svg xmlns=\"http://www.w3.org/2000/svg\">"
                        + "<circle r=\"4\"/></svg>"
                        + "<img src=\"data:image/png;base64,"
                        + "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo=\"></body></html>");
        assertCspFirstInHead(out);
        assertTrue(out.contains("data:image/png;base64,"));
        assertTrue(out.contains("<circle"));
    }

    @Test
    void vietnameseText_survivesRoundTrip() {
        String out = HtmlSandbox.apply(
                "<html><head><meta charset=\"utf-8\"></head>"
                        + "<body><p>Trận Bạch Đằng 938 — Ngô Quyền đánh đuổi quân Nam Hán.</p>"
                        + "</body></html>");
        assertCspFirstInHead(out);
        assertTrue(out.contains("Bạch Đằng"), () -> "mất dấu tiếng Việt");
        assertTrue(out.contains("đuổi"), () -> "mất ký tự Unicode");
    }

    @Test
    void malformedHtml_stillGetsCspOrFailsClosed() {
        // Pathological nesting — parser normalizes or we throw; either
        // way nothing unverified ships. This fixture is recoverable.
        String out = HtmlSandbox.apply(
                "<html><head><body><p>broken");
        assertCspFirstInHead(out);
    }

    @Test
    void alreadyInjected_isIdempotent() {
        String once = HtmlSandbox.apply(
                "<html><head></head><body></body></html>");
        String twice = HtmlSandbox.apply(once);
        assertCspFirstInHead(twice);
    }

    @Test
    void blankPassthrough() {
        assertEquals("", HtmlSandbox.apply(""));
        assertEquals(null, HtmlSandbox.apply(null));
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
    void metaIsRealDomNode_notJustSubstring() {
        // A text-level check could pass while the meta sits inside a
        // comment/CDATA. Walk the DOM: the element must be an Element in
        // head, position 0 — proven by the parser, not by string scan.
        String out = HtmlSandbox.apply(
                "<html><head></head><body><!-- <meta http-equiv=\"Content-"
                        + "Security-Policy\"> --></body></html>");
        Document doc = assertCspFirstInHead(out);
        Element meta = doc.head().children().get(0);
        assertTrue(meta.parent() == doc.head());
    }
}
