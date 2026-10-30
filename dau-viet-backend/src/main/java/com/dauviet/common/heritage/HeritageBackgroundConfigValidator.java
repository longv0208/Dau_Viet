package com.dauviet.common.heritage;

import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import com.dauviet.lesson.domain.Asset;
import com.dauviet.lesson.domain.AssetNotFoundException;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Validates, normalizes, and serializes/deserializes {@link HeritageBackgroundConfigDto}.
 * Ensures referenced assets exist and are ACTIVE images, and guarantees a valid
 * default configuration when none has been configured by Admin.
 */
@Component
public class HeritageBackgroundConfigValidator {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private static final Set<String> ALLOWED_MODES = Set.of(
            HeritageBackgroundConfigDto.MODE_HERITAGE_FADE,
            HeritageBackgroundConfigDto.MODE_NORMAL,
            HeritageBackgroundConfigDto.MODE_NONE
    );

    private static final Set<String> ALLOWED_TINTS = Set.of(
            HeritageBackgroundConfigDto.TINT_WARM,
            HeritageBackgroundConfigDto.TINT_SEPIA,
            HeritageBackgroundConfigDto.TINT_COOL,
            HeritageBackgroundConfigDto.TINT_NEUTRAL,
            HeritageBackgroundConfigDto.TINT_NONE
    );

    private static final Set<String> ALLOWED_IMAGE_MIMES = Set.of(
            "image/jpeg",
            "image/png",
            "image/webp"
    );

    private static final Pattern UUID_PATTERN = Pattern.compile(
            "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
            Pattern.CASE_INSENSITIVE
    );

    private static final Pattern ASSET_CONTENT_URL_PATTERN = Pattern.compile(
            "^/api/v1/(?:admin/)?assets/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/content$",
            Pattern.CASE_INSENSITIVE
    );

    private static final Pattern LOGICAL_IMAGE_KEY_PATTERN = Pattern.compile(
            "^(?:periods|events|assets/images|/heritage)/[A-Za-z0-9_./-]+\\.(?:jpg|jpeg|png|webp)$",
            Pattern.CASE_INSENSITIVE
    );

    private final AssetRepository assets;

    public HeritageBackgroundConfigValidator() {
        this(null);
    }

    @Autowired
    public HeritageBackgroundConfigValidator(AssetRepository assets) {
        this.assets = assets;
    }

