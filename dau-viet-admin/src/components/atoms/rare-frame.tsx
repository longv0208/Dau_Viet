import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

export type RarityTier = "common" | "uncommon" | "rare" | "epic";

const RARITY_CLASSES: Record<RarityTier, string> = {
  common: "border-border shadow-heritage bg-surface-alt",
  uncommon: "border-2 border-jade shadow-pixel-sm bg-jade/5",
  rare: "border-2 border-gold-dark shadow-pixel bg-warning/10",
  epic: "border-2 border-brand shadow-pixel-lg bg-brand/5",
};

export interface RareFrameProps {
  children: ReactNode;
  rarity?: RarityTier;
  className?: string;
}

export function RareFrame({
  children,
  rarity = "common",
  className,
}: RareFrameProps) {
  return (
    <div className={cn("rounded-lg p-3", RARITY_CLASSES[rarity], className)}>
      {children}
    </div>
  );
}
