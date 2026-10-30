import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { authStore } from "@/features/auth/auth-store";

import { PolicyEditor } from "./policy-editor";

function renderEditor(props?: Partial<Parameters<typeof PolicyEditor>[0]>) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const onSubmit = vi.fn();
  const onValidate = vi.fn();
  const onCancel = vi.fn();
  const utils = render(
    <QueryClientProvider client={client}>
      <PolicyEditor
        eventId="11111111-1111-1111-1111-111111111111"
        initial={null}
        saving={false}
        validating={false}
        validation={null}
        onValidate={onValidate}
        onSubmit={onSubmit}
        onCancel={onCancel}
        {...props}
      />
    </QueryClientProvider>,
  );
  return { onSubmit, onValidate, onCancel, ...utils };
}

describe("PolicyEditor", () => {
  it("renders only the required lessons list and pre-selects published lessons by default", async () => {
    authStore.setAccessToken("t", 900);
    renderEditor();
    await waitFor(() =>
      expect(
        screen.getAllByText("Vì sao Ngô Quyền thắng trận Bạch Đằng?").length,
      ).toBe(1),
    );
    expect(screen.queryByText(/Bài học tuỳ chọn/i)).toBeNull();
    const checkbox = screen.getByRole("checkbox", {
      name: /vì sao ngô quyền thắng trận bạch đằng/i,
    });
    expect(checkbox).toBeChecked();
  });

  it("submits pre-selected required lessons + empty optionalLessonIds + threshold payload", async () => {
    authStore.setAccessToken("t", 900);
    const { onSubmit } = renderEditor();
    await waitFor(() =>
      expect(
        screen.getByRole("checkbox", {
          name: /vì sao ngô quyền thắng trận bạch đằng/i,
        }),
      ).toBeChecked(),
    );
    // Bat "Danh gia mastered" — mac dinh threshold = 70.
    await userEvent.click(screen.getByRole("checkbox", { name: /đánh giá mastered/i }));
    await userEvent.click(screen.getByRole("button", { name: /lưu bản nháp/i }));
    expect(onSubmit).toHaveBeenCalledWith({
      requiredLessonIds: ["33333333-3333-3333-3333-333333333333"],
      optionalLessonIds: [],
      masteryThreshold: 70,
      expectedPolicyVersion: null,
    });
  });

  it("validate button forwards the current draft payload with pre-selected requiredLessonIds", async () => {
    authStore.setAccessToken("t", 900);
    const { onValidate } = renderEditor();
    await waitFor(() =>
      expect(
        screen.getByRole("checkbox", {
          name: /vì sao ngô quyền thắng trận bạch đằng/i,
        }),
      ).toBeChecked(),
    );
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra/i }));
    expect(onValidate).toHaveBeenCalledWith(
      expect.objectContaining({
        requiredLessonIds: ["33333333-3333-3333-3333-333333333333"],
        optionalLessonIds: [],
      }),
    );
  });
  it("renders backend validation errors", async () => {
    authStore.setAccessToken("t", 900);
    renderEditor({
      validation: {
        valid: false,
        errors: [
          {
            code: "REQUIRED_EMPTY",
            message: "at least one required lesson is needed",
            field: "requiredLessonIds",
          },
        ],
        warnings: ["learners keep existing progress"],
        diff: null,
      },
    });
    await waitFor(() =>
      expect(screen.getByText(/REQUIRED_EMPTY/)).toBeInTheDocument(),
    );
    expect(screen.getByText(/learners keep existing progress/)).toBeInTheDocument();
  });
});
