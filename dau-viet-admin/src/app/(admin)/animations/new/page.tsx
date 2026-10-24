import { redirect } from "next/navigation";

export const metadata = { title: "Tạo hoạt họa — Dấu Việt CMS" };

// Quy trình tạo scene bằng template RIVER_TIDE/JOURNEY_MAP đã ngừng —
// hoạt họa giờ được tải lên dưới dạng file HTML tự chứa. Đường dẫn cũ
// redirect về thư viện có dropzone ngay trên trang.
export default function NewAnimationPage() {
  redirect("/animations");
}
