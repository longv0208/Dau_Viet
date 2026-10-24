package com.dauviet.animation.manifest;

import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import com.dauviet.animation.domain.AnimationExceptions.ManifestFieldError;

/**
 * Validates an uploaded single-file HTML animation: must be a non-empty,
 * UTF-8, self-contained document. External dependencies (remote URLs,
 * relative file paths, dynamic imports, meta refresh, base href) are
 * rejected with the offending line so the admin can fix and re-upload.
 * Runs BEFORE persistence — invalid bytes never reach the database.
 */
@Component
public class HtmlDocumentValidator {

    /** Result of a successful validation — content already decoded UTF-8. */
    public record ValidatedHtml(String content, String sha256, long sizeBytes,
                                String filename) {
    }

    /**
     * External-reference patterns. Each: pattern + Vietnamese message.
     * Matched case-insensitively against the decoded document.
     */
    private static final List<Rule> EXTERNAL_RULES = List.of(
            new Rule("<script[^>]+src\\s*=",
                    "Thẻ <script src> tải mã từ bên ngoài — nhúng JavaScript trực tiếp vào file."),
            new Rule("<link[^>]+href\\s*=",
                    "Thẻ <link href> tải tài nguyên ngoài — nhúng CSS vào <style>."),
            new Rule("(?:src|href)\\s*=\\s*[\"']?\\s*(https?:)?//",
                    "Tham chiếu URL ngoài (http/https hoặc protocol-relative) — file phải tự chứa."),
            new Rule("(?:src|href)\\s*=\\s*[\"']\\s*\\.\\.?/",
                    "Đường dẫn tương đối (./ hoặc ../) — không có thư mục assets đi kèm."),
            new Rule("url\\(\\s*[\"']?\\s*(?!data:|#|none\\b|inherit\\b|initial\\b|unset\\b)[^d]",
                    "url() trong CSS trỏ tới tài nguyên ngoài — dùng data: URI."),
            new Rule("url\\(\\s*[\"']?\\s*(https?:)?//",
                    "url() trong CSS trỏ tới URL ngoài — dùng data: URI."),
            new Rule("(?:src|href)\\s*=\\s*[\"'][a-zA-Z0-9_\\-.]+\\.(?:png|jpe?g|gif|webp|svg|css|js|json|mp3|wav|ogg|mp4|woff2?)[\"']",
                    "Tham chiếu file cục bộ — nhúng trực tiếp (data: URI hoặc inline)."),
            new Rule("@import\\s",
                    "@import tải stylesheet ngoài — nhúng CSS vào <style>."),
            new Rule("\\bfetch\\s*\\(",
                    "fetch() tải tài nguyên mạng — hoạt họa phải tự chứa hoàn toàn."),
            new Rule("\\bXMLHttpRequest\\b",
                    "XMLHttpRequest tải tài nguyên mạng — hoạt họa phải tự chứa hoàn toàn."),
            new Rule("import\\s*\\(\\s*[\"'](https?:|//|\\.)",
                    "Dynamic import tải mã ngoài — nhúng JavaScript vào file."),
            new Rule("<base\\s+[^>]*href",
                    "<base href> đổi gốc tài nguyên — không được phép."),
            new Rule("<meta[^>]+http-equiv\\s*=\\s*[\"']?refresh",
                    "<meta http-equiv=refresh> điều hướng tự động — không được phép."),
            new Rule("<iframe\\b",
                    "<iframe> nhúng tài liệu khác — không được phép."),
            new Rule("<form\\b",
                    "<form> gửi dữ liệu ra ngoài — không được phép."),
            new Rule("\\bnavigator\\.(sendBeacon|share)\\b",
                    "Gọi API trình duyệt gửi dữ liệu ra ngoài — không được phép."),
            new Rule("\\b(openDatabase|indexedDB\\.open|localStorage|sessionStorage|caches\\.open|serviceWorker)\\b",
                    "Lưu trữ cục bộ/service worker trong WebView — không được phép."),
            new Rule("\\bnew\\s+(WebSocket|EventSource|RTCPeerConnection)\\b|\\bWebSocket\\s*\\(",
                    "Kết nối mạng bất đồng bộ (WebSocket/EventSource/RTC) — không được phép."),
            new Rule("\\bwindow\\.open\\s*\\(|\\btop\\.location\\b|\\bparent\\.location\\b|\\blocation\\.(assign|replace|href\\s*=)",
                    "Điều hướng/popup ra ngoài tài liệu — không được phép."),
            new Rule("import\\s*\\(\\s*[\"'`]",
                    "Dynamic import tải mã ngoài — nhúng JavaScript vào file."),
            new Rule("\\bimport\\s+[^'\"]*from\\s*[\"'](https?:|//|\\.)",
                    "ES-module import từ URL/tương đối — nhúng vào file."),
            new Rule("<object\\b|<embed\\b|<applet\\b",
                    "<object>/<embed>/<applet> nhúng plugin/tài liệu ngoài — không được phép."),
            new Rule("<(?:video|audio|source|img)[^>]+src\\s*=\\s*[\"']\\s*(?!data:|#)",
                    "<video>/<audio>/<source>/<img> src tải media ngoài — nhúng data: URI."),
            new Rule("\\b(beacon|report-uri|ReportingObserver)\\b",
                    "API báo cáo/telemetry ra ngoài — không được phép."));

