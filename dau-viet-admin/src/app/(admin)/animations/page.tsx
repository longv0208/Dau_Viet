import { PageHeader } from "@/components/page-header";
import { AnimationLibrary } from "@/features/animations/animation-library";

export const metadata = { title: "Hoạt họa lịch sử — Dấu Việt CMS" };

export default function AnimationsPage() {
  return (
    <div>
      <PageHeader
        title="Thư viện hoạt họa"
        description="Tải lên và quản lý hoạt họa HTML — một tệp .html tự chứa cho mỗi cảnh."
      />
      <AnimationLibrary />
    </div>
  );
}
