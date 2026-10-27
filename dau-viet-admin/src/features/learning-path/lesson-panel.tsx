"use client";

import { useState } from "react";
import Link from "next/link";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { ExternalLink, ImageIcon, Trash2 } from "lucide-react";
import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import type { PathEvent, PathLesson } from "@/lib/dto/learning-path";
import { Button } from "@/components/ui/button";
import { StatusChip } from "@/components/status-chip";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { ErrorState } from "@/components/error-state";
import { useAssetObjectUrl } from "@/features/assets/use-asset-object-url";
import { SortableList } from "./sortable-list";
import type { PathChange } from "./builder-types";

function LessonThumbnail({ coverAssetId, title }: { coverAssetId?: string | null; title: string | null }) {
  const contentUrl = coverAssetId ? `/api/v1/admin/assets/${coverAssetId}/content` : null;
  const { src, loading, error } = useAssetObjectUrl(contentUrl);

  if (!coverAssetId || error) {
    return (
      <div
        className="flex h-9 w-16 shrink-0 items-center justify-center rounded border border-border bg-surface text-ink-muted"
        title="Chưa cấu hình ảnh bìa"
      >
        <ImageIcon className="size-3.5 opacity-60" aria-hidden />
      </div>
    );
  }

  if (loading || !src) {
    return (
      <div className="h-9 w-16 shrink-0 animate-pulse rounded border border-border bg-surface" />
    );
  }

  return (
    <div className="h-9 w-16 shrink-0 overflow-hidden rounded border border-border bg-surface">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={src}
        alt={title ?? "Ảnh bìa bài học"}
        className="h-full w-full object-cover"
      />
    </div>
  );
}

