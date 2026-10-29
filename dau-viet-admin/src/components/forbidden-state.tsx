import Link from "next/link";
import { ShieldAlert } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

/** 403 surface — shown when a non-CONTENT_ADMIN account reaches admin pages. */
export function ForbiddenState({ user }: { user?: { displayName?: string; role?: string } }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-surface p-6">
      <Card className="w-full max-w-md">
        <CardContent className="flex flex-col items-center gap-3 py-10 text-center">
          {/* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */}
          <img src="/logo.svg" alt="Dấu Việt" className="mb-1 h-12 w-auto object-contain" />
          <ShieldAlert className="size-12 text-error" aria-hidden />
          <h1 className="font-display text-xl font-semibold">Không có quyền truy cập</h1>
          <p className="text-sm text-ink-muted">
            {user?.displayName
              ? `Tài khoản ${user.displayName} không có quyền quản trị nội dung.`
              : "Tài khoản này không có quyền quản trị nội dung."}
          </p>
          <Button asChild variant="secondary">
            <Link href="/login">Đăng nhập tài khoản khác</Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
