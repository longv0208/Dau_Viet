"use client";

import { useMutation } from "@tanstack/react-query";
import { RefreshCw } from "lucide-react";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { LearnerLessonContent } from "@/lib/dto/publish";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

import { parseDraft, type Draft } from "../builder/draft-model";
import { MobileFrame } from "./mobile-frame";
import type { EmbeddedAsset, EmbeddedEvidence } from "./renderers/types";
import { StageNav } from "./stage-nav";
import { StageView } from "./stage-view";

/**
 * Lesson preview — calls POST /admin/lessons/{id}/preview once and renders
 * the learner-safe projection inside a phone-width frame. Read-only: no
 * scoring, no submission, no attempt records.
 */
export function PreviewPage({ lessonId }: { lessonId: string }) {
  const preview = useMutation({
    mutationFn: () =>
      apiFetch<LearnerLessonContent>(`/admin/lessons/${lessonId}/preview`, {
        method: "POST",
      }),
  });
  const [selectedStageId, setSelectedStageId] = useState<string | null>(null);
  const [activityIndex, setActivityIndex] = useState(0);

  // Fire once on mount — POST semantics, so useMutation instead of useQuery.
  useEffect(() => {
    preview.mutate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lessonId]);

  const draft: Draft | null = useMemo(() => {
    if (!preview.data?.content) return null;
    try {
      return parseDraft(JSON.stringify(preview.data.content));
    } catch {
      return null;
    }
  }, [preview.data]);

  // Denormalized documents embedded by the preview/snapshot pipeline —
  // renderers resolve ids to titles/sources instead of showing raw uuids.
  const embedded = useMemo(() => {
    const content = preview.data?.content as Record<string, unknown> | undefined;
    const evidence = Array.isArray(content?.evidence)
      ? (content.evidence as EmbeddedEvidence[])
      : [];
    const assets = Array.isArray(content?.assets)
      ? (content.assets as EmbeddedAsset[])
      : [];
    return { evidence, assets };
  }, [preview.data]);

  const stages = draft?.stages ?? [];
  const currentStageId = selectedStageId ?? stages[0]?.id ?? null;
  const stage = stages.find((s) => s.id === currentStageId) ?? stages[0] ?? null;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <p className="rounded-md bg-warning/15 px-3 py-1.5 text-xs font-medium text-ink">
          Chế độ xem trước — chưa chấm điểm · hiển thị bản nháp đã lưu trên máy chủ
        </p>
        <div className="ml-auto flex gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => preview.mutate()}
            disabled={preview.isPending}
          >
            <RefreshCw className={"size-3.5 " + (preview.isPending ? "animate-spin" : "")} />
            Tải lại
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href={`/lessons/${lessonId}/builder`}>Quay lại trình soạn</Link>
          </Button>
        </div>
      </div>

      {preview.isPending && (
        <div className="mx-auto flex w-full max-w-[390px] flex-col gap-3">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-[30rem] w-full rounded-3xl" />
        </div>
      )}

      {preview.isError && (
        <p role="alert" className="rounded-md bg-error/10 px-4 py-3 text-sm text-error">
          {toUserMessage(preview.error)}
        </p>
      )}

      {preview.isSuccess && (
        <>
          {stages.length === 0 ? (
            <div className="rounded-md border border-dashed border-border px-6 py-12 text-center">
              <p className="text-sm text-ink-muted">
                Bản nháp chưa có giai đoạn nào — quay lại{" "}
                <Link href={`/lessons/${lessonId}/builder`} className="text-brand hover:underline">
                  trình soạn bài học
                </Link>{" "}
                để thêm nội dung.
              </p>
            </div>
          ) : (
            <div className="flex flex-col items-center gap-4">
              <StageNav
                stages={stages}
                selectedId={stage?.id ?? null}
                onSelect={(id) => {
                  setSelectedStageId(id);
                  setActivityIndex(0);
                }}
              />
              <MobileFrame>
                {stage && (
                  <StageView
                    stage={stage}
                    activityIndex={activityIndex}
                    onActivityChange={setActivityIndex}
                    evidence={embedded.evidence}
                    assets={embedded.assets}
                  />
                )}
              </MobileFrame>
            </div>
          )}
        </>
      )}
    </div>
  );
}
