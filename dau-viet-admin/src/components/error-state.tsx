"use client";

import { AlertTriangle, RotateCcw } from "lucide-react";

import { ApiClientError, toUserMessage } from "@/lib/api-error";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

/** Error surface with optional retry + traceId for support. */
export function ErrorState({
  error,
  onRetry,
}: {
  error?: unknown;
  onRetry?: () => void;
}) {
  const traceId = error instanceof ApiClientError ? error.traceId : null;
  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-3 py-12 text-center">
        <AlertTriangle className="size-10 text-error" aria-hidden />
        <p className="font-medium text-ink">Có lỗi xảy ra</p>
        <p className="max-w-md text-sm text-ink-muted">
          {error ? toUserMessage(error) : "Không thể tải dữ liệu, vui lòng thử lại."}
        </p>
        {traceId && <p className="text-xs text-ink-muted">Mã tra cứu lỗi: {traceId}</p>}
        {onRetry && (
          <Button variant="secondary" onClick={onRetry}>
            <RotateCcw aria-hidden /> Thử lại
          </Button>
        )}
      </CardContent>
    </Card>
  );
}