    private record Rule(String regex, String message) {
        Pattern pattern() {
            return Pattern.compile(regex, Pattern.CASE_INSENSITIVE);
        }
    }

    /**
     * Attribute-scoped reference checks: applied per (src|href|xlink:href)
     * ATTRIBUTE VALUE, not per line — a valid `xmlns="http://www.w3.org/…"`
     * declaration on the same line/tag must not mask a dangerous `src=`.
     * Extracts the value, then applies VALUE_RULES.
     */
    private static final Pattern REF_ATTR = Pattern.compile(
            "(?:\\s|^)(?:src|href|xlink:href|poster|data|action|formaction|background)"
                    + "\\s*=\\s*([\"'])(.*?)\\1",
            Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
    private static final Pattern REF_ATTR_UNQUOTED = Pattern.compile(
            "(?:\\s|^)(?:src|href|xlink:href|poster|data|action|formaction|background)"
                    + "\\s*=\\s*([^\\s>]+)",
            Pattern.CASE_INSENSITIVE);

    /** Value-level rules — checked on the extracted attribute value. */
    private static final List<Rule> ATTR_VALUE_RULES = List.of(
            new Rule("^(https?:)?//",
                    "URL ngoài (http/https/protocol-relative) — file phải tự chứa."),
            new Rule("^\\./|^\\.\\./|^[a-zA-Z0-9_\\-.]+\\.(png|jpe?g|gif|webp|svg|css|js|json|mp3|wav|ogg|mp4|woff2?)$",
                    "Đường dẫn tương đối/file cục bộ — nhúng trực tiếp (data: URI hoặc inline)."),
            new Rule("^javascript:",
                    "URL javascript: — không được phép."));

    /**
     * CSS url() per-value check: allows only data: URIs, fragment refs
     * (#id used by SVG filters/gradients) and CSS keywords; everything
     * else is an external fetch.
     */
    private static final Pattern CSS_URL = Pattern.compile(
            "url\\(\\s*([\"']?)(.*?)\\1\\s*\\)", Pattern.CASE_INSENSITIVE);

    /** Namespaces that are inert declarations — NOT fetchable deps. */
    private static final Pattern SVG_NS_OK = Pattern.compile(
            "xmlns(:\\w+)?\\s*=\\s*[\"'](http://www\\.w3\\.org/"
                    + "(1999/xhtml|2000/svg|1999/xlink|1998/Math/MathML))[\"']",
            Pattern.CASE_INSENSITIVE);

    private final long maxBytes;

    public HtmlDocumentValidator(
            @Value("${dauviet.animations.html.max-bytes:15728640}") long maxBytes) {
        this.maxBytes = maxBytes;
    }

    /** Validate an uploaded multipart file. Throws nothing — returns errors. */
    public List<ManifestFieldError> validateUpload(String filename, String mime,
                                                 byte[] bytes) {
        List<ManifestFieldError> errors = new ArrayList<>();
        String fn = filename == null ? "" : filename;

        // (1) extension
        String lower = fn.toLowerCase(Locale.ROOT);
        if (!lower.endsWith(".html") && !lower.endsWith(".htm")) {
            errors.add(err("file", "BAD_EXTENSION",
                    "Chỉ chấp nhận file .html (đã nhận: '" + fn + "')."));
        }

        // (2) declared MIME (lenient — sniff is authoritative)
        if (mime != null && !mime.isBlank()) {
            String m = mime.toLowerCase(Locale.ROOT);
            if (!m.startsWith("text/html") && !m.startsWith("text/plain")
                    && !m.equals("application/octet-stream")) {
                errors.add(err("file", "BAD_MIME",
                        "Loại file không hợp lệ: " + mime));
            }
        }

        // (3) non-empty + size bound
        if (bytes == null || bytes.length == 0) {
            errors.add(err("file", "EMPTY", "File rỗng."));
            return errors;
        }
        if (bytes.length > maxBytes) {
            errors.add(err("file", "TOO_LARGE",
                    "File vượt giới hạn " + (maxBytes / (1024 * 1024)) + " MB."));
            return errors;
        }

        // (4) strict UTF-8
        String content;
        try {
            content = StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes)).toString();
        } catch (CharacterCodingException e) {
            errors.add(err("file", "BAD_ENCODING",
                    "File không phải UTF-8 hợp lệ."));
            return errors;
        }

        // (5) looks like HTML
        if (!Pattern.compile("<html|<!doctype", Pattern.CASE_INSENSITIVE)
                .matcher(content).find()) {
            errors.add(err("file", "NOT_HTML",
                    "Nội dung không giống tài liệu HTML (thiếu <html>/<!doctype>)."));
            return errors;
        }