    /**
     * Parses a stored JSONB string into {@link HeritageBackgroundConfigDto},
     * returning {@link HeritageBackgroundConfigDto#defaultConfig()} when null, blank, or empty.
     */
    public static HeritageBackgroundConfigDto parseOrDefault(String rawJson) {
        if (rawJson == null || rawJson.isBlank()) {
            return HeritageBackgroundConfigDto.defaultConfig();
        }
        try {
            JsonNode node = MAPPER.readTree(rawJson);
            if (node == null || !node.isObject() || node.isEmpty()) {
                return HeritageBackgroundConfigDto.defaultConfig();
            }
            UUID assetId = null;
            if (node.hasNonNull("backgroundAssetId")) {
                String rawId = node.get("backgroundAssetId").asText("").trim();
                if (UUID_PATTERN.matcher(rawId).matches()) {
                    assetId = UUID.fromString(rawId);
                }
            }
            String imageUrl = null;
            if (node.hasNonNull("backgroundImageUrl")) {
                String rawUrl = node.get("backgroundImageUrl").asText("").trim();
                if (!rawUrl.isEmpty()) {
                    imageUrl = rawUrl;
                }
            }
            if (assetId == null && imageUrl != null) {
                assetId = extractAssetUuid(imageUrl);
            }
            if (assetId != null) {
                imageUrl = "/api/v1/assets/" + assetId + "/content";
            }

            boolean hasImage = imageUrl != null && !imageUrl.isBlank();
            String rawMode = node.hasNonNull("backgroundMode")
                    ? node.get("backgroundMode").asText("").trim().toLowerCase(Locale.ROOT)
                    : "";
            String mode = ALLOWED_MODES.contains(rawMode)
                    ? rawMode
                    : (hasImage ? HeritageBackgroundConfigDto.MODE_HERITAGE_FADE : HeritageBackgroundConfigDto.MODE_NONE);

            double focusX = clampUnit(readDouble(node, "focusX", HeritageBackgroundConfigDto.DEFAULT_FOCUS_X));
            double focusY = clampUnit(readDouble(node, "focusY", HeritageBackgroundConfigDto.DEFAULT_FOCUS_Y));
            double imageOpacity = clampUnit(readDouble(node, "imageOpacity", HeritageBackgroundConfigDto.DEFAULT_IMAGE_OPACITY));
            double fadeStrength = clampUnit(readDouble(node, "fadeStrength", HeritageBackgroundConfigDto.DEFAULT_FADE_STRENGTH));

            String rawTint = node.hasNonNull("tintPreset")
                    ? node.get("tintPreset").asText("").trim().toLowerCase(Locale.ROOT)
                    : "";
            String tint = ALLOWED_TINTS.contains(rawTint)
                    ? rawTint
                    : HeritageBackgroundConfigDto.TINT_WARM;

            boolean enabled = !node.hasNonNull("enabled") || node.get("enabled").asBoolean(true);

            return new HeritageBackgroundConfigDto(
                    assetId,
                    imageUrl,
                    mode,
                    focusX,
                    focusY,
                    imageOpacity,
                    fadeStrength,
                    tint,
                    enabled
            );
        } catch (Exception e) {
            return HeritageBackgroundConfigDto.defaultConfig();
        }
    }

    /**
     * Validates an incoming {@link HeritageBackgroundConfigDto} from Admin,
     * checks asset existence if an asset is referenced, normalizes defaults,
     * and returns the canonical JSON string to persist in `background_config_json`.
     */
    public String validateAndSerialize(HeritageBackgroundConfigDto input) {
        if (input == null) {
            return null;
        }
        HeritageBackgroundConfigDto normalized = validateAndNormalize(input);
        try {
            return MAPPER.writeValueAsString(normalized);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Không thể tuần tự hóa cấu hình ảnh nền: " + e.getMessage());
        }
    }

