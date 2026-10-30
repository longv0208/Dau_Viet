import { cn } from "@/lib/utils";

export interface ChapterBadgeProps {
  label: string | number;
  size?: number;
  filled?: boolean;
  className?: string;
}

export function ChapterBadge({
  label,
  size = 36,
  filled = false,
  className,
}: ChapterBadgeProps) {
  return (
    <span
      style={{ width: size, height: size }}
      className={cn(
        "inline-flex shrink-0 items-center justify-center rounded-full border-2 border-chapter font-display text-sm font-bold tabular-nums shadow-pixel-sm",
        filled ? "bg-chapter text-surface-alt" : "bg-surface-alt text-chapter",
        className,
      )}
    >
      {label}
    </span>
  );
}
