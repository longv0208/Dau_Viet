import { Suspense } from "react";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { LoginForm } from "@/features/auth/login-form";

export const metadata = { title: "Đăng nhập — Dấu Việt CMS" };

/** A-01 — centered login card on the cream surface. */
export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader className="items-center text-center">
          {/* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */}
          <img src="/logo.svg" alt="Dấu Việt" className="size-16 rounded-full object-cover" />
          <CardTitle className="text-2xl text-brand">Dấu Việt</CardTitle>
          <CardDescription>Đăng nhập quản trị nội dung</CardDescription>
        </CardHeader>
        <CardContent>
          <Suspense>
            <LoginForm />
          </Suspense>
        </CardContent>
      </Card>
    </div>
  );
}
