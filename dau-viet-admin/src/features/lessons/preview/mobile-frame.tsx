import type { ReactNode } from "react";

/**
 * Phone-width shell for the lesson preview — a fixed 390px column with a fake
 * status bar so the rendered content approximates what a learner sees in the
 * Flutter app. Read-only presentation, no interaction wiring.
 */
export function MobileFrame({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto w-full max-w-[390px] overflow-hidden rounded-3xl border border-border bg-white shadow-sm">
      <div className="flex items-center justify-between bg-ink px-5 py-1.5 text-[10px] font-medium text-white">
        <span>9:41</span>
        <span className="tracking-wide">Dấu Việt — Xem trước</span>
        <span aria-hidden>●●●</span>
      </div>
      <div className="max-h-[72vh] overflow-y-auto p-4">{children}</div>
    </div>
  );
}
