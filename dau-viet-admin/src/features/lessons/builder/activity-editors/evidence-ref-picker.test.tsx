import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { EvidenceRefPicker } from "./evidence-ref-picker";

function wrap(ui: React.ReactElement) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe("EvidenceRefPicker", () => {
  it("renders selected chips resolved via per-id fetch", async () => {
    wrap(
      <EvidenceRefPicker
        label="Bằng chứng"
        selectedIds={["e1111111-1111-1111-1111-111111111111"]}
        onChange={vi.fn()}
      />,
    );
    await waitFor(() =>
      expect(screen.getByText(/Cọc ngầm sông Bạch Đằng/)).toBeInTheDocument(),
    );
  });

  it("opens the panel and lists evidence from the library", async () => {
    const user = userEvent.setup();
    wrap(<EvidenceRefPicker label="Bằng chứng" selectedIds={[]} onChange={vi.fn()} />);
    await user.click(screen.getByRole("button", { name: /Chọn bằng chứng/ }));
    await waitFor(() =>
      expect(screen.getByText("Đại Việt sử ký toàn thư — trận Bạch Đằng")).toBeInTheDocument(),
    );
  });

  it("emits the id list when toggling an item", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    wrap(<EvidenceRefPicker label="Bằng chứng" selectedIds={[]} onChange={onChange} />);
    await user.click(screen.getByRole("button", { name: /Chọn bằng chứng/ }));
    const item = await screen.findByText("Cọc ngầm sông Bạch Đằng");
    await user.click(item);
    expect(onChange).toHaveBeenCalledWith(["e1111111-1111-1111-1111-111111111111"]);
  });

  it("shows the required alert when selection is empty", () => {
    wrap(
      <EvidenceRefPicker label="Bằng chứng" required selectedIds={[]} onChange={vi.fn()} />,
    );
    expect(screen.getByRole("alert")).toHaveTextContent(/ít nhất 1 bằng chứng/);
  });

  it("removes a chip via its X button", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    wrap(
      <EvidenceRefPicker
        label="Bằng chứng"
        selectedIds={["e1111111-1111-1111-1111-111111111111"]}
        onChange={onChange}
      />,
    );
    await waitFor(() => screen.getByText(/Cọc ngầm sông Bạch Đằng/));
    await user.click(screen.getByRole("button", { name: /Gỡ/ }));
    expect(onChange).toHaveBeenCalledWith([]);
  });
});
