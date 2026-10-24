package com.dauviet.animation.manifest;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Injects a restrictive Content-Security-Policy <meta> tag into the HTML
 * document itself. The response-header CSP (set by the controllers) only
 * guards the fetch RESPONSE — once bytes are handed to a WebView via
 * loadHtmlString or to an iframe via blob URL there IS no response any
 * more, so the policy must travel inside the document.
 *
 * Policy (mirrors the header, plus the extra directives the header set
 * didn't cover):
 *   default-src 'none'        — deny by default
 *   script-src 'unsafe-inline' — animation needs inline JS; no network
 *   style-src 'unsafe-inline'  — inline CSS needed; external blocked anyway
 *   img-src data:              — only embedded media
 *   media-src data:            — only embedded audio/video
 *   font-src data:             — only embedded fonts
 *   connect-src 'none'         — no fetch/XHR/WebSocket/EventSource/beacon
 *   frame-src 'none'           — no nested browsing contexts
 *   object-src 'none'          — no <object>/<embed>
 *   form-action 'none'         — no form submission
 *   base-uri 'none'            — no <base> re-basing
 *   frame-ancestors 'none'     — cannot be embedded (defense-in-depth)
 *
 * The injected meta is placed as the FIRST child of <head> so it applies
 * before any subresource the document might otherwise request. If the
 * author already declared a CSP meta we REPLACE it — author policy can
 * only widen, never tighten, so we don't let it stand.
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

    private static final Pattern EXISTING_CSP_META = Pattern.compile(
            "<meta[^>]+http-equiv\\s*=\\s*[\"']?content-security-policy[\"']?[^>]*>",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern HEAD_OPEN = Pattern.compile(
            "<head[^>]*>", Pattern.CASE_INSENSITIVE);
    private static final Pattern HTML_OPEN = Pattern.compile(
            "<html[^>]*>", Pattern.CASE_INSENSITIVE);

    private HtmlSandbox() {
    }

    /**
     * Returns the document with the sandbox CSP meta installed. Removes
     * any author-declared CSP meta first (it can only be more permissive).
     */
    public static String apply(String html) {
        if (html == null || html.isBlank()) return html;
        String out = EXISTING_CSP_META.matcher(html).replaceAll("");
        String meta = "<meta http-equiv=\"Content-Security-Policy\" content=\""
                + CSP + "\">";
        Matcher head = HEAD_OPEN.matcher(out);
        if (head.find()) {
            return out.substring(0, head.end()) + meta + out.substring(head.end());
        }
        // No <head> — inject a minimal one after <html>.
        Matcher htmlTag = HTML_OPEN.matcher(out);
        if (htmlTag.find()) {
            return out.substring(0, htmlTag.end())
                    + "<head>" + meta + "</head>" + out.substring(htmlTag.end());
        }
        // Degenerate document — prepend.
        return meta + out;
    }

    /**
     * Rejects documents whose markup would defeat the meta (e.g. a CSP
     * meta the author set that we couldn't remove — belt-and-suspenders
     * check for pathological tag shapes the regex might miss).
     */
    public static boolean hasConflictingCsp(String html) {
        if (html == null) return false;
        Matcher m = Pattern.compile("content-security-policy",
                Pattern.CASE_INSENSITIVE).matcher(html);
        while (m.find()) {
            int start = Math.max(0, m.start() - 200);
            String before = html.substring(start, m.start()).toLowerCase(Locale.ROOT);
            if (!before.contains("http-equiv")) {
                // "content-security-policy" appearing as JS/CSS text, not a
                // meta http-equiv — that's fine.
                continue;
            }
            return true; // leftover meta http-equiv CSP — we strip these
        }
        return false;
    }
}
