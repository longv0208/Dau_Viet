import Link from "next/link";
import { FileQuestion } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

/** 404 inside the admin segment. */
export default function AdminNotFound() {
  return (
    <div className="flex items-center justify-center p-10">
      <Card className="w-full max-w-md">
        <CardContent className="flex flex-col items-center gap-3 py-10 text-center">
          {/* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */}
          <img src="/logo.svg" alt="Dấu Việt" className="mb-1 h-12 w-auto object-contain" />
          <FileQuestion className="size-12 text-ink-muted" aria-hidden />
          <h1 className="font-display text-xl font-semibold">Không tìm thấy trang</h1>
          <p className="text-sm text-ink-muted">
            Đường dẫn bạn truy cập không tồn tại hoặc đã bị di chuyển.
          </p>
          <Button asChild variant="secondary">
            <Link href="/dashboard">Về trang tổng quan</Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
