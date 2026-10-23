import Link from "next/link";

import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { AnimationLibrary } from "@/features/animations/animation-library";

export const metadata = { title: "Hoạt họa lịch sử — Dấu Việt CMS" };

export default function AnimationsPage() {
  return (
    <div>
      <PageHeader
        title="Hoạt họa lịch sử"
        description="Soạn các cảnh hoạt họa tương tác gắn vào bài học — không cần viết code."
        actions={
          <Button asChild>
            <Link href="/animations/new">+ Tạo hoạt họa mới</Link>
          </Button>
        }
      />
      <AnimationLibrary />
    </div>
  );
}
