import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

export type StampSealVariant = "default" | "success" | "outline";

const VARIANT_MAP: Record<StampSealVariant, string> = {
  default: "border-brand bg-brand/10 text-brand",
  success: "border-jade bg-jade/10 text-jade-dark",
  outline: "border-heading bg-surface-alt text-heading",
};

export interface StampSealProps {
  label?: ReactNode;
  children?: ReactNode;
  variant?: StampSealVariant;
  className?: string;
}

export function StampSeal({
  label,
  children,
  variant = "default",
  className,
}: StampSealProps) {
  return (
    <span
      className={cn(
        "inline-flex -rotate-[8deg] items-center justify-center rounded-full border-2 p-0.5 font-display text-[10px] font-bold uppercase tracking-widest shadow-pixel-sm",
        VARIANT_MAP[variant],
        className,
      )}
    >
      <span className="inline-flex items-center justify-center rounded-full border border-surface-alt px-2 py-1">
        {label ?? children ?? "ẤN"}
      </span>
    </span>
  );
}
