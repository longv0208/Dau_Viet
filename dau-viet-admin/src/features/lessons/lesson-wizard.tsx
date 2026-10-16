"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { useFieldArray, useForm } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { AdminLessonDetail, LessonTemplate } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";
import { EmptyState } from "@/components/empty-state";
import { useUnsavedChangesGuard } from "@/components/unsaved-changes-guard";

const basicSchema = z.object({
  title: z.string().min(1, "Vui lòng nhập tiêu đề bài học").max(255),
  centralQuestion: z.string().min(1, "Vui lòng nhập câu hỏi trung tâm"),
  objectives: z
    .array(z.object({ value: z.string().min(1, "Không để trống mục tiêu") }))
    .min(1, "Cần ít nhất 1 mục tiêu học tập"),
});

type BasicValues = z.infer<typeof basicSchema>;

const STEPS = [
  { n: 1, label: "Chọn sự kiện" },
  { n: 2, label: "Chọn khung bài học" },
  { n: 3, label: "Thông tin cơ bản" },
  { n: 4, label: "Xác nhận & lưu" },
];

/** A-06 — guided 4-step lesson creation wizard. */
export function LessonWizard() {
  const router = useRouter();
  const qc = useQueryClient();
  const searchParams = useSearchParams();
  const presetEvent = searchParams.get("event") ?? undefined;

  const [step, setStep] = useState(1);
  const [eventId, setEventId] = useState<string | undefined>(presetEvent);
  const [templateId, setTemplateId] = useState<string | undefined>();
  const [serverError, setServerError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const eventsQuery = useQuery({
    queryKey: qk.events.list({ size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminEventSummary>>("/admin/events?size=100&sort=updatedAt,desc"),
  });
  const templatesQuery = useQuery({
    queryKey: qk.templates.list(),
    queryFn: () => apiFetch<LessonTemplate[]>("/admin/lesson-templates"),
  });

  const event = eventsQuery.data?.content.find((e) => e.id === eventId);
  const template = templatesQuery.data?.find((t) => t.id === templateId);

  const {
    register,
    control,
    handleSubmit,
    formState: { errors, isDirty },
    getValues,
  } = useForm<BasicValues>({
    resolver: zodResolver(basicSchema),
    defaultValues: { title: "", centralQuestion: "", objectives: [{ value: "" }] },
  });
  const objectives = useFieldArray({ control, name: "objectives" });

  // Warn before leaving once the admin has picked anything or typed anything.
  useUnsavedChangesGuard(isDirty || step > 1);

  async function saveDraft(v: BasicValues) {
    if (!eventId || !templateId) return;
    setSubmitting(true);
    setServerError(null);
    try {
      const res = await apiFetch<AdminLessonDetail>("/admin/lessons", {
        method: "POST",
        body: JSON.stringify({
          eventId,
          templateId,
          title: v.title.trim(),
          centralQuestion: v.centralQuestion.trim(),
          objectivesJson: JSON.stringify(v.objectives.map((o) => o.value.trim()).filter(Boolean)),
          draftJson: "{}",
        }),
      });
      qc.invalidateQueries({ queryKey: ["lessons"] });
      router.push(`/lessons/${res.id}`);
    } catch (err) {
      setServerError(toUserMessage(err));
      setSubmitting(false);
    }
  }

  const next = () => setStep((s) => Math.min(4, s + 1));
  const back = () => setStep((s) => Math.max(1, s - 1));

  return (
    <div className="flex flex-col gap-6">
      <ol className="flex flex-wrap items-center gap-2 text-sm">
        {STEPS.map((s) => (
          <li key={s.n} className="flex items-center gap-2">
            <span
              className={
                s.n === step
                  ? "flex size-7 items-center justify-center rounded-full bg-brand text-xs font-semibold text-white"
                  : s.n < step
                    ? "flex size-7 items-center justify-center rounded-full bg-success/20 text-xs font-semibold text-ink"
                    : "flex size-7 items-center justify-center rounded-full bg-surface-alt text-xs text-ink-muted"
              }
            >
              {s.n}
            </span>
            <span className={s.n === step ? "font-medium text-ink" : "text-ink-muted"}>
              {s.label}
            </span>
            {s.n < STEPS.length && <span className="text-ink-muted">→</span>}
          </li>
        ))}
      </ol>

      {step === 1 && (
        <Card>
          <CardHeader>
            <CardTitle>Bước 1 — Chọn sự kiện lịch sử</CardTitle>
            <CardDescription>
              Bài học sẽ gắn với một sự kiện. Chưa có sự kiện phù hợp?{" "}
              <Link href="/events/new" className="text-primary underline">
                Tạo sự kiện mới
              </Link>
              .
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            {eventsQuery.isPending && <Skeleton className="h-40 w-full" />}
            {eventsQuery.isError && (
              <ErrorState error={eventsQuery.error} onRetry={() => eventsQuery.refetch()} />
            )}
            {eventsQuery.data && eventsQuery.data.content.length === 0 && (
              <EmptyState
                title="Chưa có sự kiện nào"
                description="Bạn cần tạo ít nhất một sự kiện lịch sử trước khi tạo bài học."
                action={
                  <Button asChild>
                    <Link href="/events/new">Tạo sự kiện đầu tiên</Link>
                  </Button>
                }
              />
            )}
            <div className="grid gap-2">
              {(eventsQuery.data?.content ?? []).map((ev) => (
                <button
                  key={ev.id}
                  type="button"
                  onClick={() => setEventId(ev.id)}
                  className={
                    "rounded-md border p-3 text-left transition-colors " +
                    (eventId === ev.id
                      ? "border-brand bg-brand/5"
                      : "border-border bg-white hover:bg-surface")
                  }
                >
                  <p className="font-medium text-ink">{ev.title}</p>
                  <p className="text-xs text-ink-muted">
                    {[ev.era, ev.startYear].filter(Boolean).join(" · ") || "—"}
                  </p>
                </button>
              ))}
            </div>
            <div className="flex justify-end gap-2">
              <Button disabled={!eventId} onClick={next}>
                Tiếp tục
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {step === 2 && (
        <Card>
          <CardHeader>
            <CardTitle>Bước 2 — Chọn khung bài học</CardTitle>
            <CardDescription>
              Khung quyết định cấu trúc giai đoạn và hoạt động của bài học. Sự kiện đã chọn:{" "}
              <strong>{event?.title}</strong>.
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            {templatesQuery.isPending && <Skeleton className="h-40 w-full" />}
            {templatesQuery.isError && (
              <ErrorState error={templatesQuery.error} onRetry={() => templatesQuery.refetch()} />
            )}
            {templatesQuery.data && templatesQuery.data.length === 0 && (
              <EmptyState
                title="Chưa có khung bài học khả dụng"
                description="Hệ thống chưa có khung bài học nào được bật. Vui lòng liên hệ quản trị hệ thống để được hỗ trợ."
              />
            )}
            <div className="grid gap-2">
              {(templatesQuery.data ?? []).map((t) => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => setTemplateId(t.id)}
                  className={
                    "rounded-md border p-3 text-left transition-colors " +
                    (templateId === t.id
                      ? "border-brand bg-brand/5"
                      : "border-border bg-white hover:bg-surface")
                  }
                >
                  <p className="font-medium text-ink">{t.name}</p>
                  <p className="text-xs text-ink-muted">{t.description}</p>
                </button>
              ))}
            </div>
            <div className="flex justify-between">
              <Button variant="secondary" onClick={back}>
                Quay lại
              </Button>
              <Button disabled={!templateId} onClick={next}>
                Tiếp tục
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {step === 3 && (
        <Card>
          <CardHeader>
            <CardTitle>Bước 3 — Thông tin cơ bản</CardTitle>
            <CardDescription>
              Những thông tin này xuất hiện với học viên và trong danh sách quản trị.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form className="flex flex-col gap-4" onSubmit={handleSubmit(() => next())} noValidate>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="title">Tiêu đề bài học *</Label>
                <Input
                  id="title"
                  placeholder="Bí mật chiến thắng Bạch Đằng"
                  aria-invalid={Boolean(errors.title)}
                  {...register("title")}
                />
                {errors.title && <p role="alert" className="text-xs text-error">{errors.title.message}</p>}
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="centralQuestion">Câu hỏi trung tâm *</Label>
                <Textarea
                  id="centralQuestion"
                  rows={3}
                  placeholder="Vì sao Ngô Quyền đánh bại quân Nam Hán trên sông Bạch Đằng năm 938?"
                  aria-invalid={Boolean(errors.centralQuestion)}
                  {...register("centralQuestion")}
                />
                <p className="text-xs text-ink-muted">
                  Câu hỏi lớn mà bài học giúp học viên trả lời.
                </p>
                {errors.centralQuestion && (
                  <p role="alert" className="text-xs text-error">{errors.centralQuestion.message}</p>
                )}
              </div>
              <div className="flex flex-col gap-2">
                <Label>Mục tiêu học tập *</Label>
                {objectives.fields.map((f, i) => (
                  <div key={f.id} className="flex flex-col gap-1">
                    <div className="flex items-center gap-2">
                      <Input
                        placeholder={`Mục tiêu ${i + 1}`}
                        aria-label={`Mục tiêu ${i + 1}`}
                        aria-invalid={Boolean(errors.objectives?.[i]?.value)}
                        {...register(`objectives.${i}.value` as const)}
                      />
                      <Button
                        type="button"
                        variant="secondary"
                        onClick={() => objectives.remove(i)}
                        disabled={objectives.fields.length === 1}
                        aria-label={`Xoá mục tiêu ${i + 1}`}
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
                >
                  + Thêm mục tiêu
                </Button>
                {typeof errors.objectives?.message === "string" && (
                  <p role="alert" className="text-xs text-error">{errors.objectives.message}</p>
                )}
              </div>
              <div className="flex justify-between">
                <Button type="button" variant="secondary" onClick={back}>
                  Quay lại
                </Button>
                <Button type="submit">Tiếp tục</Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {step === 4 && (
        <Card>
          <CardHeader>
            <CardTitle>Bước 4 — Xác nhận & lưu bản nháp</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            <dl className="grid gap-3 rounded-md border border-border bg-surface p-4 text-sm">
              <div>
                <dt className="text-ink-muted">Sự kiện</dt>
                <dd className="font-medium text-ink">{event?.title}</dd>
              </div>
              <div>
                <dt className="text-ink-muted">Khung bài học</dt>
                <dd className="font-medium text-ink">{template?.name}</dd>
              </div>
              <div>
                <dt className="text-ink-muted">Tiêu đề</dt>
                <dd className="font-medium text-ink">{getValues("title")}</dd>
              </div>
              <div>
                <dt className="text-ink-muted">Câu hỏi trung tâm</dt>
                <dd className="font-medium text-ink">{getValues("centralQuestion")}</dd>
              </div>
              <div>
                <dt className="text-ink-muted">Mục tiêu</dt>
                <dd className="font-medium text-ink">
                  <ul className="list-disc pl-5">
                    {getValues("objectives")
                      .map((o) => o.value)
                      .filter(Boolean)
                      .map((o, i) => (
                        <li key={i}>{o}</li>
                      ))}
                  </ul>
                </dd>
              </div>
            </dl>
            {serverError && (
              <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
                {serverError}
              </p>
            )}
            <div className="flex justify-between">
              <Button variant="secondary" onClick={back} disabled={submitting}>
                Quay lại
              </Button>
              <Button onClick={handleSubmit(saveDraft)} disabled={submitting}>
                {submitting ? "Đang lưu..." : "Lưu bản nháp"}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
