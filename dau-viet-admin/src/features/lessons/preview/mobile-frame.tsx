import type { ReactNode } from "react";

/**
 * Phone-width shell for the lesson preview — a fixed 390px column with a fake
 * status bar so the rendered content approximates what a learner sees in the
 * Flutter app. Read-only presentation, no interaction wiring.
 */
export function MobileFrame({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto w-full max-w-[390px] overflow-hidden rounded-3xl border-2 border-heading bg-surface-alt shadow-pixel">
      <div className="flex items-center justify-between bg-chapter px-5 py-1.5 text-[10px] font-medium text-surface-alt">
        <span>9:41</span>
        <span className="flex items-center gap-1 tracking-wide">
          {/* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */}
          <img src="/logo.svg" alt="" className="size-3.5 rounded-full object-cover" />
          Dấu Việt — Xem trước
        </span>
        <span aria-hidden>●●●</span>
      </div>
      <div className="max-h-[72vh] overflow-y-auto p-4">{children}</div>
    </div>
  );
}
