import { render, screen } from "@testing-library/react";

import { Button } from "./button";

describe("Button", () => {
  it("renders children and is clickable", () => {
    render(<Button>Đăng nhập</Button>);
    expect(screen.getByRole("button", { name: "Đăng nhập" })).toBeInTheDocument();
  });

  it("is disabled when disabled prop set", () => {
    render(<Button disabled>Lưu</Button>);
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
  });
});
