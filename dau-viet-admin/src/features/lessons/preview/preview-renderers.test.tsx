import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import type { Activity } from "../builder/draft-model";
import { ActivityRenderer } from "./activity-renderer";

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

  it("EVIDENCE_SELECT renders selectable entries from visibleEvidenceIds", () => {
    renderActivity({
      id: "a4",
      type: "EVIDENCE_SELECT",
      config: { visibleEvidenceIds: ["e1", "e2"], minRequired: 1 },
    });
    expect(screen.getByText(/tối thiểu 1/)).toBeInTheDocument();
    expect(screen.getByText("Bằng chứng 1")).toBeInTheDocument();
    expect(screen.getByText("Bằng chứng 2")).toBeInTheDocument();
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
