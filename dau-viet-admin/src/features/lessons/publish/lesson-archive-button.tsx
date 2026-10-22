"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { AdminLessonDetail } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";

/**
 * Archive (ẩn) a lesson — POST /admin/lessons/{id}/archive.
 * Ẩn khỏi học viên ngay lập tức: lesson không còn PUBLISHED thì learner
 * list/metadata/content đều 404. Phiên bản snapshot đã xuất bản vẫn nguyên
 * vẹn trong lesson_versions (phục vụ attempt đang chạy) — archive không
 * xóa dữ liệu. Phía admin, lesson ARCHIVED khóa sửa/publish.
 */
export function LessonArchiveButton({ lesson }: { lesson: AdminLessonDetail }) {
  const qc = useQueryClient();
  const [confirmOpen, setConfirmOpen] = useState(false);

  const archive = useMutation({
    mutationFn: () =>
      apiFetch<AdminLessonDetail>(`/admin/lessons/${lesson.id}/archive`, { method: "POST" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.lessons.detail(lesson.id) });
      qc.invalidateQueries({ queryKey: ["lessons"] });
    },
  });

  if (lesson.status === "ARCHIVED") return null;

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center gap-3">
        <Button
          variant="secondary"
          className="text-error hover:bg-error/10"
          onClick={() => setConfirmOpen(true)}
          disabled={archive.isPending}
        >
          {archive.isPending ? "Đang lưu trữ..." : "Lưu trữ bài học"}
        </Button>
        {lesson.status === "PUBLISHED" && (
          <p className="text-xs text-ink-muted">
            Học viên sẽ không còn thấy bài học sau khi lưu trữ.
          </p>
        )}
      </div>
      {archive.isError && (
        <p role="alert" className="text-xs text-error">
          {toUserMessage(archive.error)}
        </p>
      )}
      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="Lưu trữ bài học này?"
        description="Bài học sẽ bị ẩn khỏi học viên ngay lập tức và không thể chỉnh sửa hay xuất bản lại. Phiên bản đã xuất bản được giữ nguyên cho các lượt học đang chạy."
        confirmLabel="Lưu trữ"
        destructive
        onConfirm={() => archive.mutate()}
      />
    </div>
  );
}
