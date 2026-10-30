package com.dauviet.common.heritage;

import java.util.UUID;

/**
 * Dynamic Heritage Background configuration contract shared across
 * historical periods/chapters, events, and lessons.
 * Distinct from cover/thumbnail images: controls how the hero background
 * blends into the Vietnamese heritage paper surface on mobile.
 */
public record HeritageBackgroundConfigDto(
        UUID backgroundAssetId,
        String backgroundImageUrl,
        String backgroundMode,
        Double focusX,
        Double focusY,
        Double imageOpacity,
        Double fadeStrength,
        String tintPreset,
        Boolean enabled
) {
    public static final String MODE_HERITAGE_FADE = "heritage_fade";
    public static final String MODE_NORMAL = "normal";
    public static final String MODE_NONE = "none";

    public static final String TINT_WARM = "warm";
    public static final String TINT_SEPIA = "sepia";
    public static final String TINT_COOL = "cool";
    public static final String TINT_NEUTRAL = "neutral";
    public static final String TINT_NONE = "none";

    public static final double DEFAULT_FOCUS_X = 0.5;
    public static final double DEFAULT_FOCUS_Y = 0.35;
    public static final double DEFAULT_IMAGE_OPACITY = 0.55;
    public static final double DEFAULT_FADE_STRENGTH = 0.8;

    public static HeritageBackgroundConfigDto defaultConfig() {
        return new HeritageBackgroundConfigDto(
                null,
                null,
                MODE_NONE,
                DEFAULT_FOCUS_X,
                DEFAULT_FOCUS_Y,
                DEFAULT_IMAGE_OPACITY,
                DEFAULT_FADE_STRENGTH,
                TINT_WARM,
                true
        );
    }

    public static HeritageBackgroundConfigDto presetHeritageFade(UUID assetId, String imageUrl) {
        return new HeritageBackgroundConfigDto(
                assetId,
                imageUrl,
                MODE_HERITAGE_FADE,
                DEFAULT_FOCUS_X,
                DEFAULT_FOCUS_Y,
                DEFAULT_IMAGE_OPACITY,
                DEFAULT_FADE_STRENGTH,
                TINT_WARM,
                true
        );
    }
}
