import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { AdminEventDossierLink } from "@/lib/dto/gamification";

import { DossierLinkTable } from "./dossier-link-table";

const ROWS: AdminEventDossierLink[] = [
  {
    dossierId: "d1",
    canonicalCode: "ngo-quyen",
    title: "Ngô Quyền",
    dossierType: "PERSON",
    status: "PUBLISHED",
    displayOrder: 1,
  },
  {
    dossierId: "d2",
    canonicalCode: "song-bach-dang",
    title: "Sông Bạch Đằng",
    dossierType: "LOCATION",
    status: "PUBLISHED",
    displayOrder: 2,
  },
];

describe("DossierLinkTable", () => {
  it("renders rows with localized type labels", () => {
    render(<DossierLinkTable rows={ROWS} onMove={vi.fn()} onRemove={vi.fn()} />);
    expect(screen.getByText("Ngô Quyền")).toBeInTheDocument();
    expect(screen.getByText("Sông Bạch Đằng")).toBeInTheDocument();
    expect(screen.getAllByText("Nhân vật").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Địa điểm").length).toBeGreaterThan(0);
  });

  it("calls onMove with the row index + direction", async () => {
    const onMove = vi.fn();
    render(<DossierLinkTable rows={ROWS} onMove={onMove} onRemove={vi.fn()} />);
    const downButtons = screen.getAllByRole("button", { name: "Xuống" });
    await userEvent.click(downButtons[0]!);
    expect(onMove).toHaveBeenCalledWith(0, 1);
  });

  it("calls onRemove with the dossierId", async () => {
    const onRemove = vi.fn();
    render(<DossierLinkTable rows={ROWS} onMove={vi.fn()} onRemove={onRemove} />);
    await userEvent.click(
      screen.getByRole("button", { name: "Gỡ Ngô Quyền" }),
    );
    expect(onRemove).toHaveBeenCalledWith("d1");
  });
});
