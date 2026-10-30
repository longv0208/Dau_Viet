import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { Activity, Stage } from "../draft-model";
import { validateDraftLocally } from "../draft-local-validator";
import { EvidenceSelectEditor } from "./evidence-select-editor";

const stage: Stage = { id: "s-ev", type: "EVIDENCE", required: true, activities: [] };

function makeActivity(config: Record<string, unknown>): Activity {
  return {
    id: "es-1",
    type: "EVIDENCE_SELECT",
    required: true,
    instruction: "Chọn bằng chứng liên quan",
    config,
    feedback: {
      COMPLETED: "Hoàn thành",
      INCORRECT: "Chưa đúng",
      PARTIAL: "Đúng một phần",
      EXHAUSTED: "Hết lượt",
    },
  };
}

function renderEditor(activity: Activity, onChange = vi.fn()) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(
    <QueryClientProvider client={qc}>
      <EvidenceSelectEditor stage={stage} activity={activity} onChange={onChange} />
    </QueryClientProvider>,
  );
  return { onChange };
}

describe("EvidenceSelectEditor", () => {
  it("renders onboarding guide and COLLECT mode preview when graded is false", () => {
    const act = makeActivity({
      graded: false,
      visibleEvidenceIds: ["e1111111-1111-1111-1111-111111111111"],
      minRequired: 2,
    });
    renderEditor(act);

    expect(screen.getByTestId("evidence-select-guide")).toHaveTextContent(
      /Hướng dẫn cơ chế hoạt động Chọn bằng chứng/,
    );
    expect(
      screen.getByRole("radio", { name: /Thu thập bằng chứng \(không chấm điểm\)/ }),
    ).toBeChecked();
    expect(screen.queryByText(/Bằng chứng đúng \(đáp án\)/)).toBeNull();
    expect(screen.getByTestId("evidence-select-learner-preview")).toHaveTextContent(
      /THU THẬP DẤU VẾT · CHỌN ÍT NHẤT 2/,
    );
  });

  it("switches from ASSESS (graded:true) to COLLECT (graded:false) and strips graded-only keys", async () => {
    const user = userEvent.setup();
    const act = makeActivity({
      graded: true,
      visibleEvidenceIds: [
        "e1111111-1111-1111-1111-111111111111",
        "e2222222-2222-2222-2222-222222222222",
      ],
      acceptedEvidenceIds: ["e1111111-1111-1111-1111-111111111111"],
      maxAttempts: 3,
      remedialAttempts: 1,
      minRequired: 2,
    });
    const { onChange } = renderEditor(act);

    expect(screen.getByTestId("evidence-select-learner-preview")).toHaveTextContent(
      /CHỌN ĐÚNG CÁC DẤU VẾT LIÊN QUAN · Sai mất Thể lực · còn 3 lượt \+ 1 sửa/,
    );

    await user.click(
      screen.getByRole("radio", { name: /Thu thập bằng chứng \(không chấm điểm\)/ }),
    );

    expect(onChange).toHaveBeenCalledTimes(1);
    const patch = onChange.mock.calls[0]![0] as { config: Record<string, unknown> };
    expect(patch.config.graded).toBe(false);
    expect(patch.config.minRequired).toBe(2);
    expect("acceptedEvidenceIds" in patch.config).toBe(false);
    expect("maxAttempts" in patch.config).toBe(false);
    expect("remedialAttempts" in patch.config).toBe(false);
  });

  it("warns when acceptedEvidenceIds is not a subset of visibleEvidenceIds or when there are no distractors", () => {
    const actOutOfSubset = makeActivity({
      graded: true,
      visibleEvidenceIds: ["e1111111-1111-1111-1111-111111111111"],
      acceptedEvidenceIds: [
        "e1111111-1111-1111-1111-111111111111",
        "e2222222-2222-2222-2222-222222222222",
      ],
    });
    const { unmount } = render(
      <QueryClientProvider client={new QueryClient()}>
        <EvidenceSelectEditor
          stage={stage}
          activity={actOutOfSubset}
          onChange={vi.fn()}
        />
      </QueryClientProvider>,
    );
    expect(
      screen.getByText(/chưa nằm trong danh sách hiển thị cho học viên/),
    ).toBeInTheDocument();
    unmount();

    const actNoDistractor = makeActivity({
      graded: true,
      visibleEvidenceIds: ["e1111111-1111-1111-1111-111111111111"],
      acceptedEvidenceIds: ["e1111111-1111-1111-1111-111111111111"],
    });
    renderEditor(actNoDistractor);
    expect(
      screen.getByText(/Cảnh báo thiết kế: Tất cả 1 bằng chứng hiển thị đều là đáp án đúng/),
    ).toBeInTheDocument();
  });

  it("validateDraftLocally accepts both COLLECT (graded:false) and ASSESS (graded:true) modes", () => {
    const collectDraft = {
      schemaVersion: 1,
      stages: [
        {
          id: "s1",
          type: "EVIDENCE" as const,
          required: true,
          activities: [
            {
              id: "es1",
              type: "EVIDENCE_SELECT" as const,
              required: true,
              config: {
                graded: false,
                visibleEvidenceIds: ["e1"],
                minRequired: 1,
              },
              feedback: { COMPLETED: "Đã thu thập xong" },
            },
          ],
          nextStageIds: [],
        },
      ],
    };
    expect(validateDraftLocally(collectDraft)).toEqual([]);

    const invalidAssessDraft = {
      schemaVersion: 1,
      stages: [
        {
          id: "s1",
          type: "EVIDENCE" as const,
          required: true,
          activities: [
            {
              id: "es1",
              type: "EVIDENCE_SELECT" as const,
              required: true,
              config: {
                graded: true,
                visibleEvidenceIds: ["e1"],
                acceptedEvidenceIds: ["e2"],
              },
              feedback: {
                COMPLETED: "OK",
                INCORRECT: "Sai",
                PARTIAL: "Một phần",
                EXHAUSTED: "Hết lượt",
              },
            },
          ],
          nextStageIds: [],
        },
      ],
    };
    const errors = validateDraftLocally(invalidAssessDraft);
    expect(errors.some((e) => e.path.endsWith("config.acceptedEvidenceIds"))).toBe(true);
  });
});
