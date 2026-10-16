import { Image as ImageIcon } from "lucide-react";

import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";

export const metadata = { title: "Thư viện media — Dấu Việt CMS" };

/** Honest coming-soon — upload pipeline is out of scope for the foundation. */
export default function AssetsPage() {
  return (
    <div>
      <PageHeader title="Thư viện media" />
      <Card>
        <CardContent className="flex flex-col items-center gap-3 py-12 text-center">
          <ImageIcon className="size-10 text-ink-muted" aria-hidden />
          <p className="font-medium text-ink">Sắp ra mắt</p>
          <p className="max-w-md text-sm text-ink-muted">
            Thư viện quản lý hình ảnh và tư liệu dùng trong bài học đang được xây dựng.
            Hiện tại bạn có thể nhúng tư liệu trực tiếp trong phần soạn bài học.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
