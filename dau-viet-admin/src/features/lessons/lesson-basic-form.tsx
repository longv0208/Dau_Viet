"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { skipToken, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useFieldArray, useForm } from "react-hook-form";
import { z } from "zod";
import { ImageIcon, RefreshCw, Trash2, Upload } from "lucide-react";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import { parseReturnTo, withReturnTo } from "@/lib/return-to";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { AdminAsset } from "@/lib/dto/evidence";
import type {
  AdminLessonDetail,
  AdminLessonUpdateRequest,
  LessonTemplate,
} from "@/lib/dto/lesson";
import { applyServerFieldErrors } from "@/lib/form-utils";
import { qk } from "@/lib/query-keys";
import { AssetImage } from "@/features/assets/asset-image";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { StampSeal } from "@/components/atoms/stamp-seal";
import { Button } from "@/components/ui/button";
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

const ALLOWED_COVER_MIMES = new Set(["image/jpeg", "image/png", "image/webp"]);

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

function formatCoverError(err: unknown): string {
  if (err instanceof ApiClientError) {
    if (err.isConflict) {
      return "Bài học đã bị sửa đồng thời (xung đột rowVersion). Vui lòng tải lại dữ liệu rồi thử lưu lại ảnh bìa.";
    }
    const reason = typeof err.details.reason === "string" ? err.details.reason : undefined;
    if (reason) return reason;
    if (err.message && err.message !== "An unexpected error occurred") return err.message;
  }
  return toUserMessage(err);
}

