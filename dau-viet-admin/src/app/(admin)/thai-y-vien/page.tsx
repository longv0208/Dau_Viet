import { PageGuideBanner } from "@/components/page-guide-banner";
import { ThaiYVienManager } from "@/features/thai-y-vien/thai-y-vien-manager";

export default function ThaiYVienPage() {
  return (
    <div>
      <PageGuideBanner
        storageKey="thai-y-vien"
        title="Viện Thái Y & Thể lực"
        purpose="Cấu hình giới hạn Thể lực (⚡), mức trừ khi trả lời sai, chu kỳ hồi tự nhiên và danh mục phương thuốc hồi thể lực bằng Điểm Sử Ký."
        appSurface="Hiển thị trên thanh Thể lực ở đầu màn hình học tập và cửa sổ Viện Thái Y khi học viên cần hồi phục thể lực."
        nextStep="Cân chỉnh thông số thể lực hợp lý để khuyến khích học viên suy luận cẩn trọng mà không gây đứt quãng trải nghiệm."
      />
      <ThaiYVienManager />
    </div>
  );
}
