import { PageHeader } from "@/components/page-header";
import { TemplatePicker } from "@/features/animations/template-picker";

export const metadata = { title: "Tạo hoạt họa — Dấu Việt CMS" };

export default function NewAnimationPage() {
  return (
    <div>
      <PageHeader
        title="Tạo hoạt họa mới"
        description="Chọn kiểu cảnh minh họa — chỉ hiện các kiểu mà ứng dụng học viên đã hỗ trợ."
      />
      <TemplatePicker />
    </div>
  );
}
