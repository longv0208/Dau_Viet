import {
  BookOpen,
  FileText,
  Image,
  Landmark,
  Map,
  ScrollText,
  type LucideIcon,
} from "lucide-react";

/** Evidence type catalogue — backend stores a free VARCHAR(48); client offers
 * a curated Vietnamese set plus free-text "Khác". Kept as plain strings so
 * any value already saved still renders. */
export const EVIDENCE_TYPES = [
  "VAN_BAN",
  "HIEN_VAT",
  "HINH_ANH",
  "BAN_DO",
  "LOI_KE",
  "GHI_CHEP",
  "KHAC",
] as const;

export type EvidenceTypeCode = (typeof EVIDENCE_TYPES)[number];

export const EVIDENCE_TYPE_LABELS: Record<string, { label: string; icon: LucideIcon }> = {
  VAN_BAN: { label: "Văn bản", icon: FileText },
  HIEN_VAT: { label: "Hiện vật", icon: Landmark },
  HINH_ANH: { label: "Hình ảnh", icon: Image },
  BAN_DO: { label: "Bản đồ", icon: Map },
  LOI_KE: { label: "Lời kể", icon: BookOpen },
  GHI_CHEP: { label: "Ghi chép", icon: ScrollText },
  KHAC: { label: "Khác", icon: FileText },
};

export const RELIABILITY_LABELS: Record<string, string> = {
  HIGH: "Độ tin cậy cao",
  MEDIUM: "Trung bình",
  LOW: "Thấp",
  UNASSESSED: "Chưa đánh giá",
};

export function evidenceTypeLabel(t: string): string {
  return EVIDENCE_TYPE_LABELS[t]?.label ?? t;
}
