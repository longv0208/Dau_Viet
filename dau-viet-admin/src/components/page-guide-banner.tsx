"use client";

import { ChevronDown, ChevronUp, Compass, ExternalLink } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";

import { cn } from "@/lib/utils";

export interface PageGuideLink {
  href: string;
  label: string;
}

export interface PageGuideBannerProps {
  storageKey: string;
  title: string;
  purpose: string;
  appSurface: string;
  nextStep: string;
  links?: PageGuideLink[];
  className?: string;
}

/**
 * Khung hướng dẫn ngữ cảnh đầu trang (AC-4): giải thích rõ vai trò màn hình,
 * vị trí hiển thị trên ứng dụng học viên và bước tiếp theo kèm liên kết trực tiếp.
 */
export function PageGuideBanner({
  storageKey,
  title,
  purpose,
  appSurface,
  nextStep,
  links = [],
  className,
}: PageGuideBannerProps) {
  const [expanded, setExpanded] = useState(true);

  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(`dv_guide_${storageKey}`);
      if (saved === "collapsed") {
        setExpanded(false);
      }
    } catch {
      // Ignore storage access errors in restricted environments
    }
  }, [storageKey]);

  const toggle = () => {
    setExpanded((prev) => {
      const next = !prev;
      try {
        window.localStorage.setItem(
          `dv_guide_${storageKey}`,
          next ? "expanded" : "collapsed",
        );
      } catch {
        // Ignore storage errors
      }
      return next;
    });
  };

  return (
    <aside
      aria-label={`Hướng dẫn: ${title}`}
      className={cn(
        "mb-5 rounded-lg border border-border border-l-4 border-l-jade bg-surface-alt p-4 shadow-sm",
        className,
      )}
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Compass className="size-4 shrink-0 text-jade-dark" aria-hidden />
          <p className="font-sans text-xs font-bold uppercase tracking-wider text-jade-dark">
            Hướng dẫn nhanh · {title}
          </p>
        </div>
        <button
          type="button"
          onClick={toggle}
          aria-expanded={expanded}
          className="inline-flex items-center gap-1 rounded px-2 py-0.5 text-xs font-medium text-ink-muted transition-colors hover:bg-surface hover:text-ink"
        >
          <span>{expanded ? "Thu gọn hướng dẫn" : "Xem hướng dẫn"}</span>
          {expanded ? (
            <ChevronUp className="size-3.5" aria-hidden />
          ) : (
            <ChevronDown className="size-3.5" aria-hidden />
          )}
        </button>
      </div>

      {expanded && (
        <div className="mt-3 grid gap-3 border-t border-border pt-3 text-xs sm:grid-cols-3">
          <div>
            <p className="font-semibold text-ink">1. Trang này dùng để làm gì?</p>
            <p className="mt-1 leading-relaxed text-ink-secondary">{purpose}</p>
          </div>
          <div>
            <p className="font-semibold text-ink">2. Hiển thị ở đâu trên ứng dụng?</p>
            <p className="mt-1 leading-relaxed text-ink-secondary">{appSurface}</p>
          </div>
          <div>
            <p className="font-semibold text-ink">3. Bước tiếp theo &amp; liên kết</p>
            <p className="mt-1 leading-relaxed text-ink-secondary">{nextStep}</p>
            {links.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-2">
                {links.map((link) => (
                  <Link
                    key={link.href}
                    href={link.href}
                    className="inline-flex items-center gap-1 rounded-md border border-brand/30 bg-brand/10 px-2.5 py-1 text-[11px] font-semibold text-brand transition-colors hover:bg-brand hover:text-surface-alt"
                  >
                    <span>{link.label}</span>
                    <ExternalLink className="size-3 shrink-0" aria-hidden />
                  </Link>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </aside>
  );
}
