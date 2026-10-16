"use client";

import { useEffect } from "react";

/**
 * Warn while a form is dirty on both browser-level unload (reload/close)
 * and in-app navigation — a capture-phase click listener intercepts any
 * internal <a href="/..."> (covers next/link, sidebar, breadcrumbs) and
 * confirms before letting it proceed.
 */
export function useUnsavedChangesGuard(isDirty: boolean) {
  useEffect(() => {
    if (!isDirty) return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = "";
    };
    const onClick = (e: MouseEvent) => {
      if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) {
        return;
      }
      const anchor = (e.target as HTMLElement | null)?.closest?.("a[href]");
      const href = anchor?.getAttribute("href") ?? "";
      if (!href.startsWith("/")) return;
      if (!window.confirm("Bạn có thay đổi chưa lưu. Bỏ các thay đổi này?")) {
        e.preventDefault();
        e.stopPropagation();
      }
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    document.addEventListener("click", onClick, true);
    return () => {
      window.removeEventListener("beforeunload", onBeforeUnload);
      document.removeEventListener("click", onClick, true);
    };
  }, [isDirty]);
}

/** Confirm helper used by Cancel buttons. */
export function confirmDiscard(isDirty: boolean): boolean {
  if (!isDirty) return true;
  return window.confirm("Bạn có thay đổi chưa lưu. Bỏ các thay đổi này?");
}
