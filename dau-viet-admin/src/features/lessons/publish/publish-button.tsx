"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { AdminLessonDetail } from "@/lib/dto/lesson";
import type { PublishIssue, PublishResponse } from "@/lib/dto/publish";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";

interface Props {
  lesson: AdminLessonDetail;
  onPublished?: (res: PublishResponse) => void;
  onConflict?: () => void;
}

function readDetailErrors(err: ApiClientError): PublishIssue[] {
  const raw = err.details?.errors;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((x) => x && typeof x === "object")
    .map((x) => {
      const r = x as Record<string, unknown>;
      return {
        path: r.path === undefined ? undefined : String(r.path),
        code: r.code === undefined ? undefined : String(r.code),
        message: String(r.message ?? ""),
      };
    });
}

/**
 * Publish (or republish) the lesson — POST /admin/lessons/{id}/publish with
 * expectedRowVersion optimistic locking. Handles 409 conflict, 422 readiness
 * errors (incl. EVENT_NOT_PUBLISHED with a link to the event editor), and
 * blocks double submission via isPending.
 */
export function PublishButton({ lesson, onPublished, onConflict }: Props) {
  const qc = useQueryClient();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [detailErrors, setDetailErrors] = useState<PublishIssue[]>([]);

  const publish = useMutation({
    mutationFn: () =>
      apiFetch<PublishResponse>(`/admin/lessons/${lesson.id}/publish`, {
        method: "POST",
        body: JSON.stringify({ expectedRowVersion: lesson.rowVersion }),
      }),
    onSuccess: (res) => {
      setDetailErrors([]);
      qc.invalidateQueries({ queryKey: qk.lessons.detail(lesson.id) });
      qc.invalidateQueries({ queryKey: ["lessons"] });
      qc.invalidateQueries({ queryKey: qk.learner.content(lesson.id) });
      onPublished?.(res);
    },
    onError: (err) => {
      if (err instanceof ApiClientError) {
        if (err.isConflict) {
          onConflict?.();
          setDetailErrors([]);
          return;
        }
        if (err.status === 422) {
          setDetailErrors(readDetailErrors(err));
          return;
        }
      }
      setDetailErrors([]);
    },
  });

  const archived = lesson.status === "ARCHIVED";
  const republish = lesson.status === "PUBLISHED";
  const label = republish ? "Xuất bản phiên bản mới" : "Xuất bản bài học";
  const eventBlocked = detailErrors.some((e) => e.code === "EVENT_NOT_PUBLISHED");

  if (archived) {
    return (
      <p className="rounded-md bg-warning/15 px-3 py-2 text-sm text-ink">
        Bài học đã lưu trữ — không thể xuất bản.
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-3">
        <Button onClick={() => setConfirmOpen(true)} disabled={publish.isPending}>
          {publish.isPending ? "Đang xuất bản..." : label}
        </Button>
        {republish && (
          <p className="text-xs text-ink-muted">
            Bài học đã xuất bản — xuất bản lại sẽ tạo phiên bản mới từ bản nháp hiện tại;
            phiên bản cũ vẫn giữ nguyên cho tới khi phát hành.
          </p>
        )}
      </div>

      {publish.isError && !publish.error && null}
      {publish.isError &&
        publish.error instanceof ApiClientError &&
        publish.error.status === 422 &&
        detailErrors.length > 0 && (
          <div className="flex flex-col gap-2 rounded-md border border-error/40 bg-error/5 p-3">
            <p className="text-sm font-semibold text-error">
              Chưa thể xuất bản — còn {detailErrors.length} lỗi:
            </p>
            <ul className="flex flex-col gap-1">
              {detailErrors.map((e, i) => (
                <li key={i} className="text-xs text-ink">
                  <span className="block font-mono text-[10px] text-ink-muted">{e.path ?? ""}</span>
                  <span className="font-medium text-error">{e.code ? `[${e.code}] ` : ""}</span>
                  {e.message}
                </li>
              ))}
            </ul>
            {eventBlocked && (
              <p className="text-xs text-ink">
                Sự kiện lịch sử chưa được xuất bản.{" "}
                <Link
                  href={`/events/${lesson.eventId}`}
                  className="font-medium text-brand hover:underline"
                >
                  Đi tới trang sự kiện để xuất bản →
                </Link>
              </p>
            )}
            <Button
              asChild
              variant="secondary"
              size="sm"
              className="self-start"
            >
              <Link href={`/lessons/${lesson.id}/builder`}>Đi tới chỉnh sửa</Link>
            </Button>
          </div>
        )}
      {publish.isError &&
        (!(publish.error instanceof ApiClientError) ||
          (publish.error.status !== 422 && !publish.error.isConflict)) && (
          <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
            {toUserMessage(publish.error)}
          </p>
        )}

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="Xuất bản bài học này?"
        description={
          republish
            ? "Một phiên bản mới sẽ được tạo từ bản nháp hiện tại và phát hành cho học viên. Phiên bản đã xuất bản trước đó được giữ nguyên và không thể sửa."
            : "Bản nháp hiện tại sẽ được đóng gói thành phiên bản đầu tiên cho học viên. Phiên bản đã xuất bản là bất biến — thay đổi sau đó cần xuất bản phiên bản mới."
        }
        confirmLabel="Xuất bản"
        onConfirm={() => publish.mutate()}
      />
    </div>
  );
}
