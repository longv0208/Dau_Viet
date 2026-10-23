import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";

import { ScenePreview } from "./scene-editor/scene-preview";
import { emptyManifest, type AnimationManifest } from "./animation-types";

function riverManifest(): AnimationManifest {
  const m = emptyManifest("RIVER_TIDE");
  m.title = "Bạch Đằng";
  m.river = {
    stakes: [
      { id: "s1", x: 0.3, length: 0.4, visible: true },
      { id: "s2", x: 0.6, length: 0.3, visible: true },
    ],
  };
  m.steps = [
    {
      id: "step-1",
      title: "Triều lên",
      durationMs: 1000,
      targetState: { waterLevel: 0.8, boatProgress: 0.2 },
    },
    {
      id: "step-2",
      title: "Cọc lộ",
      durationMs: 1000,
      targetState: { waterLevel: 0.15, boatProgress: 0.6, obstructed: true },
    },
  ];
  return m;
}

function mapManifest(): AnimationManifest {
  const m = emptyManifest("JOURNEY_MAP");
  m.title = "Hai Bà Trưng";
  m.map = {
    locations: [
      { id: "me-linh", name: "Mê Linh", x: 0.3, y: 0.4, description: "Quê hương Hai Bà Trưng." },
      { id: "hat-mon", name: "Hát Môn", x: 0.6, y: 0.5 },
    ],
    routes: [{ id: "r1", from: "me-linh", to: "hat-mon" }],
  };
  m.steps = [
    {
      id: "step-1",
      title: "Khởi nghĩa",
      durationMs: 1000,
      targetState: { markerVisibility: { "me-linh": 1 }, routeProgress: { r1: 0 } },
    },
  ];
  return m;
}

describe("ScenePreview", () => {
  it("renders the river scene and steps through target states", async () => {
    render(<ScenePreview manifest={riverManifest()} />);
    expect(screen.getByLabelText("Xem trước cảnh sông")).toBeInTheDocument();
    expect(screen.getByText(/Bước 1\/2 — Triều lên/)).toBeInTheDocument();

    await userEvent.click(screen.getByLabelText("Bước sau"));
    expect(screen.getByText(/Bước 2\/2 — Cọc lộ/)).toBeInTheDocument();
  });

  it("renders the map scene with visible markers from targetState", () => {
    render(<ScenePreview manifest={mapManifest()} />);
    expect(screen.getByLabelText("Xem trước bản đồ")).toBeInTheDocument();
    expect(screen.getByText("Mê Linh")).toBeInTheDocument();
    // Hát Môn có markerVisibility = 0 → không vẽ.
    expect(screen.queryByText("Hát Môn")).not.toBeInTheDocument();
  });

  it("exposes the water control only when the step allows WATER_LEVEL_CONTROL", async () => {
    const m = riverManifest();
    m.steps[0]!.allowedInteractions = ["WATER_LEVEL_CONTROL"];
    render(<ScenePreview manifest={m} />);
    expect(screen.getByText(/Học viên kéo mực nước/)).toBeInTheDocument();

    await userEvent.click(screen.getByLabelText("Bước sau"));
    // Bước 2 không cho tương tác → slider biến mất.
    expect(screen.queryByText(/Học viên kéo mực nước/)).not.toBeInTheDocument();
  });

  it("shows an empty-state hint when the scene has no steps", () => {
    const m = emptyManifest("RIVER_TIDE");
    render(<ScenePreview manifest={m} />);
    expect(screen.getByText(/Chưa có bước/)).toBeInTheDocument();
    expect(screen.getByText(/Phát/)).toBeDisabled();
  });
});