    public HeritageBackgroundConfigDto validateAndNormalize(HeritageBackgroundConfigDto input) {
        if (input == null) {
            return HeritageBackgroundConfigDto.defaultConfig();
        }

        UUID assetId = input.backgroundAssetId();
        String rawUrl = input.backgroundImageUrl() == null ? null : input.backgroundImageUrl().trim();
        if (rawUrl != null && rawUrl.isEmpty()) {
            rawUrl = null;
        }

        if (assetId == null && rawUrl != null) {
            assetId = extractAssetUuid(rawUrl);
        }

        String resolvedImageUrl = null;
        if (assetId != null) {
            validateActiveImageAsset(assetId);
            resolvedImageUrl = "/api/v1/assets/" + assetId + "/content";
        } else if (rawUrl != null) {
            if (!LOGICAL_IMAGE_KEY_PATTERN.matcher(rawUrl).matches()) {
                throw new IllegalArgumentException(
                        "Đường dẫn ảnh nền không hợp lệ hoặc tham chiếu asset không tồn tại: " + rawUrl);
            }
            resolvedImageUrl = rawUrl;
        }

        boolean hasImage = resolvedImageUrl != null;

        String mode;
        if (input.backgroundMode() == null || input.backgroundMode().isBlank()) {
            mode = hasImage
                    ? HeritageBackgroundConfigDto.MODE_HERITAGE_FADE
                    : HeritageBackgroundConfigDto.MODE_NONE;
        } else {
            mode = input.backgroundMode().trim().toLowerCase(Locale.ROOT);
            if (!ALLOWED_MODES.contains(mode)) {
                throw new IllegalArgumentException(
                        "Chế độ hiển thị ảnh nền (backgroundMode) không hợp lệ: " + input.backgroundMode()
                                + ". Chỉ chấp nhận: heritage_fade, normal, none.");
            }
        }

        double focusX = validateUnitRange("focusX", input.focusX(), HeritageBackgroundConfigDto.DEFAULT_FOCUS_X);
        double focusY = validateUnitRange("focusY", input.focusY(), HeritageBackgroundConfigDto.DEFAULT_FOCUS_Y);
        double defaultOpacity = HeritageBackgroundConfigDto.MODE_NORMAL.equals(mode)
                ? 0.85
                : HeritageBackgroundConfigDto.DEFAULT_IMAGE_OPACITY;
        double defaultFade = HeritageBackgroundConfigDto.MODE_NORMAL.equals(mode)
                ? 0.35
                : HeritageBackgroundConfigDto.DEFAULT_FADE_STRENGTH;
        double imageOpacity = validateUnitRange("imageOpacity", input.imageOpacity(), defaultOpacity);
        double fadeStrength = validateUnitRange("fadeStrength", input.fadeStrength(), defaultFade);

        String tint;
        if (input.tintPreset() == null || input.tintPreset().isBlank()) {
            tint = HeritageBackgroundConfigDto.TINT_WARM;
        } else {
            tint = input.tintPreset().trim().toLowerCase(Locale.ROOT);
            if (!ALLOWED_TINTS.contains(tint)) {
                throw new IllegalArgumentException(
                        "Tông màu ảnh nền (tintPreset) không hợp lệ: " + input.tintPreset()
                                + ". Chỉ chấp nhận: warm, sepia, cool, neutral, none.");
            }
        }

        boolean enabled = input.enabled() == null || input.enabled();

        return new HeritageBackgroundConfigDto(
                assetId,
                resolvedImageUrl,
                mode,
                focusX,
                focusY,
                imageOpacity,
                fadeStrength,
                tint,
                enabled
        );
    }

    private void validateActiveImageAsset(UUID assetId) {
        if (assets == null) {
            return;
        }
        Asset asset = assets.findById(assetId)
                .filter(a -> "ACTIVE".equals(a.getState()))
                .orElseThrow(() -> new AssetNotFoundException(
                        "Ảnh nền không tồn tại hoặc không ở trạng thái ACTIVE: " + assetId));
        String mime = asset.getMimeType() == null ? "" : asset.getMimeType().toLowerCase(Locale.ROOT);
        if (!ALLOWED_IMAGE_MIMES.contains(mime)) {
            throw new IllegalArgumentException(
                    "Ảnh nền chỉ chấp nhận định dạng JPEG, PNG hoặc WebP (định dạng hiện tại: "
                            + asset.getMimeType() + ")");
        }
    }

    public static UUID extractAssetUuid(String raw) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (UUID_PATTERN.matcher(trimmed).matches()) {
            return UUID.fromString(trimmed);
        }
        Matcher matcher = ASSET_CONTENT_URL_PATTERN.matcher(trimmed);
        if (matcher.matches()) {
            return UUID.fromString(matcher.group(1));
        }
        return null;
    }

    private static double validateUnitRange(String field, Double value, double defaultValue) {
        if (value == null) {
            return defaultValue;
        }
        if (value.isNaN() || value.isInfinite() || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(
                    "Giá trị " + field + " phải nằm trong khoảng [0.0, 1.0] (nhận được: " + value + ")");
        }
        return Math.round(value * 1000.0) / 1000.0;
    }

    private static double readDouble(JsonNode node, String field, double fallback) {
        if (!node.hasNonNull(field) || !node.get(field).isNumber()) {
            return fallback;
        }
        return node.get(field).asDouble(fallback);
    }

    private static double clampUnit(double v) {
        if (Double.isNaN(v) || Double.isInfinite(v)) {
            return 0.5;
        }
        return Math.max(0.0, Math.min(1.0, v));
    }
}
