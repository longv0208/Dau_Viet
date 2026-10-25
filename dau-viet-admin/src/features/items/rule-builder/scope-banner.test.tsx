import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { ScopeBanner } from "./scope-banner";

describe("ScopeBanner", () => {
  it("renders nothing when scope is missing", () => {
    const { container } = render(<ScopeBanner scope={null} />);
    expect(container).toBeEmptyDOMElement();
  });

  it("GLOBAL renders the success banner", () => {
    render(<ScopeBanner scope="GLOBAL" />);
    expect(
      screen.getByText(/phạm vi toàn hệ thống/i),
    ).toBeInTheDocument();
  });

  it("UNRESOLVED warns the item is awaiting event mapping", () => {
    render(<ScopeBanner scope="UNRESOLVED" />);
    expect(
      screen.getByText(/chưa minh định sự kiện/i),
    ).toBeInTheDocument();
  });

  it("EVENT_SCOPED warns the new rule must carry an event leaf", () => {
    render(<ScopeBanner scope="EVENT_SCOPED" />);
    expect(
      screen.getByText(/đã gắn phạm vi sự kiện/i),
    ).toBeInTheDocument();
  });
});