        // (6) external dependency checks. Two passes:
        //   a) Line-scoped EXTERNAL_RULES on tag/JS text — catches
        //      constructs like <iframe>, fetch(, <script src=.
        //      xmlns/doctype on the SAME line no longer skips the whole
        //      line — each rule matches the dangerous token directly.
        //   b) Attribute-scoped value checks — every src/href/xlink:href
        //      value is extracted and validated on its own, so a legal
        //      xmlns="http://www.w3.org/2000/svg" can't mask a sibling
        //      src="https://evil".
        int line = 1;
        int reported = 0;
        final int MAX_REPORTED = 10;
        outer:
        for (String l : content.split("\n", -1)) {
            String trimmed = l.trim();
            // Strip inert xmlns declarations before running rules so a
            // legit xmlns attr can't shadow a dangerous attr on the line.
            String scrubbed = SVG_NS_OK.matcher(trimmed).replaceAll("xmlns=\"\"");
            for (Rule rule : EXTERNAL_RULES) {
                if (rule.pattern().matcher(scrubbed).find()) {
                    reported += reportErr(errors, line, rule.message(), trimmed);
                    if (reported >= MAX_REPORTED) break outer;
                    break; // one error per line is enough for the admin
                }
            }
            for (String value : extractRefAttrValues(scrubbed)) {
                for (Rule rule : ATTR_VALUE_RULES) {
                    if (rule.pattern().matcher(value).find()) {
                        reported += reportErr(errors, line, rule.message(),
                                value.length() > 80 ? value.substring(0, 80) + "…" : value);
                        if (reported >= MAX_REPORTED) break outer;
                        break;
                    }
                }
            }
            for (String value : extractCssUrls(scrubbed)) {
                if (isExternalCssUrl(value)) {
                    reported += reportErr(errors, line,
                            "url() trong CSS trỏ tới tài nguyên ngoài — dùng data: URI.",
                            "url(" + (value.length() > 70 ? value.substring(0, 70) + "…" : value) + ")");
                    if (reported >= MAX_REPORTED) break outer;
                }
            }
            line++;
        }
        if (reported >= MAX_REPORTED) {
            errors.add(err("html", "EXTERNAL_REF",
                    "...và nhiều tham chiếu ngoài khác (hiển thị 10 lỗi đầu)."));
        }
        return errors;
    }

    private static int reportErr(List<ManifestFieldError> errors, int line,
                                 String message, String snippet) {
        String s = snippet.length() > 90 ? snippet.substring(0, 90) + "…" : snippet;
        errors.add(err("html", "EXTERNAL_REF",
                "Dòng " + line + ": " + message + " — " + s));
        return 1;
    }

    /** Extract values of every ref-carrying attribute (quoted + unquoted). */
    private static List<String> extractRefAttrValues(String text) {
        List<String> out = new ArrayList<>();
        Matcher m = REF_ATTR.matcher(text);
        while (m.find()) out.add(m.group(2));
        Matcher m2 = REF_ATTR_UNQUOTED.matcher(text);
        while (m2.find()) out.add(m2.group(1));
        return out;
    }

    private static List<String> extractCssUrls(String text) {
        List<String> out = new ArrayList<>();
        Matcher m = CSS_URL.matcher(text);
        while (m.find()) out.add(m.group(2).trim());
        return out;
    }

    /**
     * url() is external unless it's a data: URI, an in-document #fragment
     * (SVG filter/gradient refs), or a CSS keyword (none/inherit/…).
     */
    private static boolean isExternalCssUrl(String value) {
        if (value.isEmpty()) return false;
        String v = value.toLowerCase(Locale.ROOT);
        if (v.startsWith("data:") || v.startsWith("#")) return false;
        if (v.equals("none") || v.equals("inherit") || v.equals("initial")
                || v.equals("unset")) return false;
        // Anything that looks like a URL or a file path is external.
        return v.startsWith("http") || v.startsWith("//")
                || v.startsWith(".") || v.contains("/")
                || v.matches(".*\\.(png|jpe?g|gif|webp|svg|css|js|json|mp3|wav|ogg|mp4|woff2?|ttf|otf|eot)$");
    }

    /** Convenience: validate a MultipartFile end-to-end. */
    public ValidatedHtml validate(MultipartFile file) {
        byte[] bytes;
        try {
            bytes = file.getBytes();
        } catch (java.io.IOException e) {
            throw new com.dauviet.animation.domain.AnimationExceptions
                    .HtmlValidationException(List.of(
                            err("file", "READ_FAILED", "Không đọc được file tải lên.")));
        }
        List<ManifestFieldError> errors = validateUpload(
                file.getOriginalFilename(), file.getContentType(), bytes);
        if (!errors.isEmpty()) {
            throw new com.dauviet.animation.domain.AnimationExceptions
                    .HtmlValidationException(errors);
        }
        String content = StandardCharsets.UTF_8.decode(ByteBuffer.wrap(bytes)).toString();
        return new ValidatedHtml(content, sha256(bytes), bytes.length,
                file.getOriginalFilename());
    }

    public static String sha256(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (Exception e) {
            throw new IllegalStateException("checksum failed", e);
        }
    }

    private static ManifestFieldError err(String path, String code, String msg) {
        return new ManifestFieldError(path, code, msg);
    }
}
