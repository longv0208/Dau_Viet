import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

export type ClueTagColor = "jade" | "brand" | "gold" | "river" | "nature";

const SUBTLE_MAP: Record<ClueTagColor, string> = {
  jade: "bg-jade/15 text-jade-dark border-jade",
  river: "bg-jade/15 text-jade-dark border-jade",
  brand: "bg-brand/10 text-brand border-brand",
  gold: "bg-gold-dark/20 text-ink border-gold-dark",
  nature: "bg-success/20 text-ink border-success",
};

const FILLED_MAP: Record<ClueTagColor, string> = {
  jade: "bg-jade text-surface-alt border-jade-dark",
  river: "bg-jade text-surface-alt border-jade-dark",
  brand: "bg-brand text-surface-alt border-brand-press",
  gold: "bg-gold-dark text-surface-alt border-gold-dark",
  nature: "bg-success text-surface-alt border-success",
};

export interface ClueTagProps {
  label?: ReactNode;
  children?: ReactNode;
  icon?: LucideIcon;
  color?: ClueTagColor;
  filled?: boolean;
  active?: boolean;
  onClick?: () => void;
  className?: string;
}

export function ClueTag({
  label, children, icon: Icon, color = "jade", filled = false, active = false, onClick, className,
}: ClueTagProps) {
  const isFilled = filled || active;
  const classes = cn(
    "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-medium transition-colors",
    isFilled ? FILLED_MAP[color] : SUBTLE_MAP[color],
    onClick && "cursor-pointer hover:opacity-90",
    className,
  );
  const content = (
    <>
      {Icon && <Icon className="size-3.5 shrink-0" aria-hidden />}
      {label ?? children}
    </>
  );
  if (onClick) {
    return <button type="button" onClick={onClick} className={classes}>{content}</button>;
  }
  return <span className={classes}>{content}</span>;
}
