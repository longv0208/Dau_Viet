import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

import { SectionEyebrow, type SectionEyebrowColor } from "./section-eyebrow";

export interface SectionDividerProps {
  eyebrow?: ReactNode;
  eyebrowColor?: SectionEyebrowColor;
  title?: ReactNode;
  description?: ReactNode;
  action?: ReactNode;
  className?: string;
}

export function SectionDivider({
  eyebrow,
  eyebrowColor = "chapter",
  title,
  description,
  action,
  className,
}: SectionDividerProps) {
  return (
    <div
      className={cn(
        "flex flex-wrap items-end justify-between gap-2 border-b-4 border-heading pb-2",
        className,
      )}
    >
      <div>
        {eyebrow && (
          <div className="mb-1.5">
            <SectionEyebrow color={eyebrowColor}>{eyebrow}</SectionEyebrow>
          </div>
        )}
        {title && <h2 className="font-display text-lg font-bold text-chapter">{title}</h2>}
        {description && <p className="mt-0.5 text-xs text-ink-muted">{description}</p>}
      </div>
      {action}
    </div>
  );
}
