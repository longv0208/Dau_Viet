"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";

import { toUserMessage } from "@/lib/api-error";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { loginSchema, safeNext, type LoginFormValues } from "./schemas";
import { useLogin } from "./use-auth";

/** A-01 — email + password form, posts to the BFF login route. */
export function LoginForm() {
  const searchParams = useSearchParams();
  const login = useLogin();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  });

  const onSubmit = handleSubmit(async (values) => {
    try {
      await login.mutateAsync(values);
      // Full-page navigation (not router.replace): guarantees the just-set
      // dv_refresh cookie rides along — a client-side RSC fetch can race the
      // cookie commit and hit middleware with no cookie, bouncing to /login.
      window.location.assign(safeNext(searchParams.get("next")));
    } catch {
      // mutateAsync throws — login.isError already carries the message.
    }
  });

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          type="email"
          autoComplete="email"
          placeholder="admin@dauviet.local"
          aria-invalid={Boolean(errors.email)}
          {...register("email")}
        />
        {errors.email && (
          <p role="alert" className="text-xs text-error">
            {errors.email.message}
          </p>
        )}
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="password">Mật khẩu</Label>
        <Input
          id="password"
          type="password"
          autoComplete="current-password"
          aria-invalid={Boolean(errors.password)}
          {...register("password")}
        />
        {errors.password && (
          <p role="alert" className="text-xs text-error">
            {errors.password.message}
          </p>
        )}
      </div>

      {login.isError && (
        <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
          {toUserMessage(login.error)}
        </p>
      )}

      <Button type="submit" disabled={login.isPending} className="w-full">
        {login.isPending ? "Đang đăng nhập..." : "Đăng nhập"}
      </Button>
    </form>
  );
}
