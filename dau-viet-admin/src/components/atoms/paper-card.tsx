import * as React from "react";

import { cn } from "@/lib/utils";

export interface PaperCardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  className?: string;
  interactive?: boolean;
  onClick?: React.MouseEventHandler<HTMLDivElement>;
  usePixelShadow?: boolean;
}

export const PaperCard = React.forwardRef<HTMLDivElement, PaperCardProps>(
  ({ children, className, interactive = false, onClick, usePixelShadow = false, ...props }, ref) => {
    return (
      <div
        ref={ref}
        onClick={onClick}
        className={cn(
          "rounded-lg bg-surface-alt text-ink",
          usePixelShadow
            ? "border-2 border-heading shadow-pixel"
            : "border border-border shadow-heritage",
          interactive &&
            "cursor-pointer transition-all hover:-translate-y-0.5 hover:border-brand hover:shadow-pixel-sm",
          className,
        )}
        {...props}
      >
        {children}
      </div>
    );
  },
);
PaperCard.displayName = "PaperCard";
