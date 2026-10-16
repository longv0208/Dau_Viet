"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { skipToken, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useFieldArray, useForm } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { AdminLessonDetail, LessonTemplate } from "@/lib/dto/lesson";
import { applyServerFieldErrors } from "@/lib/form-utils";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { StatusChip } from "@/components/status-chip";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";
import {
  confirmDiscard,
  useUnsavedChangesGuard,
} from "@/components/unsaved-changes-guard";

const schema = z.object({
  title: z.string().min(1, "Vui lòng nhập tiêu đề").max(255),
  centralQuestion: z.string().min(1, "Vui lòng nhập câu hỏi trung tâm"),
  objectives: z
    .array(z.object({ value: z.string().min(1, "Không để trống mục tiêu") }))
    .min(1, "Cần ít nhất 1 mục tiêu"),
});

type Values = z.infer<typeof schema>;

function parseObjectives(json: string): { value: string }[] {
  try {
    const arr = JSON.parse(json);
    if (Array.isArray(arr)) {
      const out = arr.filter((x) => typeof x === "string").map((x) => ({ value: x }));
      return out.length ? out : [{ value: "" }];
    }
  } catch {
    /* fall through */
  }
  return [{ value: "" }];
}

/** A-07 — basic lesson metadata editor. */
export function LessonBasicEditor({ lessonId }: { lessonId: string }) {
  const router = useRouter();
  const qc = useQueryClient();
  const [serverError, setServerError] = useState<string | null>(null);
  const [savedTick, setSavedTick] = useState(false);

  const lessonQuery = useQuery({
    queryKey: qk.lessons.detail(lessonId),
    queryFn: () => apiFetch<AdminLessonDetail>(`/admin/lessons/${lessonId}`),
  });
  const lesson = lessonQuery.data;

  const eventQuery = useQuery({
    queryKey: qk.events.detail(lesson?.eventId ?? "none"),
    queryFn: lesson?.eventId
      ? () => apiFetch<AdminEventSummary>(`/admin/events/${lesson.eventId}`)
      : skipToken,
  });
  const templatesQuery = useQuery({
    queryKey: qk.templates.list(),
    queryFn: () => apiFetch<LessonTemplate[]>("/admin/lesson-templates"),
  });
  const template = templatesQuery.data?.find((t) => t.id === lesson?.templateId);

  const {
    register,
    control,
    handleSubmit,
    reset,
    setError,
    formState: { errors, isDirty, isSubmitting },
  } = useForm<Values>({
    resolver: zodResolver(schema),
    values: lesson
      ? {
          title: lesson.title,
          centralQuestion: lesson.centralQuestion,
          objectives: parseObjectives(lesson.objectivesJson),
        }
      : undefined,
  });
  const objectives = useFieldArray({ control, name: "objectives" });

  useUnsavedChangesGuard(isDirty);

  if (lessonQuery.isPending) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }
  if (lessonQuery.isError) {
    return <ErrorState error={lessonQuery.error} onRetry={() => lessonQuery.refetch()} />;
  }
  if (!lesson) return null;

  const archived = lesson.status === "ARCHIVED";

  const onSubmit = handleSubmit(async (v) => {
    setServerError(null);
    try {
      const res = await apiFetch<AdminLessonDetail>(`/admin/lessons/${lesson.id}`, {
        method: "PATCH",
        body: JSON.stringify({
          title: v.title.trim(),
          centralQuestion: v.centralQuestion.trim(),
          objectivesJson: JSON.stringify(v.objectives.map((o) => o.value.trim()).filter(Boolean)),
          expectedRowVersion: lesson.rowVersion,
        }),
      });
      reset({
        title: res.title,
        centralQuestion: res.centralQuestion,
        objectives: parseObjectives(res.objectivesJson),
      });
      setSavedTick(true);
      setTimeout(() => setSavedTick(false), 3000);
      qc.invalidateQueries({ queryKey: ["lessons"] });
    } catch (err) {
      const mapped = applyServerFieldErrors(err, setError, ["title", "centralQuestion"] as const);
      if (err instanceof ApiClientError && err.isConflict) {
        setServerError(
          "Bài học đã bị sửa đồng thời hoặc không thể chỉnh sửa ở trạng thái hiện tại. Tải lại trang.",
        );
      } else if (!mapped) {
        setServerError(toUserMessage(err));
      }
    }
  });

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center gap-3">
        <StatusChip status={lesson.status} />
        <span className="text-xs text-ink-muted">
          Cập nhật {new Date(lesson.updatedAt).toLocaleString("vi-VN")}
        </span>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Sự kiện</CardTitle>
          </CardHeader>
          <CardContent>
            {eventQuery.isPending && <Skeleton className="h-6 w-48" />}
            {eventQuery.data && (
              <p className="text-sm font-medium text-ink">{eventQuery.data.title}</p>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Khung bài học</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm font-medium text-ink">{template?.name ?? lesson.templateId}</p>
            {template && <p className="mt-1 text-xs text-ink-muted">{template.description}</p>}
            {lesson.status !== "DRAFT" && (
              <p className="mt-2 text-xs text-ink-muted">
                Không đổi khung sau khi đã xuất bản.
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      {archived && (
        <p className="rounded-md bg-warning/15 px-3 py-2 text-sm text-ink">
          Bài học đã lưu trữ — chỉ xem, không chỉnh sửa.
        </p>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Thông tin cơ bản</CardTitle>
          <CardDescription>Tiêu đề, câu hỏi trung tâm và mục tiêu học tập.</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="title">Tiêu đề *</Label>
              <Input id="title" disabled={archived} {...register("title")} />
              {errors.title && <p role="alert" className="text-xs text-error">{errors.title.message}</p>}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="centralQuestion">Câu hỏi trung tâm *</Label>
              <Textarea id="centralQuestion" rows={3} disabled={archived} {...register("centralQuestion")} />
              {errors.centralQuestion && (
                <p role="alert" className="text-xs text-error">{errors.centralQuestion.message}</p>
              )}
            </div>
            <div className="flex flex-col gap-2">
              <Label>Mục tiêu học tập *</Label>
              {objectives.fields.map((f, i) => (
                <div key={f.id} className="flex flex-col gap-1">
                  <div className="flex items-center gap-2">
                    <Input disabled={archived} {...register(`objectives.${i}.value` as const)} />
                    <Button
                      type="button"
                      variant="secondary"
                      onClick={() => objectives.remove(i)}
                      disabled={archived || objectives.fields.length === 1}
                    >
                      Xoá
                    </Button>
                  </div>
                  {errors.objectives?.[i]?.value && (
                    <p role="alert" className="text-xs text-error">
                      {errors.objectives[i]?.value?.message}
                    </p>
                  )}
                </div>
              ))}
              <Button
                type="button"
                variant="secondary"
                className="self-start"
                onClick={() => objectives.append({ value: "" })}
                disabled={archived}
              >
                + Thêm mục tiêu
              </Button>
            </div>

            {serverError && (
              <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
                {serverError}
              </p>
            )}
            {savedTick && (
              <p role="status" className="rounded-md bg-success/10 px-3 py-2 text-sm text-success">
                Đã lưu thay đổi.
              </p>
            )}

            {!archived && (
              <div className="flex items-center gap-3">
                <Button type="submit" disabled={isSubmitting}>
                  {isSubmitting ? "Đang lưu..." : "Lưu thay đổi"}
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => {
                    if (confirmDiscard(isDirty)) router.push("/lessons");
                  }}
                >
                  Huỷ
                </Button>
              </div>
            )}
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Giai đoạn & hoạt động</CardTitle>
          <CardDescription>
            Xây dựng cấu trúc giai đoạn và các hoạt động học tập của bài học.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <p className="rounded-md bg-surface-alt px-3 py-2 text-sm text-ink-muted">
            Sắp triển khai — Stage Builder sẽ có ở TASK tiếp theo.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
