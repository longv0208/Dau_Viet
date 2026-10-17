import { Archive, CheckCircle2, FileEdit } from "lucide-react";

import { cn } from "@/lib/utils";

const CONFIG: Record<string, { label: string; className: string; icon: typeof FileEdit }> = {
  DRAFT: { label: "Bản nháp", className: "bg-warning/25 text-ink", icon: FileEdit },
  APPROVED: { label: "Đã phê duyệt", className: "bg-success/20 text-ink", icon: CheckCircle2 },
  PUBLISHED: { label: "Đã xuất bản", className: "bg-success/20 text-ink", icon: CheckCircle2 },
  ARCHIVED: { label: "Đã lưu trữ", className: "bg-surface-alt text-ink-muted", icon: Archive },
};

/** Status chip — text + icon (never color-only). */
export function StatusChip({ status }: { status: string }) {
  const cfg = CONFIG[status] ?? { label: "Khác", className: "bg-surface-alt text-ink", icon: FileEdit };
  const Icon = cfg.icon;
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium",
        cfg.className,
      )}
    >
      <Icon className="size-3.5" aria-hidden />
      {cfg.label}
    </span>
  );
}