export function LessonPanel({ event, disabled, readOnly, change }: {
  event: PathEvent; disabled: boolean; readOnly: boolean; change: PathChange;
}) {
  const [page, setPage] = useState(0);
  const [removing, setRemoving] = useState<PathLesson | null>(null);
  const query = useQuery({
    queryKey: ["learning-path", "lesson-catalog", event.node.eventId, page],
    queryFn: () =>
      apiFetch<PageResponse<AdminLessonSummary>>(
        `/admin/lessons${toQuery({ eventId: event.node.eventId, page, size: 12 })}`,
      ),
    enabled: !readOnly,
    placeholderData: keepPreviousData,
  });
  const attached = new Set(event.lessons.map((row) => row.node.lessonId));
  const catalogCoverById = new Map(
    (query.data?.content ?? []).map((item) => [item.id, item.coverAssetId ?? null]),
  );
  const policyLabel = (id: string) =>
    event.requiredLessonIds?.includes(id)
      ? "Bắt buộc theo policy"
      : event.optionalLessonIds?.includes(id)
        ? "Tùy chọn theo policy"
        : "Ngoài policy hoàn thành";
  const missing = event.requiredLessonIds?.filter((id) => !attached.has(id)).length ?? 0;

  return (
    <section aria-label={`Bài học của ${event.title}`} className="space-y-3 rounded-lg border border-brand/20 bg-surface p-4">
      <div>
        <h3 className="font-display text-lg font-semibold">Bài học · {event.title}</h3>
        <p className="mt-1 text-xs text-ink-muted">
          Thứ tự bài học và điều kiện hoàn thành sự kiện là hai cấu hình riêng. Sắp xếp ở đây không thay đổi policy.
        </p>
      </div>
      {!event.publishedPolicyId && (
        <p className="text-sm text-error">Sự kiện chưa có completion policy đã xuất bản.</p>
      )}
      {missing > 0 && (
        <p role="status" className="text-sm text-error">
          Còn thiếu {missing} bài bắt buộc theo policy trong lộ trình.
        </p>
      )}
      <SortableList
        items={event.lessons}
        getId={(row) => row.node.id}
        scope={`lessons:${event.node.id}`}
        disabled={disabled || readOnly}
        onReorder={(lessonNodeIds) =>
          change(`/events/${event.node.id}/lessons/reorder`, "PUT", { lessonNodeIds })
        }
      >
        {(lesson) => {
          const coverId = catalogCoverById.get(lesson.node.lessonId) ?? lesson.coverAssetId ?? null;
          return (
            <div className="py-1">
              <div className="flex items-start justify-between gap-2">
                <div className="flex min-w-0 items-start gap-2.5">
                  <LessonThumbnail coverAssetId={coverId} title={lesson.title} />
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-1.5">
                      <p className="font-medium">
                        {lesson.node.sortOrder}. {lesson.title ?? "Bài học không còn tồn tại"}
                      </p>
                      <Link
                        href={`/lessons/${lesson.node.lessonId}`}
                        className="inline-flex items-center gap-0.5 rounded px-1.5 py-0.5 text-[11px] font-medium text-brand hover:bg-brand/10 hover:underline"
                        title="Mở màn chỉnh sửa bài học & ảnh bìa"
                      >
                        Sửa bài <ExternalLink className="size-2.5" aria-hidden />
                      </Link>
                    </div>
                    <p className="mt-0.5 text-xs text-ink-muted">{policyLabel(lesson.node.lessonId)}</p>
                  </div>
                </div>
                {!readOnly && (
                  <Button
                    variant="ghost"
                    size="icon"
                    disabled={disabled}
                    aria-label={`Gỡ bài ${lesson.title}`}
                    onClick={() => setRemoving(lesson)}
                  >
                    <Trash2 aria-hidden />
                  </Button>
                )}
              </div>
              <div className="mt-2">
                <StatusChip status={lesson.status} />
              </div>
              {lesson.status !== "PUBLISHED" && (
                <p className="mt-1 text-xs text-error">
                  Bài chưa xuất bản; cần xem lại trước khi xuất bản lộ trình.
                </p>
              )}
            </div>
          );
        }}
      </SortableList>
      {event.lessons.length === 0 && <p className="text-sm text-ink-muted">Chưa gắn bài học nào.</p>}
      {!readOnly && (
        <div className="space-y-2 border-t border-border pt-3">
          <h4 className="text-sm font-semibold">Thêm bài từ sự kiện này</h4>
          {query.isPending && <p className="text-xs text-ink-muted">Đang tải bài học…</p>}
          {query.isError && <ErrorState error={query.error} onRetry={() => void query.refetch()} />}
          {query.data && (
            <>
              <ul className="divide-y divide-border">
                {query.data.content.map((lesson) => (
                  <li key={lesson.id} className="flex items-center justify-between gap-2 py-2">
                    <div className="flex min-w-0 items-center gap-2.5">
                      <LessonThumbnail coverAssetId={lesson.coverAssetId} title={lesson.title} />
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-1.5">
                          <p className="text-sm font-medium">{lesson.title}</p>
                          <Link
                            href={`/lessons/${lesson.id}`}
                            className="inline-flex items-center gap-0.5 rounded px-1.5 py-0.5 text-[11px] font-medium text-brand hover:bg-brand/10 hover:underline"
                          >
                            Sửa bài <ExternalLink className="size-2.5" aria-hidden />
                          </Link>
                        </div>
                        <p className="text-xs text-ink-muted">{policyLabel(lesson.id)}</p>
                        <StatusChip status={lesson.status} />
                      </div>
                    </div>
                    <Button
                      variant="secondary"
                      size="sm"
                      disabled={
                        disabled ||
                        attached.has(lesson.id) ||
                        query.isPlaceholderData ||
                        lesson.eventId !== event.node.eventId
                      }
                      onClick={() =>
                        void change(`/events/${event.node.id}/lessons`, "POST", { lessonId: lesson.id })
                      }
                    >
                      {attached.has(lesson.id) ? "Đã gắn" : "Gắn bài"}
                    </Button>
                  </li>
                ))}
              </ul>
              {query.data.content.length === 0 && (
                <p className="text-sm text-ink-muted">Sự kiện chưa có bài học trong thư viện.</p>
              )}
              <div className="flex items-center justify-between">
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={page === 0 || query.isFetching}
                  onClick={() => setPage((value) => value - 1)}
                >
                  Trước
                </Button>
                <span className="text-xs text-ink-muted">
                  Trang {page + 1} / {Math.max(1, query.data.totalPages)}
                </span>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={page + 1 >= query.data.totalPages || query.isFetching}
                  onClick={() => setPage((value) => value + 1)}
                >
                  Sau
                </Button>
              </div>
            </>
          )}
          <Link href={`/events/${event.node.eventId}`} className="inline-block text-xs text-brand underline">
            Mở Event Workspace để quản lý nội dung và policy
          </Link>
        </div>
      )}
      <ConfirmDialog
        open={removing != null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title="Gỡ bài khỏi lộ trình?"
        description="Bài học gốc, policy và kết quả học tập được giữ nguyên."
        destructive
        confirmLabel="Gỡ bài"
        onConfirm={() => {
          if (removing && !disabled) {
            void change(`/events/${event.node.id}/lessons/${removing.node.id}`, "DELETE");
          }
        }}
      />
    </section>
  );
}
