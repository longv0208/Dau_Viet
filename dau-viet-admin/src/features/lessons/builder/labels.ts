/** Vietnamese labels + lucide icons for stage & activity types. */
import {
  ArrowDownUp,
  BookOpen,
  CheckSquare,
  Compass,
  FileQuestion,
  GitBranch,
  HelpCircle,
  Image,
  Layers,
  Lightbulb,
  Link2,
  ListChecks,
  ListOrdered,
  MapPin,
  PenLine,
  Puzzle,
  Search,
  Shuffle,
  type LucideIcon,
} from "lucide-react";

import type { ActivityType, StageType } from "./draft-model";

export const STAGE_LABELS: Record<StageType, { label: string; description: string; icon: LucideIcon }> = {
  CONTEXT: { label: "Bối cảnh", description: "Đặt sự kiện vào bối cảnh lịch sử", icon: BookOpen },
  DISCOVERY: { label: "Khám phá", description: "Học viên tự khám phá thông tin mới", icon: Compass },
  EVIDENCE: { label: "Bằng chứng", description: "Làm việc với tư liệu, bằng chứng", icon: Search },
  REASONING: { label: "Suy luận", description: "Phân tích, so sánh, lập luận", icon: Puzzle },
  HYPOTHESIS: { label: "Giả thuyết", description: "Đưa ra và chọn giả thuyết", icon: Lightbulb },
  RECONSTRUCTION: { label: "Tái dựng", description: "Dựng lại diễn biến sự kiện", icon: GitBranch },
  VERIFICATION: { label: "Kiểm chứng", description: "Đối chiếu giả thuyết với bằng chứng", icon: CheckSquare },
  CONCLUSION: { label: "Kết luận", description: "Rút ra kết luận có lập luận", icon: Layers },
  REFLECTION: { label: "Suy ngẫm", description: "Liên hệ và ghi nhận cảm nhận", icon: PenLine },
};

export const ACTIVITY_LABELS: Record<
  ActivityType,
  { label: string; description: string; icon: LucideIcon }
> = {
  READ: { label: "Đọc tư liệu", description: "Đoạn văn bản học viên đọc", icon: BookOpen },
  VIEW_IMAGE: { label: "Quan sát hình ảnh", description: "Hình ảnh kèm chú thích", icon: Image },
  MULTIPLE_CHOICE: { label: "Trắc nghiệm", description: "Câu hỏi nhiều lựa chọn", icon: ListOrdered },
  EXPLORE_MAP: { label: "Khám phá bản đồ", description: "Đánh dấu vị trí trên bản đồ", icon: MapPin },
  EVIDENCE_SELECT: { label: "Chọn bằng chứng", description: "Chọn bằng chứng phù hợp", icon: Search },
  MATCHING: { label: "Ghép cặp", description: "Nối các cặp tương ứng", icon: Shuffle },
  REASONING_CONNECT: { label: "Kết nối lập luận", description: "Nối các khái niệm quan hệ", icon: Link2 },
  HYPOTHESIS_CHOICE: { label: "Chọn giả thuyết", description: "Chọn giả thuyết hợp lý", icon: HelpCircle },
  DRAG_ORDER: { label: "Sắp xếp diễn biến", description: "Sắp xếp theo thứ tự đúng", icon: ArrowDownUp },
  VERIFICATION: { label: "Kiểm chứng", description: "Xác nhận/bác bỏ khẳng định", icon: CheckSquare },
  CER: { label: "Kết luận có dẫn chứng", description: "Viết lập luận có dẫn chứng", icon: FileQuestion },
  CER_CHOICE: { label: "Kết luận có dẫn chứng (chọn)", description: "Chọn lập luận - bằng chứng - suy luận", icon: ListChecks },
  REFLECTION_PROMPT: { label: "Câu hỏi suy ngẫm", description: "Câu hỏi mở cho học viên", icon: PenLine },
};
