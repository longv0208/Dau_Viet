import { Archive, CheckCircle2, FileEdit } from "lucide-react";

import { cn } from "@/lib/utils";

const CONFIG: Record<string, { label: string; className: string; icon: typeof FileEdit }> = {
  DRAFT: {
    label: "Bản nháp",
    className: "bg-gold-dark/20 text-ink border border-gold-dark",
    icon: FileEdit,
  },
  APPROVED: {
    label: "Đã phê duyệt",
    className: "bg-jade/15 text-jade-dark border border-jade",
    icon: CheckCircle2,
  },
  PUBLISHED: {
    label: "Đã xuất bản",
    className: "bg-jade/15 text-jade-dark border border-jade",
    icon: CheckCircle2,
  },
  ARCHIVED: {
    label: "Đã lưu trữ",
    className: "bg-surface-alt text-ink-muted border border-border",
    icon: Archive,
  },
};

/** Status chip — text + icon (never color-only). */
export function StatusChip({ status }: { status: string }) {
  const cfg = CONFIG[status] ?? {
    label: "Khác",
    className: "bg-surface-alt text-ink border border-border",
    icon: FileEdit,
  };
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
