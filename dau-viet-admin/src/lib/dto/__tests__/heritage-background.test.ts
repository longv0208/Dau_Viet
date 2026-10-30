import { describe, expect, it } from "vitest";
import {
  applyHeritagePreset,
  defaultHeritageBackgroundConfig,
  normalizeHeritageBackgroundConfig,
  updateHeritageBackgroundImage,
} from "../heritage-background";

describe("heritage-background helpers", () => {
  it("returns default paper config when input is null or empty", () => {
    const cfg = normalizeHeritageBackgroundConfig(null);
    expect(cfg).toEqual({
      backgroundAssetId: null,
      backgroundImageUrl: null,
      backgroundMode: "none",
      focusX: 0.5,
      focusY: 0.35,
      imageOpacity: 0.55,
      fadeStrength: 0.8,
      tintPreset: "warm",
      enabled: true,
    });
  });

  it("switches to heritage_fade automatically when an image is added without losing sliders", () => {
    const custom = {
      ...defaultHeritageBackgroundConfig(),
      focusX: 0.3,
      focusY: 0.2,
      imageOpacity: 0.65,
      fadeStrength: 0.9,
      tintPreset: "sepia" as const,
    };

    const assetId = "d7a70000-0000-4000-8000-000000000004";
    const withImg = updateHeritageBackgroundImage(custom, assetId);

    expect(withImg.backgroundAssetId).toBe(assetId);
    expect(withImg.backgroundImageUrl).toBe(`/api/v1/assets/${assetId}/content`);
    expect(withImg.backgroundMode).toBe("heritage_fade");
    expect(withImg.focusX).toBe(0.3);
    expect(withImg.focusY).toBe(0.2);
    expect(withImg.imageOpacity).toBe(0.65);
    expect(withImg.fadeStrength).toBe(0.9);
    expect(withImg.tintPreset).toBe("sepia");

    // Replacing with another image preserves custom sliders
    const secondAssetId = "d7a70000-0000-4000-8000-000000000005";
    const replaced = updateHeritageBackgroundImage(withImg, secondAssetId);
    expect(replaced.backgroundAssetId).toBe(secondAssetId);
    expect(replaced.focusX).toBe(0.3);
    expect(replaced.tintPreset).toBe("sepia");

    // Removing image falls back to paper mode while keeping slider settings
    const cleared = updateHeritageBackgroundImage(replaced, null, null);
    expect(cleared.backgroundAssetId).toBeNull();
    expect(cleared.backgroundImageUrl).toBeNull();
    expect(cleared.backgroundMode).toBe("none");
    expect(cleared.focusX).toBe(0.3);
  });

  it("applies presets while keeping the selected image", () => {
    const assetId = "d7a70000-0000-4000-8000-000000000004";
    const initial = updateHeritageBackgroundImage(
      defaultHeritageBackgroundConfig(),
      assetId,
    );

    const normal = applyHeritagePreset(initial, "normal");
    expect(normal.backgroundMode).toBe("normal");
    expect(normal.backgroundAssetId).toBe(assetId);
    expect(normal.imageOpacity).toBe(0.85);
    expect(normal.fadeStrength).toBe(0.35);
    expect(normal.tintPreset).toBe("neutral");
  });
});
