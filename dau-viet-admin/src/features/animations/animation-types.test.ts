import { describe, expect, it } from "vitest";

import { emptyManifest, RENDERER_CODES } from "./animation-types";
import { parseDraft } from "./use-scene-editor";
import type { AnimationSceneDetail } from "./animation-types";

describe("emptyManifest", () => {
  it("seeds a river section for RIVER_TIDE only", () => {
    const river = emptyManifest("RIVER_TIDE");
    expect(river.river?.stakes).toEqual([]);
    expect(river.map).toBeUndefined();
    expect(river.rendererCode).toBe("RIVER_TIDE");
  });

  it("seeds map locations/routes for JOURNEY_MAP only", () => {
    const map = emptyManifest("JOURNEY_MAP", 2);
    expect(map.map?.locations).toEqual([]);
    expect(map.map?.routes).toEqual([]);
    expect(map.river).toBeUndefined();
    expect(map.rendererVersion).toBe(2);
  });

  it("covers every supported renderer code", () => {
    for (const code of RENDERER_CODES) {
      const m = emptyManifest(code);
      expect(m.steps).toEqual([]);
      expect(m.schemaVersion).toBe(1);
    }
  });
});

describe("parseDraft", () => {
  const scene = (draftJson: string | null): AnimationSceneDetail =>
    ({
      id: "s1",
      templateId: "t1",
      eventId: null,
      title: "Cảnh",
      status: "DRAFT",
      currentVersionId: null,
      currentVersionNo: null,
      rowVersion: 0,
      updatedAt: "",
      draftJson: draftJson ?? "",
      createdBy: "",
      updatedBy: "",
      createdAt: "",
    }) as AnimationSceneDetail;

  it("parses a valid manifest object", () => {
    const m = emptyManifest("RIVER_TIDE");
    expect(parseDraft(scene(JSON.stringify(m)))?.rendererCode).toBe("RIVER_TIDE");
  });

  it("returns null for empty or missing draftJson", () => {
    expect(parseDraft(scene(null))).toBeNull();
    expect(parseDraft(undefined)).toBeNull();
  });

  it("returns null for malformed JSON instead of throwing", () => {
    expect(parseDraft(scene("{not json"))).toBeNull();
    expect(parseDraft(scene("42"))).toBeNull();
  });
});
