"use client";

import { ErrorState } from "@/components/error-state";

/** Segment error boundary — keeps the shell, replaces only the page body. */
export default function AdminError({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="p-6">
      <ErrorState onRetry={reset} />
    </div>
  );
}
