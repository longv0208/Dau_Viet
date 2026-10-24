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
            new Rule("url\\(\\s*[\"']?\\s*(?!data:)[^d]",
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
            new Rule("\\b(openDatabase|indexedDB\\.open|localStorage|sessionStorage)\\b",
                    "Lưu trữ cục bộ trong WebView — không được phép."));

    private record Rule(String regex, String message) {
        Pattern pattern() {
            return Pattern.compile(regex, Pattern.CASE_INSENSITIVE);
        }
    }

    private static final Pattern ATTR_NAMESPACE_OK =
            Pattern.compile("(xmlns\\s*=|xlink:href\\s*=|!doctype|<!ENTITY)",
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

        // (6) external dependency blocklist — report first N violations with
        // line number + snippet so the admin can fix precisely.
        int line = 1;
        int reported = 0;
        for (String l : content.split("\n", -1)) {
            String trimmed = l.trim();
            if (ATTR_NAMESPACE_OK.matcher(trimmed).find()) {
                line++;
                continue; // xmlns / doctype lines are declarative, not deps
            }
            for (Rule rule : EXTERNAL_RULES) {
                Matcher m = rule.pattern().matcher(trimmed);
                if (m.find()) {
                    String snippet = trimmed.length() > 90
                            ? trimmed.substring(0, 90) + "…" : trimmed;
                    errors.add(err("html", "EXTERNAL_REF",
                            "Dòng " + line + ": " + rule.message()
                                    + " — " + snippet));
                    reported++;
                    break;
                }
            }
            if (reported >= 10) {
                errors.add(err("html", "EXTERNAL_REF",
                        "...và nhiều tham chiếu ngoài khác (hiển thị 10 lỗi đầu)."));
                break;
            }
            line++;
        }
        return errors;
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
