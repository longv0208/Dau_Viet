"use client";

import { useMutation } from "@tanstack/react-query";
import { ShieldCheck } from "lucide-react";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { LearnerLessonContent } from "@/lib/dto/publish";
import { Button } from "@/components/ui/button";

/**
 * Verify the learner-facing content after publish — fetches
 * GET /api/v1/lessons/{id}/content (the same endpoint the Flutter app calls)
 * and shows the versionNo it resolves to, so the admin can confirm the
 * published snapshot is reachable with a Bearer token.
 */
export function VerifyContentCard({ lessonId }: { lessonId: string }) {
  const [checked, setChecked] = useState(false);
  const verify = useMutation({
    mutationFn: () => apiFetch<LearnerLessonContent>(`/lessons/${lessonId}/content`),
    onSuccess: () => setChecked(true),
  });

  const stageCount = (() => {
    const content = verify.data?.content;
    if (content && typeof content === "object" && !Array.isArray(content)) {
      const stages = (content as Record<string, unknown>).stages;
      if (Array.isArray(stages)) return stages.length;
    }
    return null;
  })();

  return (
    <section className="flex flex-col gap-2 rounded-md border border-border bg-surface-alt p-3 shadow-heritage">
      <h4 className="flex items-center gap-1.5 text-sm font-semibold text-ink">
        <ShieldCheck className="size-4 text-success" aria-hidden />
        Kiểm tra nội dung học viên
      </h4>
      <p className="text-xs text-ink-muted">
        Kiểm tra xem học viên đã đọc được nội dung bài học từ ứng dụng chưa.
      </p>

      {verify.isSuccess && (
        <div
          role="status"
          className="flex flex-col gap-1 rounded bg-success/10 px-3 py-2 text-xs text-success"
        >
          <p className="font-medium">
            Phiên bản {verify.data.versionNo ?? "?"} đang phát hành — học viên đã đọc được nội dung
            {stageCount !== null ? ` · ${stageCount} giai đoạn` : ""}.
          </p>
        </div>
      )}
      {verify.isError && (
        <p role="alert" className="rounded bg-error/10 px-3 py-2 text-xs text-error">
          {toUserMessage(verify.error)}
        </p>
      )}

      <Button
        variant="secondary"
        size="sm"
        className="self-start"
        disabled={verify.isPending}
        onClick={() => verify.mutate()}
      >
        {verify.isPending ? "Đang kiểm tra..." : checked ? "Kiểm tra lại" : "Kiểm tra nội dung"}
      </Button>
    </section>
  );
}
