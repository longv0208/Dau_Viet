import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { QueryProvider } from "@/components/query-provider";
import { server } from "@/test/msw/server";

import { LoginForm } from "./login-form";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

function renderForm() {
  return render(
    <QueryProvider>
      <LoginForm />
    </QueryProvider>,
  );
}

describe("LoginForm", () => {
  it("shows Vietnamese validation errors on empty submit", async () => {
    renderForm();
    await userEvent.click(screen.getByRole("button", { name: /đăng nhập/i }));
    await waitFor(() => {
      expect(screen.getByText("Vui lòng nhập email")).toBeInTheDocument();
      expect(screen.getByText("Vui lòng nhập mật khẩu")).toBeInTheDocument();
    });
  });

  it("shows email-format error for malformed input", async () => {
    renderForm();
    await userEvent.type(screen.getByLabelText(/email/i), "not-an-email");
    await userEvent.type(screen.getByLabelText(/mật khẩu/i), "x");
    await userEvent.click(screen.getByRole("button", { name: /đăng nhập/i }));
    await waitFor(() =>
      expect(screen.getByText("Email không hợp lệ")).toBeInTheDocument(),
    );
  });

  it("shows INVALID_CREDENTIALS message on 401", async () => {
    server.use(
      http.post("*/api/auth/login", () =>
        HttpResponse.json(
          { code: "INVALID_CREDENTIALS", message: "bad credentials" },
          { status: 401 },
        ),
      ),
    );
    renderForm();
    await userEvent.type(screen.getByLabelText(/email/i), "a@b.co");
    await userEvent.type(screen.getByLabelText(/mật khẩu/i), "wrong");
    await userEvent.click(screen.getByRole("button", { name: /đăng nhập/i }));
    await waitFor(() =>
      expect(
        screen.getByText("Email hoặc mật khẩu không đúng"),
      ).toBeInTheDocument(),
    );
  });
});
