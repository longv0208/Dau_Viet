import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { learnerUserFixture } from "@/test/fixtures";

import { ForbiddenState } from "./forbidden-state";

describe("ForbiddenState", () => {
  it("renders the 403 message with the account name", () => {
    render(<ForbiddenState user={learnerUserFixture} />);
    expect(screen.getByText("Không có quyền truy cập")).toBeInTheDocument();
    expect(
      screen.getByText(new RegExp(learnerUserFixture.displayName)),
    ).toBeInTheDocument();
  });

  it("offers a way back to login with a different account", () => {
    render(<ForbiddenState />);
    expect(
      screen.getByRole("link", { name: /đăng nhập tài khoản khác/i }),
    ).toBeInTheDocument();
  });
});