/** A-07 — basic lesson metadata editor. */
export function LessonBasicEditor({ lessonId }: { lessonId: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const returnTo = parseReturnTo(searchParams.get("return"));
  const qc = useQueryClient();
  const [serverError, setServerError] = useState<string | null>(null);
  const [savedTick, setSavedTick] = useState(false);

  const [pickerOpen, setPickerOpen] = useState(false);
  const [selectedCoverId, setSelectedCoverId] = useState<string | null>(null);
  const [pickedAsset, setPickedAsset] = useState<AdminAsset | null>(null);
  const [coverError, setCoverError] = useState<string | null>(null);
  const [coverSavedTick, setCoverSavedTick] = useState(false);

  const lessonQuery = useQuery({
    queryKey: qk.lessons.detail(lessonId),
    queryFn: () => apiFetch<AdminLessonDetail>(`/admin/lessons/${lessonId}`),
  });
  const lesson = lessonQuery.data;

  useEffect(() => {
    if (lesson !== undefined) {
      setSelectedCoverId(lesson.coverAssetId ?? null);
    }
  }, [lesson?.id, lesson?.coverAssetId]);

  const coverAssetQuery = useQuery({
    queryKey: qk.assets.detail(selectedCoverId ?? "none"),
    queryFn:
      selectedCoverId && pickedAsset?.id !== selectedCoverId
        ? () => apiFetch<AdminAsset>(`/admin/assets/${selectedCoverId}`)
        : skipToken,
  });

  const currentCoverAsset: AdminAsset | null =
    selectedCoverId == null
      ? null
      : pickedAsset?.id === selectedCoverId
        ? pickedAsset
        : (coverAssetQuery.data ?? null);

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

  const coverMutation = useMutation({
    mutationFn: async (nextCoverId: string | null) => {
      const latest =
        qc.getQueryData<AdminLessonDetail>(qk.lessons.detail(lessonId)) ?? lesson;
      if (!latest) throw new Error("Chưa tải được dữ liệu bài học.");
      const payload: AdminLessonUpdateRequest =
        nextCoverId === null
          ? {
              clearCoverAsset: true,
              expectedRowVersion: latest.rowVersion,
            }
          : {
              coverAssetId: nextCoverId,
              expectedRowVersion: latest.rowVersion,
            };
      return apiFetch<AdminLessonDetail>(`/admin/lessons/${latest.id}`, {
        method: "PATCH",
        body: JSON.stringify(payload),
      });
    },
    onSuccess: async (updated) => {
      setCoverError(null);
      setSelectedCoverId(updated.coverAssetId ?? null);
      if (!updated.coverAssetId) {
        setPickedAsset(null);
      }
      setCoverSavedTick(true);
      setTimeout(() => setCoverSavedTick(false), 3000);
      qc.setQueryData(qk.lessons.detail(lessonId), updated);
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["lessons"] }),
        qc.invalidateQueries({ queryKey: qk.learningPath.all }),
      ]);
    },
    onError: (err) => {
      setCoverSavedTick(false);
      setCoverError(formatCoverError(err));
    },
  });

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

  const handleSelectCoverAsset = (asset: AdminAsset) => {
    const mime = (asset.mimeType ?? "").toLowerCase();
    if (!ALLOWED_COVER_MIMES.has(mime)) {
      setCoverError(
        `Định dạng "${asset.mimeType}" không hợp lệ cho ảnh bìa. Vui lòng chọn ảnh JPEG, PNG hoặc WebP.`,
      );
      return;
    }
    setCoverError(null);
    setPickedAsset(asset);
    setSelectedCoverId(asset.id);
    coverMutation.mutate(asset.id);
  };

  const handleClearCoverAsset = () => {
    setCoverError(null);
    setSelectedCoverId(null);
    setPickedAsset(null);
    coverMutation.mutate(null);
  };

  const onSubmit = handleSubmit(async (v) => {
    setServerError(null);
    try {
      const latest =
        qc.getQueryData<AdminLessonDetail>(qk.lessons.detail(lessonId)) ?? lesson;
      const payload: AdminLessonUpdateRequest = {
        title: v.title.trim(),
        centralQuestion: v.centralQuestion.trim(),
        objectivesJson: JSON.stringify(v.objectives.map((o) => o.value.trim()).filter(Boolean)),
        expectedRowVersion: latest.rowVersion,
        ...(selectedCoverId !== (latest.coverAssetId ?? null)
          ? selectedCoverId === null
            ? { clearCoverAsset: true }
            : { coverAssetId: selectedCoverId }
          : {}),
      };
      const res = await apiFetch<AdminLessonDetail>(`/admin/lessons/${lesson.id}`, {
        method: "PATCH",
        body: JSON.stringify(payload),
      });
      reset({
        title: res.title,
        centralQuestion: res.centralQuestion,
        objectives: parseObjectives(res.objectivesJson),
      });
      setCoverError(null);
      setSavedTick(true);
      setTimeout(() => setSavedTick(false), 3000);
      qc.setQueryData(qk.lessons.detail(lessonId), res);
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["lessons"] }),
        qc.invalidateQueries({ queryKey: qk.learningPath.all }),
      ]);
    } catch (err) {
      const mapped = applyServerFieldErrors(err, setError, ["title", "centralQuestion"] as const);
      if (err instanceof ApiClientError && err.isConflict) {
        setServerError(
          "Bài học đã bị sửa đồng thời hoặc không thể chỉnh sửa ở trạng thái hiện tại. Tải lại trang.",
        );
      } else if (!mapped) {
        setServerError(formatCoverError(err));
      }
    }
  });

  const hasUnsavedCoverSelection = selectedCoverId !== (lesson.coverAssetId ?? null);

  return (
    <div className="flex flex-col gap-5">
      {returnTo && (
        <Button asChild variant="secondary" className="self-start">
          <Link href={returnTo}>← Quay lại sự kiện</Link>
        </Button>
      )}
      <div className="flex flex-wrap items-center gap-3">
        <StatusChip status={lesson.status} />
        {lesson.currentVersionId && (
          <StampSeal variant="success" label="ẤN HÀNH" className="scale-90" />
        )}
        <span className="text-xs text-ink-muted">
          Cập nhật {new Date(lesson.updatedAt).toLocaleString("vi-VN")}
        </span>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <PaperCard className="p-5">
          <SectionDivider eyebrow="LIÊN KẾT" title="Sự kiện" className="mb-3" />
          <div>
            {eventQuery.isPending && <Skeleton className="h-6 w-48" />}
            {eventQuery.data && (
              <p className="text-sm font-medium text-ink">{eventQuery.data.title}</p>
            )}
          </div>
        </PaperCard>
        <PaperCard className="p-5">
          <SectionDivider eyebrow="CẤU TRÚC" eyebrowColor="jade" title="Khung bài học" className="mb-3" />
          <div>
            <p className="text-sm font-medium text-ink">{template?.name ?? "—"}</p>
            {template && <p className="mt-1 text-xs text-ink-muted">{template.description}</p>}
            {lesson.status !== "DRAFT" && (
              <p className="mt-2 text-xs text-ink-muted">
                Không đổi khung sau khi đã xuất bản.
              </p>
            )}
          </div>
        </PaperCard>
      </div>

      {archived && (
        <p className="rounded-md bg-warning/15 px-3 py-2 text-sm text-ink">
          Bài học đã lưu trữ — chỉ xem, không chỉnh sửa.
        </p>
      )}

      {/* Section: Ảnh bìa bài học */}
      <PaperCard className="p-5">
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div className="flex-1">
            <SectionDivider
              eyebrow="MEDIA"
              eyebrowColor="gold"
              title="Ảnh bìa bài học"
              description="Ảnh bìa/ảnh nền hiển thị trên thẻ bài học, màn giới thiệu bài học trên ứng dụng di động và trong khung thiết kế lộ trình. Ưu tiên tỷ lệ 16:9 (1200×675 px), định dạng JPEG, PNG hoặc WebP."
            />
          </div>
            <div className="flex flex-wrap items-center gap-2">
              {!selectedCoverId ? (
                <Button
                  type="button"
                  size="sm"
                  disabled={archived || coverMutation.isPending}
                  onClick={() => setPickerOpen(true)}
                >
                  <Upload className="size-4" aria-hidden />
                  Chọn ảnh
                </Button>
              ) : (
                <>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={archived || coverMutation.isPending}
                    onClick={() => setPickerOpen(true)}
                  >
                    <RefreshCw className="size-4" aria-hidden />
                    Thay ảnh
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={archived || coverMutation.isPending}
                    onClick={handleClearCoverAsset}
                  >
                    <Trash2 className="size-4" aria-hidden />
                    Gỡ ảnh
                  </Button>
                </>
              )}
            </div>
        </div>
        <div className="space-y-4">
          <div className="grid gap-4 md:grid-cols-[minmax(18rem,26rem)_1fr] md:items-center">
            <div className="overflow-hidden rounded-xl border border-border bg-surface shadow-xs">
              {selectedCoverId && currentCoverAsset ? (
                <AssetImage
                  asset={currentCoverAsset}
                  className="aspect-video w-full object-cover"
                />
              ) : selectedCoverId && coverAssetQuery.isPending ? (
                <div className="flex aspect-video w-full items-center justify-center bg-surface text-xs text-ink-muted">
                  Đang tải ảnh bìa…
                </div>
              ) : (
                <div className="flex aspect-video w-full flex-col items-center justify-center gap-2 bg-surface/70 px-4 text-center text-ink-muted">
                  <div className="flex size-11 items-center justify-center rounded-full border border-dashed border-border bg-white">
                    <ImageIcon className="size-5 text-ink-muted" aria-hidden />
                  </div>
                  <p className="text-sm font-medium text-ink">Chưa có ảnh bìa bài học</p>
                  <p className="text-xs text-ink-muted">
                    Bấm &ldquo;Chọn ảnh&rdquo; để chọn từ thư viện hoặc tải ảnh mới lên (tùy chọn, không chặn xuất bản).
                  </p>
                </div>
              )}
            </div>

            <div className="space-y-2 text-xs text-ink-muted">
              {currentCoverAsset ? (
                <div className="space-y-1 rounded-lg border border-border bg-surface/60 p-3">
                  <p className="truncate text-sm font-medium text-ink">
                    {currentCoverAsset.originalFilename ?? "Ảnh bìa bài học"}
                  </p>
                  <p>
                    Định dạng: <span className="font-mono text-ink">{currentCoverAsset.mimeType}</span> · Dung lượng:{" "}
                    <span className="font-mono text-ink">
                      {Math.max(1, Math.round(currentCoverAsset.sizeBytes / 1024))} KB
                    </span>
                  </p>
                  {currentCoverAsset.altText && (
                    <p className="text-ink-muted">Mô tả (alt): {currentCoverAsset.altText}</p>
                  )}
                  <p className="font-mono text-[11px] text-ink-muted">
                    Asset ID: {currentCoverAsset.id}
                  </p>
                </div>
              ) : (
                <div className="space-y-1 rounded-lg border border-dashed border-border p-3">
                  <p className="font-medium text-ink">Hướng dẫn ảnh bìa</p>
                  <p>• Tỷ lệ hiển thị chuẩn: 16:9 (khuyến nghị 1200×675 px).</p>
                  <p>• Định dạng hỗ trợ: JPEG, PNG, WebP (tối đa 10 MB).</p>
                  <p>• Gỡ ảnh chỉ xóa liên kết khỏi bài học, không xóa tệp khỏi thư viện Asset.</p>
                </div>
              )}

              {coverMutation.isPending && (
                <p role="status" className="text-xs font-medium text-brand">
                  Đang lưu ảnh bìa bài học…
                </p>
              )}
              {coverSavedTick && (
                <p role="status" className="rounded-md bg-success/10 px-3 py-2 text-xs font-medium text-success">
                  Đã cập nhật ảnh bìa bài học.
                </p>
              )}
              {coverError && (
                <div
                  role="alert"
                  className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-error/30 bg-error/10 px-3 py-2 text-xs text-error"
                >
                  <span>{coverError}</span>
                  {hasUnsavedCoverSelection && !archived && (
                    <Button
                      type="button"
                      size="sm"
                      variant="secondary"
                      disabled={coverMutation.isPending}
                      onClick={() => coverMutation.mutate(selectedCoverId)}
                    >
                      Thử lưu lại
                    </Button>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      </PaperCard>

      <PaperCard className="p-5">
        <SectionDivider
          eyebrow="THÔNG TIN"
          title="Thông tin cơ bản"
          description="Tiêu đề, câu hỏi trung tâm và mục tiêu học tập."
          className="mb-4"
        />
        <div>
          <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="title" className="font-medium text-ink-secondary">Tiêu đề *</Label>
              <Input id="title" disabled={archived} {...register("title")} />
              {errors.title && <p role="alert" className="text-xs text-error">{errors.title.message}</p>}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="centralQuestion" className="font-medium text-ink-secondary">Câu hỏi trung tâm *</Label>
              <Textarea id="centralQuestion" rows={3} disabled={archived} {...register("centralQuestion")} />
              {errors.centralQuestion && (
                <p role="alert" className="text-xs text-error">{errors.centralQuestion.message}</p>
              )}
            </div>
            <div className="flex flex-col gap-2">
              <Label className="font-medium text-ink-secondary">Mục tiêu học tập *</Label>
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
                <Button type="submit" disabled={isSubmitting || coverMutation.isPending}>
                  {isSubmitting ? "Đang lưu..." : "Lưu thay đổi"}
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => {
                    if (confirmDiscard(isDirty)) router.push(returnTo ?? "/lessons");
                  }}
                >
                  Huỷ
                </Button>
              </div>
            )}
          </form>
        </div>
      </PaperCard>

      <PaperCard className="p-5">
        <SectionDivider
          eyebrow="TRÌNH SOẠN"
          eyebrowColor="brand"
          title="Giai đoạn & hoạt động"
          description="Xây dựng cấu trúc giai đoạn và các hoạt động học tập của bài học."
          className="mb-4"
        />
        <div className="flex flex-col gap-2">
          <p className="text-sm text-ink-muted">
            Xây dựng cấu trúc giai đoạn và hoạt động học tập bằng trình soạn trực quan.
          </p>
          <div className="flex flex-wrap gap-2">
            <Button asChild variant="secondary">
              <Link href={withReturnTo(`/lessons/${lesson.id}/builder`, returnTo)}>
                Mở trình soạn bài học
              </Link>
            </Button>
            <Button asChild variant="secondary">
              <Link href={withReturnTo(`/lessons/${lesson.id}/preview`, returnTo)}>
                Xem trước
              </Link>
            </Button>
            {!archived && (
              <Button asChild>
                <Link href={withReturnTo(`/lessons/${lesson.id}/publish`, returnTo)}>
                  Xuất bản
                </Link>
              </Button>
            )}
          </div>
        </div>
      </PaperCard>

      <AssetPickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        onSelect={handleSelectCoverAsset}
      />
    </div>
  );
}
