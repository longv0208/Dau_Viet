import { render, screen, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

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

/* ---------- FIX-P1 §2 — playback state machine (mocked rAF + clock) ---------- */

describe("ScenePreview playback state machine", () => {
  // Manifest 2 step × 1000ms để progress = elapsed/1000 rõ ràng.
  function twoStepManifest(): AnimationManifest {
    const m = emptyManifest("RIVER_TIDE");
    m.title = "Playback";
    m.steps = [
      { id: "s1", title: "S1", durationMs: 1000, targetState: { waterLevel: 0.9 } },
      { id: "s2", title: "S2", durationMs: 1000, targetState: { waterLevel: 0.2 } },
    ];
    return m;
  }

  // Map id → cb để cancelAnimationFrame gỡ thật khỏi queue (mock phải
  // bám semantics của API gốc — không thì không assert được "không leak").
  let rafMap: Map<number, FrameRequestCallback>;
  let rafId: number;
  let nowMs: number;

  const rafQueue = {
    get length() {
      return rafMap.size;
    },
  };

  // Đẩy clock tới `ms` rồi flush MỘT vòng rAF (React 18 batching → act).
  function tickTo(ms: number) {
    nowMs = ms;
    const cbs = [...rafMap.values()];
    rafMap.clear();
    for (const cb of cbs) cb(nowMs);
  }

  beforeEach(() => {
    rafMap = new Map();
    rafId = 0;
    nowMs = 0;
    vi.stubGlobal("requestAnimationFrame", (cb: FrameRequestCallback) => {
      const id = ++rafId;
      rafMap.set(id, cb);
      return id;
    });
    vi.stubGlobal("cancelAnimationFrame", (id: number) => {
      rafMap.delete(id);
    });
    vi.stubGlobal("performance", { now: () => nowMs });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  const playBtn = () => screen.getByTestId("play-toggle");
  const label = () => screen.getByTestId("step-label").textContent ?? "";
  const water = () =>
    Number(
      screen.getByTestId("water-rect").getAttribute("y"),
    );

  it("initial Play starts step 0 with progress 0 — không skip bước", async () => {
    render(<ScenePreview manifest={twoStepManifest()} />);
    expect(label()).toContain("Bước 1/2");
    await act(async () => {
      await userEvent.click(playBtn());
    });
    // tick đầu: elapsed 0 → progress 0 → water ở target start (initial).
    act(() => tickTo(0));
    // step label vẫn step 1 — không nhảy qua step 2.
    expect(label()).toContain("Bước 1/2");
    // Có rAF pending → loop đang chạy.
    expect(rafQueue.length).toBeGreaterThan(0);
  });

  it("Pause giữ progress tại thời điểm bấm, không snap về 1", async () => {
    render(<ScenePreview manifest={twoStepManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    // Chạy tới 400ms → progress 0.4.
    act(() => tickTo(400));
    const yMid = water();
    await act(async () => {
      await userEvent.click(playBtn()); // pause
    });
    // Frame giữ nguyên — water không nhảy về end-state.
    expect(water()).toBeCloseTo(yMid, 0);
    // Button đổi thành "Phát" (không còn "Tạm dừng").
    expect(playBtn().textContent).toContain("Phát");
  });

  it("Chờ 10s khi paused → progress không đổi", async () => {
    render(<ScenePreview manifest={twoStepManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(400));
    await act(async () => {
      await userEvent.click(playBtn()); // pause @0.4
    });
    const yAt = water();
    // 10 giây trôi — không rAF chạy → không đổi.
    act(() => tickTo(10400));
    expect(water()).toBeCloseTo(yAt, 0);
  });

  it("Resume tiếp tục từ progress đã giữ, không chạy bù", async () => {
    render(<ScenePreview manifest={twoStepManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(400));
    await act(async () => {
      await userEvent.click(playBtn()); // pause @0.4
    });
    // 10s pause.
    nowMs = 10400;
    await act(async () => {
      await userEvent.click(playBtn()); // resume
    });
    // Rebase: stepStart = 10400-400=10000 → +600ms → total elapsed 1000.
    act(() => tickTo(11000));
    // progress = (11000-10000)/1000 = 1 → step sang s2.
    expect(label()).toContain("Bước 2/2");
  });

  it("Play → finish → replay → chạy lại từ step 0", async () => {
    render(<ScenePreview manifest={twoStepManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(1000)); // hết s1 → s2
    act(() => tickTo(2000)); // hết s2 → finished
    // Nút đổi "Phát lại".
    expect(playBtn().textContent).toContain("Phát lại");
    // Replay → step 0.
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(2000));
    expect(label()).toContain("Bước 1/2");
  });

  it("Pause ở step cuối rồi Resume tiếp tục, không restart nhầm", async () => {
    render(<ScenePreview manifest={twoStepManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(1000)); // vào s2
    act(() => tickTo(1400)); // s2 @0.4
    await act(async () => {
      await userEvent.click(playBtn()); // pause @s2
    });
    await act(async () => {
      await userEvent.click(playBtn()); // resume — stepStart=1400-400=1000
    });
    // s2 elapsed tính lại từ 1000 → +600 → 2000 → finished.
    act(() => tickTo(2000));
    expect(playBtn().textContent).toContain("Phát lại"); // finished
    // Không quay về step 1.
    expect(label()).toContain("Bước 2/2");
  });

  it("Next/Previous khi playing → step mới tween từ đầu", async () => {
    render(<ScenePreview manifest={twoStepManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(400));
    await act(async () => {
      await userEvent.click(screen.getByLabelText("Bước sau"));
    });
    // Step mới + progress reset → stepStart = now (400) → tick tiếp.
    expect(label()).toContain("Bước 2/2");
    act(() => tickTo(900)); // elapsed 500 → progress 0.5 s2
    // Vẫn 1 loop duy nhất — mỗi tick chỉ push 1 cb.
    expect(rafQueue.length).toBe(1);
  });

  it("manifest biên tập giữa chừng → index clamp, không crash", async () => {
    const m = twoStepManifest();
    const { rerender } = render(<ScenePreview manifest={m} />);
    await act(async () => {
      await userEvent.click(screen.getByLabelText("Bước sau"));
    });
    expect(label()).toContain("Bước 2/2");
    // Biên tập: bỏ step cuối → index=1 > len-1=0 → clamp về 0.
    const edited = twoStepManifest();
    edited.steps = [m.steps[0]!];
    await act(async () => {
      rerender(<ScenePreview manifest={edited} />);
    });
    // Không crash, label nhất quán.
    expect(screen.getByTestId("step-label")).toBeInTheDocument();
  });

  it("unmount hủy rAF loop — không leak", async () => {
    const { unmount } = render(<ScenePreview manifest={twoStepManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    expect(rafQueue.length).toBeGreaterThan(0);
    unmount();
    // Sau unmount, không còn cb mới được đăng ký → queue cạn.
    expect(rafQueue.length).toBe(0);
  });

  it("không có 2 rAF loops chạy đồng thời", async () => {
    render(<ScenePreview manifest={twoStepManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(300));
    // Mỗi vòng chỉ đúng 1 pending cb.
    expect(rafQueue.length).toBe(1);
    // Điều hướng giữa chừng — vẫn 1 cb.
    await act(async () => {
      await userEvent.click(screen.getByLabelText("Bước sau"));
    });
    act(() => tickTo(500));
    expect(rafQueue.length).toBe(1);
  });

  /* ---------- FIX-P1 §2 — pause → navigate → play (khác duration) --- */

  // 2 step duration khác nhau: s1=1000ms, s2=2000ms.
  function twoDurManifest(): AnimationManifest {
    const m = emptyManifest("RIVER_TIDE");
    m.title = "Nav";
    m.steps = [
      { id: "s1", title: "S1", durationMs: 1000, targetState: { waterLevel: 0.9 } },
      { id: "s2", title: "S2", durationMs: 2000, targetState: { waterLevel: 0.2 } },
    ];
    return m;
  }

  it("Pause@400ms → Next (dur khác) → Play chạy step 2 từ đầu, không giật", async () => {
    render(<ScenePreview manifest={twoDurManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(400)); // pause @0.4 của step1
    await act(async () => {
      await userEvent.click(playBtn()); // pause
    });
    // Next sang step 2 (dur 2000) → end-state tĩnh, status về idle.
    await act(async () => {
      await userEvent.click(screen.getByLabelText("Bước sau"));
    });
    expect(label()).toContain("Bước 2/2");
    // Play → chạy step 2 TỪ ĐẦU (không rebase elapsed 400ms của step 1).
    nowMs = 400;
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(600)); // elapsed 200ms vào step 2 → progress 0.1
    // water level đang lerp từ 0.9 → 0.2 ở progress 0.1 → y gần endState
    // start, không nhảy về progress 0.4+ cũ (đó là giật frame).
    expect(label()).toContain("Bước 2/2");
    // Vẫn đúng 1 rAF loop.
    expect(rafQueue.length).toBe(1);
    // Chạy hết 2000ms → finished (không tua nhanh từ elapsed cũ).
    act(() => tickTo(2600));
    expect(playBtn().textContent).toContain("Phát lại");
  });

  it("Pause → Previous → Play chạy step 1 từ đầu", async () => {
    render(<ScenePreview manifest={twoDurManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(1000)); // hết s1 → vào s2
    act(() => tickTo(1400)); // s2 @0.2
    await act(async () => {
      await userEvent.click(playBtn()); // pause s2
    });
    await act(async () => {
      await userEvent.click(screen.getByLabelText("Bước trước"));
    });
    expect(label()).toContain("Bước 1/2");
    // Play → step 1 từ đầu.
    nowMs = 1400;
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(1900)); // elapsed 500 → progress 0.5 s1
    expect(label()).toContain("Bước 1/2");
    // Hết 1000ms → sang s2.
    act(() => tickTo(2400));
    expect(label()).toContain("Bước 2/2");
  });

  it("Finish → Previous → Play chạy step đó (không replay từ 0)", async () => {
    render(<ScenePreview manifest={twoDurManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(1000));
    act(() => tickTo(3000)); // finished
    expect(playBtn().textContent).toContain("Phát lại");
    // Prev về step 1 → idle end-state.
    await act(async () => {
      await userEvent.click(screen.getByLabelText("Bước trước"));
    });
    expect(label()).toContain("Bước 1/2");
    // Play → chạy step 1 (không phải replay toàn scene từ step 0 — user
    // đã chọn step 1).
    nowMs = 3000;
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(3100));
    expect(label()).toContain("Bước 1/2");
    expect(rafQueue.length).toBe(1);
  });

  it("Pause → Next → Pause lại không kích hoạt rAF cũ", async () => {
    render(<ScenePreview manifest={twoDurManifest()} />);
    await act(async () => {
      await userEvent.click(playBtn());
    });
    act(() => tickTo(400));
    await act(async () => {
      await userEvent.click(playBtn()); // pause
    });
    await act(async () => {
      await userEvent.click(screen.getByLabelText("Bước sau")); // idle @s2
    });
    // Không rAF nào pending khi idle.
    expect(rafQueue.length).toBe(0);
  });
});
