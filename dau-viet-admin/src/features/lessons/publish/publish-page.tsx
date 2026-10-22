"use client";

import { skipToken, useQuery, useQueryClient } from "@tanstack/react-query";
import { Eye } from "lucide-react";
import Link from "next/link";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import type { AdminEventDetail } from "@/lib/dto/event";
import type { AdminLessonDetail, LessonTemplate } from "@/lib/dto/lesson";
import type { PublishResponse } from "@/lib/dto/publish";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ErrorState } from "@/components/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";

import { PublishReadinessCard } from "../builder/publish-readiness-card";
import { LessonArchiveButton } from "./lesson-archive-button";
import { PublishButton } from "./publish-button";
import { VerifyContentCard } from "./verify-content-card";

function parseObjectives(json: string): string[] {
  try {
    const arr = JSON.parse(json);
    return Array.isArray(arr) ? arr.filter((x) => typeof x === "string") : [];
  } catch {
    return [];
  }
}

/**
 * Publish screen — lesson metadata + readiness check + publish action +
 * post-publish learner verification. Supports republish: editing the draft
 * of a PUBLISHED lesson and publishing again bumps versionNo while the old
 * snapshot stays immutable.
 */
export function PublishPage({ lessonId }: { lessonId: string }) {
  const qc = useQueryClient();
  const [conflict, setConflict] = useState(false);
  const [lastPublished, setLastPublished] = useState<PublishResponse | null>(null);

  const lessonQuery = useQuery({
    queryKey: qk.lessons.detail(lessonId),
    queryFn: () => apiFetch<AdminLessonDetail>(`/admin/lessons/${lessonId}`),
  });
  const lesson = lessonQuery.data;

  const eventQuery = useQuery({
    queryKey: qk.events.detail(lesson?.eventId ?? "none"),
    queryFn: lesson?.eventId
      ? () => apiFetch<AdminEventDetail>(`/admin/events/${lesson.eventId}`)
      : skipToken,
  });
  const templatesQuery = useQuery({
    queryKey: qk.templates.list(),
    queryFn: () => apiFetch<LessonTemplate[]>("/admin/lesson-templates"),
  });
  const template = templatesQuery.data?.find((t) => t.id === lesson?.templateId);

  if (lessonQuery.isPending) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-8 w-80" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }
  if (lessonQuery.isError) {
    return <ErrorState error={lessonQuery.error} onRetry={() => lessonQuery.refetch()} />;
  }
  if (!lesson) return null;

  const event = eventQuery.data;
  const objectives = parseObjectives(lesson.objectivesJson);
  const publishedInfo = lastPublished;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center gap-3">
        <StatusChip status={lesson.status} />
        <span className="text-sm font-medium text-ink">{lesson.title}</span>
        <Button asChild variant="secondary" size="sm" className="ml-auto">
          <Link href={`/lessons/${lesson.id}/preview`}>
            <Eye className="size-4" /> Xem trước
          </Link>
        </Button>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Sự kiện</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-1">
            {eventQuery.isPending && <Skeleton className="h-6 w-48" />}
            {event && (
              <>
                <p className="text-sm font-medium text-ink">{event.title}</p>
                <div className="flex items-center gap-2">
                  <StatusChip status={event.status} />
                  {event.status !== "PUBLISHED" && (
                    <Link
                      href={`/events/${event.id}`}
                      className="text-xs font-medium text-brand hover:underline"
                    >
                      Xuất bản sự kiện trước →
                    </Link>
                  )}
                </div>
              </>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Khung bài học</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm font-medium text-ink">{template?.name ?? "—"}</p>
            {template && <p className="mt-1 text-xs text-ink-muted">{template.description}</p>}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Thông tin bài học</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-2 text-sm">
          <div>
            <span className="text-ink-muted">Câu hỏi trung tâm: </span>
            <span className="text-ink">{lesson.centralQuestion}</span>
          </div>
          {objectives.length > 0 && (
            <div>
              <span className="text-ink-muted">Mục tiêu: </span>
              <ul className="ml-4 list-disc">
                {objectives.map((o, i) => (
                  <li key={i} className="text-ink">{o}</li>
                ))}
              </ul>
            </div>
          )}
          <div className="text-ink-muted">
            Phiên bản đang phát hành:{" "}
            {lesson.currentVersionId ? "Đã xuất bản" : "chưa có — bài học chưa từng xuất bản"}
          </div>
        </CardContent>
      </Card>

      <PublishReadinessCard lessonId={lesson.id} />

      {conflict && (
        <div className="flex flex-wrap items-center gap-3 rounded-md bg-error/10 px-3 py-2 text-sm text-error">
          <p>Bài học đã bị sửa đồng thời — dữ liệu trên trang có thể cũ.</p>
          <Button
            variant="secondary"
            size="sm"
            onClick={async () => {
              setConflict(false);
              await qc.invalidateQueries({ queryKey: qk.lessons.detail(lessonId) });
            }}
          >
            Tải lại bản mới nhất
          </Button>
        </div>
      )}

      {publishedInfo && (
        <div
          role="status"
          className="flex flex-col gap-1 rounded-md bg-success/10 px-4 py-3 text-sm text-success"
        >
          <p className="font-semibold">
            Đã xuất bản phiên bản {publishedInfo.versionNo} thành công.
          </p>
          <p className="text-xs text-ink-muted">
            Thời điểm: {new Date(publishedInfo.publishedAt).toLocaleString("vi-VN")}
          </p>
        </div>
      )}

      <PublishButton
        lesson={lesson}
        onPublished={(res) => {
          setConflict(false);
          setLastPublished(res);
        }}
        onConflict={() => setConflict(true)}
      />

      <LessonArchiveButton lesson={lesson} />

      {(lesson.currentVersionId || publishedInfo) && <VerifyContentCard lessonId={lesson.id} />}
    </div>
  );
}
