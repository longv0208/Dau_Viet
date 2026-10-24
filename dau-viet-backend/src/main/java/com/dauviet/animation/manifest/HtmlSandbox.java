package com.dauviet.animation.manifest;

import java.util.List;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;

/**
 * Injects a restrictive Content-Security-Policy <meta> tag into the HTML
 * document itself. The response-header CSP (set by the controllers) only
 * guards the fetch RESPONSE — once bytes are handed to a WebView via
 * loadHtmlString or to an iframe via blob URL there IS no response any
 * more, so the policy must travel inside the document.
 *
 * Position is resolved by a real HTML5 parser (Jsoup), NOT regex on raw
 * text — a "<head>" substring inside a comment, a JS string, or a
 * template literal would defeat a text-level search and silently place
 * the policy where the browser never sees it. After injection the output
 * is re-parsed to PROVE the meta sits as the first element child of
 * head; any failure throws (fail closed — nothing unverifiable ships).
 *
 * Meta-note: `frame-ancestors` is inert inside a CSP <meta> (it only
 * works in an HTTP response header). It's kept here for the shared
 * header string; the meta injection is the enforcement that travels
 * with the bytes.
 */
public final class HtmlSandbox {

    /** The policy string — single source of truth for meta + header. */
    public static final String CSP =
            "default-src 'none'; "
                    + "script-src 'unsafe-inline'; "
                    + "style-src 'unsafe-inline'; "
                    + "img-src data:; "
                    + "media-src data:; "
                    + "font-src data:; "
                    + "connect-src 'none'; "
                    + "frame-src 'none'; "
                    + "object-src 'none'; "
                    + "form-action 'none'; "
                    + "base-uri 'none'; "
                    + "frame-ancestors 'none'";

    private HtmlSandbox() {
    }

    /**
     * Returns the document with the sandbox CSP meta installed as the
     * first element child of <head>. Removes author-declared CSP metas
     * (they can only widen — never allowed to stand). Preserves charset
     * meta, inline script/style bodies, SVG and data URIs verbatim.
     *
     * @throws IllegalStateException when the injected document can't be
     *         proven correct (parse produced no head, meta not first,
     *         or an author CSP meta survived) — fail closed.
     */
    public static String apply(String html) {
        if (html == null || html.isBlank()) return html;

        Document doc = Jsoup.parse(html);
        // Keep UTF-8 + the original (un-pretty-printed) HTML structure so
        // Vietnamese text and inline bytes survive the round-trip.
        doc.outputSettings()
                .charset(java.nio.charset.StandardCharsets.UTF_8)
                .prettyPrint(false);

        Element head = doc.head();   // Jsoup synthesizes head when absent
        if (head == null) {
            throw new IllegalStateException(
                    "HTML sandbox: cannot locate/create <head> — refusing to "
                            + "ship an unverifiable document");
        }

        // Remove every author-provided CSP meta anywhere in the document
        // (head or stray) — a looser author policy must not stand.
        for (Element m : cspMetas(doc)) {
            m.remove();
        }

        Element meta = doc.createElement("meta");
        meta.attr("http-equiv", "Content-Security-Policy");
        meta.attr("content", CSP);
        head.prependChild(meta);

        String out = doc.outerHtml();
        verify(out);
        return out;
    }

    /**
     * Re-parse the serialized output and prove the CSP meta is the first
     * element child of the real <head>, and no other CSP meta remains.
     * Structural proof — not `contains()`.
     */
    private static void verify(String out) {
        Document reparsed = Jsoup.parse(out);
        Element head = reparsed.head();
        if (head == null) {
            throw new IllegalStateException(
                    "HTML sandbox: re-parse produced no <head>");
        }
        List<Element> kids = head.children();
        if (kids.isEmpty()
                || !"meta".equalsIgnoreCase(kids.get(0).tagName())
                || !"content-security-policy".equalsIgnoreCase(
                        kids.get(0).attr("http-equiv"))
                || !CSP.equals(kids.get(0).attr("content"))) {
            throw new IllegalStateException(
                    "HTML sandbox: injected CSP meta is not first in <head>");
        }
        Elements leftover = cspMetas(reparsed);
        if (leftover.size() != 1) {
            throw new IllegalStateException(
                    "HTML sandbox: " + leftover.size()
                            + " CSP metas present after injection (expected 1)");
        }
    }

    /** All <meta http-equiv="content-security-policy"> — attr value
     * compared case-insensitively (jsoup's `=value` is exact-match). */
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

    /**
     * Whether the document already carries our exact CSP meta as head's
     * first element child — used to skip re-injection on already-applied
     * documents (idempotent apply() makes this mostly informational).
     */
    public static boolean hasConflictingCsp(String html) {
        if (html == null) return false;
        Document doc = Jsoup.parse(html);
        for (Element m : cspMetas(doc)) {
            if (!CSP.equals(m.attr("content"))) return true;
        }
        return false;
    }
}
