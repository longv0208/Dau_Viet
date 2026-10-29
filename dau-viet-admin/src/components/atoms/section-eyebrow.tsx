import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

export type SectionEyebrowColor = "brand" | "jade" | "gold" | "chapter";

const COLOR_MAP: Record<SectionEyebrowColor, string> = {
  brand: "bg-brand/10 border-brand text-brand",
  jade: "bg-jade/10 border-jade text-jade-dark",
  gold: "bg-gold-dark/10 border-gold-dark text-gold-dark",
  chapter: "bg-chapter/10 border-chapter text-chapter",
};

export interface SectionEyebrowProps {
  children: ReactNode;
  color?: SectionEyebrowColor;
  className?: string;
}

export function SectionEyebrow({
  children,
  color = "brand",
  className,
}: SectionEyebrowProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center border-2 px-2 py-0.5 font-mono text-[11px] font-bold uppercase tracking-wider shadow-pixel-sm",
        COLOR_MAP[color],
        className,
      )}
    >
      {children}
    </span>
  );
}
