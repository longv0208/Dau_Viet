import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";
import { parseDraft } from "@/features/lessons/builder/draft-model";

import { TemplateForm } from "./template-form";

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

function renderForm(templateId?: string) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <TemplateForm templateId={templateId} />
    </QueryClientProvider>,
  );
}

describe("TemplateForm — save round-trip keeps activities", () => {
  it("POSTs a presetJson that contains the activities added in the designer", async () => {
    authStore.setAccessToken("t", 900);
    let posted: Record<string, unknown> | null = null;
    server.use(
      http.post("*/api/proxy/admin/lesson-templates", async ({ request }) => {
        posted = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(
          {
            id: "77777777-7777-7777-7777-777777777777",
            code: posted.code,
            name: posted.name,
            description: posted.description ?? null,
            schemaVersion: 1,
            presetJson: posted.presetJson,
            enabled: true,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z",
          },
          { status: 201 },
        );
      }),
    );

    renderForm();
    await userEvent.type(screen.getByLabelText(/Tên khung/), "Khung thử nghiệm");
    // Add one activity from the library — creates the stage automatically.
    await userEvent.click(
      screen.getAllByRole("button", { name: /Thêm hoạt động Sắp xếp diễn biến/ })[0]!,
    );
    await userEvent.click(screen.getByRole("button", { name: "Tạo khung bài học" }));

    await waitFor(() => expect(posted).not.toBeNull());
    const preset = parseDraft(posted!.presetJson as string);
    // Default preset already contains a RECONSTRUCTION stage — the activity
    // lands inside it, no duplicate stage is created.
    const recon = preset.stages.find((s) => s.type === "RECONSTRUCTION");
    expect(recon?.activities).toHaveLength(1);
    expect(recon?.activities[0]!.type).toBe("DRAG_ORDER");
    // Exactly one RECONSTRUCTION stage — no accidental duplicate.
    expect(preset.stages.filter((s) => s.type === "RECONSTRUCTION")).toHaveLength(1);
    // Linear links rebuilt across the whole list.
    for (let i = 0; i < preset.stages.length - 1; i++) {
      expect(preset.stages[i]!.nextStageIds).toEqual([preset.stages[i + 1]!.id]);
    }
  });

  it("edit mode rehydrates existing activities instead of wiping them", async () => {
    authStore.setAccessToken("t", 900);
    const presetJson = JSON.stringify({
      schemaVersion: 1,
      stages: [
        {
          id: "ctx",
          type: "CONTEXT",
          title: "Bối cảnh",
          required: true,
          activities: [
            { id: "rd1", type: "READ", required: false, instruction: "Đọc", config: { text: "x" } },
          ],
          nextStageIds: ["ev"],
        },
        {
          id: "ev",
          type: "EVIDENCE",
          title: "Bằng chứng",
          required: true,
          activities: [
            { id: "es1", type: "EVIDENCE_SELECT", required: true, instruction: "Chọn", config: {} },
          ],
          nextStageIds: [],
        },
      ],
    });
    let patched: Record<string, unknown> | null = null;
    server.use(
      http.get("*/api/proxy/admin/lesson-templates/tpl-1", () =>
        HttpResponse.json({
          id: "tpl-1",
          code: "khung-co-san",
          name: "Khung có sẵn",
          description: null,
          schemaVersion: 1,
          presetJson,
          enabled: true,
          createdAt: "2026-01-01T00:00:00Z",
          updatedAt: "2026-01-01T00:00:00Z",
        }),
      ),
      http.patch("*/api/proxy/admin/lesson-templates/tpl-1", async ({ request }) => {
        patched = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ id: "tpl-1", code: "khung-co-san", presetJson: patched.presetJson });
      }),
    );

    renderForm("tpl-1");
    // Both activities rehydrate and show in the canvas.
    await waitFor(() => {
      expect(screen.getByText("Chọn bằng chứng")).toBeInTheDocument();
    });
    await userEvent.click(screen.getByRole("button", { name: "Lưu khung" }));
    await waitFor(() => expect(patched).not.toBeNull());
    const saved = parseDraft(patched!.presetJson as string);
    const ev = saved.stages.find((s) => s.id === "ev");
    expect(ev?.activities).toHaveLength(1);
    expect(ev?.activities[0]!.type).toBe("EVIDENCE_SELECT");
    // Custom config survives the round-trip (no clobber to {}).
    const ctx = saved.stages.find((s) => s.id === "ctx");
    expect(ctx?.activities[0]!.config).toEqual({ text: "x" });
  });
});
