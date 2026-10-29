import { Inbox, type LucideIcon } from "lucide-react";
import { isValidElement, type ReactNode } from "react";

import { cn } from "@/lib/utils";

import { PaperCard } from "./paper-card";

export type EmptyStateMood = "default" | "search" | "archive" | "warning" | (string & {});

const MOOD_ICON_COLOR: Record<string, string> = {
  default: "text-jade",
  search: "text-gold-dark",
  archive: "text-ink-muted",
  warning: "text-brand",
};

export interface EmptyStateCardProps {
  title?: string;
  description?: string;
  action?: ReactNode;
  icon?: LucideIcon | ReactNode;
  mood?: EmptyStateMood;
  className?: string;
}

export function EmptyStateCard({
  title = "Chưa có dữ liệu",
  description,
  action,
  icon,
  mood = "default",
  className,
}: EmptyStateCardProps) {
  const iconColor = MOOD_ICON_COLOR[mood] ?? "text-jade";
  const renderIcon = () => {
    if (!icon) return <Inbox className={cn("size-10", iconColor)} aria-hidden />;
    if (isValidElement(icon)) return icon;
    const IconComp = icon as LucideIcon;
    return <IconComp className={cn("size-10", iconColor)} aria-hidden />;
  };

  return (
    <PaperCard className={cn("flex flex-col items-center gap-3 p-5 py-12 text-center", className)}>
      {renderIcon()}
      <p className="font-display font-medium text-ink">{title}</p>
      {description && <p className="max-w-md text-sm text-ink-muted">{description}</p>}
      {action}
    </PaperCard>
  );
}
