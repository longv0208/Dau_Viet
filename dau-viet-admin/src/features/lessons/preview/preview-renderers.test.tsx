import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it } from "vitest";

import type { Activity, Stage } from "../builder/draft-model";
import { ActivityRenderer } from "./activity-renderer";
import { StageView } from "./stage-view";

function renderActivity(activity: Activity) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <ActivityRenderer activity={activity} />
    </QueryClientProvider>,
  );
}

describe("preview activity renderers", () => {
  it("READ renders config.text paragraphs", () => {
    renderActivity({
      id: "a1",
      type: "READ",
      config: { text: "Đoạn một.\n\nĐoạn hai." },
    });
    expect(screen.getByText("Đoạn một.")).toBeInTheDocument();
    expect(screen.getByText("Đoạn hai.")).toBeInTheDocument();
  });

  it("MULTIPLE_CHOICE renders options without marking the correct one", () => {
    const { container } = renderActivity({
      id: "a2",
      type: "MULTIPLE_CHOICE",
      config: {
        question: "Câu hỏi?",
        options: [
          { id: "o1", label: "Đáp án A" },
          { id: "o2", label: "Đáp án B" },
        ],
      },
    });
    expect(screen.getByText("Câu hỏi?")).toBeInTheDocument();
    expect(screen.getByText("Đáp án A")).toBeInTheDocument();
    expect(screen.getByText("Đáp án B")).toBeInTheDocument();
    // No DOM marker may leak which option is correct.
    expect(container.querySelector("[data-correct]")).toBeNull();
    expect(container.innerHTML).not.toContain("correctOptionIds");
  });

  it("DRAG_ORDER renders items without leaking expectedOrder", () => {
    const { container } = renderActivity({
      id: "a3",
      type: "DRAG_ORDER",
      config: {
        items: [
          { id: "i1", label: "Bước đầu" },
          { id: "i2", label: "Bước hai" },
        ],
      },
    });
    expect(screen.getByText("Bước đầu")).toBeInTheDocument();
    // expectedOrder must not leak into any attribute/value — text mention in
    // the admin-facing note is fine, but never a DOM data marker.
    expect(container.querySelector("[data-expected-order]")).toBeNull();
    expect(container.innerHTML).not.toContain('"expectedOrder"');
  });

  it("EVIDENCE_SELECT resolves titles from embedded evidence", () => {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ActivityRenderer
          activity={{
            id: "a4",
            type: "EVIDENCE_SELECT",
            config: { visibleEvidenceIds: ["e1", "e2"], minRequired: 1 },
          }}
          evidence={[
            {
              id: "e1",
              title: "Cọc ngầm sông Bạch Đằng",
              source: { title: "Bảo tàng Lịch sử" },
            },
            { id: "e2", title: "Đại Việt sử ký toàn thư" },
          ]}
        />
      </QueryClientProvider>,
    );
    expect(screen.getByText("Cọc ngầm sông Bạch Đằng")).toBeInTheDocument();
    expect(screen.getByText("Đại Việt sử ký toàn thư")).toBeInTheDocument();
    expect(screen.getByText(/Nguồn: Bảo tàng Lịch sử/)).toBeInTheDocument();
  });

  it("EVIDENCE_SELECT falls back to generic label for missing evidence", () => {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ActivityRenderer
          activity={{
            id: "a4",
            type: "EVIDENCE_SELECT",
            config: { visibleEvidenceIds: ["ghost"] },
          }}
          evidence={[]}
        />
      </QueryClientProvider>,
    );
    expect(screen.getByText("Bằng chứng 1")).toBeInTheDocument();
    expect(screen.queryByText(/ghost/)).not.toBeInTheDocument();
  });

  it("MATCHING renders two independent columns, never paired rows", () => {
    const { container } = renderActivity({
      id: "m1",
      type: "MATCHING",
      config: {
        leftItems: [
          { id: "l1", label: "Bên trái 1" },
          { id: "l2", label: "Bên trái 2" },
        ],
        rightItems: [
          { id: "r1", label: "Bên phải 1" },
          { id: "r2", label: "Bên phải 2" },
        ],
      },
    });
    expect(screen.getByText("Bên trái 1")).toBeInTheDocument();
    expect(screen.getByText("Bên phải 1")).toBeInTheDocument();
    // Two independent columns — no single row contains a left+right pair.
    expect(container.innerHTML).not.toContain("pairs");
  });

  it("MATCHING falls back gracefully when columns missing", () => {
    renderActivity({ id: "m2", type: "MATCHING", config: {} });
    expect(screen.getByText(/Chưa có cặp nối nào/)).toBeInTheDocument();
  });

  it("VERIFICATION resolves source titles from embedded evidence", () => {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ActivityRenderer
          activity={{
            id: "v1",
            type: "VERIFICATION",
            config: { visibleSourceIds: ["e9"] },
          }}
          evidence={[
            {
              id: "e9",
              title: "Biên bản chiến dịch",
              source: { title: "Đại Việt sử ký", author: "Ngô Sĩ Liên" },
            },
          ]}
        />
      </QueryClientProvider>,
    );
    expect(screen.getByText("Biên bản chiến dịch")).toBeInTheDocument();
    expect(screen.getByText(/Đại Việt sử ký/)).toBeInTheDocument();
  });

  it("navigating between same-type activities resets local state", async () => {
    // Regression: without key={activity.id} React reused the DragOrder view
    // across activities — the reordered state leaked into the next activity.
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    const stage = {
      id: "s",
      type: "RECONSTRUCTION",
      activities: [
        {
          id: "d1",
          type: "DRAG_ORDER",
          config: { items: [{ id: "i1", label: "A1" }, { id: "i2", label: "B2" }] },
        },
        {
          id: "d2",
          type: "DRAG_ORDER",
          config: { items: [{ id: "x1", label: "X1" }, { id: "x2", label: "Y2" }] },
        },
      ],
    } as unknown as Stage;
    // Parent holds the index, like the preview page does.
    function Harness() {
      const [idx, setIdx] = useState(0);
      return <StageView stage={stage} activityIndex={idx} onActivityChange={setIdx} />;
    }
    render(
      <QueryClientProvider client={client}>
        <Harness />
      </QueryClientProvider>,
    );
    const ordered = () => screen.getAllByText(/^(A1|B2|X1|Y2)$/).map((n) => n.textContent);
    // Reorder first activity — B2 moves to top.
    await userEvent.click(screen.getByLabelText(/Đưa "B2" lên/i));
    expect(ordered()).toEqual(["B2", "A1"]);
    // Navigate to activity 2 — shows its own items, no leaked state.
    await userEvent.click(screen.getByLabelText("Hoạt động tiếp"));
    expect(ordered()).toEqual(["X1", "Y2"]);
    // Navigate back — first activity remounts with its ORIGINAL order.
    await userEvent.click(screen.getByLabelText("Hoạt động trước"));
    expect(ordered()).toEqual(["A1", "B2"]);
  });

  it("unknown/EXPLORE_MAP type falls back to honest placeholder", () => {
    renderActivity({
      id: "a5",
      type: "EXPLORE_MAP",
      config: { center: [105, 20] },
    });
    expect(screen.getByText(/chưa có bản xem trước/i)).toBeInTheDocument();
    expect(screen.getByText(/EXPLORE_MAP/)).toBeInTheDocument();
  });
});
