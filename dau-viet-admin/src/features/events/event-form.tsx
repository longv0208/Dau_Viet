"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { AdminEventDetail } from "@/lib/dto/event";
import { applyServerFieldErrors, toSlug } from "@/lib/form-utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  confirmDiscard,
  useUnsavedChangesGuard,
} from "@/components/unsaved-changes-guard";

const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const eventSchema = z.object({
  title: z.string().min(1, "Vui lòng nhập tiêu đề").max(255, "Tối đa 255 ký tự"),
  slug: z
    .string()
    .min(1, "Vui lòng nhập đường dẫn rút gọn")
    .max(150, "Tối đa 150 ký tự")
    .regex(SLUG_RE, "Chỉ gồm chữ thường không dấu, số và gạch ngang"),
  era: z.string().max(100, "Tối đa 100 ký tự").optional().or(z.literal("")),
  period: z.string().max(100, "Tối đa 100 ký tự").optional().or(z.literal("")),
  startYear: z
    .string()
    .optional()
    .refine(
      (v) => v === undefined || v === "" || /^-?\d+$/.test(v),
      "Năm phải là số nguyên",
    ),
  location: z.string().optional().or(z.literal("")),
  summary: z.string().min(1, "Vui lòng nhập tóm tắt"),
  description: z.string().optional().or(z.literal("")),
  coverAssetKey: z.string().max(512).optional().or(z.literal("")),
  tags: z.array(z.object({ value: z.string() })),
});

export type EventFormValues = z.infer<typeof eventSchema>;

interface Props {
  /** When provided the form is in edit mode (PATCH). */
  initial?: AdminEventDetail;
}

/** A-04 — create/edit Historical Event. Shared between /events/new and /events/[id]. */
export function EventForm({ initial }: Props) {
  const router = useRouter();
  const qc = useQueryClient();
  const isEdit = Boolean(initial);
  const [serverError, setServerError] = useState<string | null>(null);
  const [savedTick, setSavedTick] = useState(false);
  const [slugTouched, setSlugTouched] = useState(isEdit);

  const {
    register,
    handleSubmit,
    control,
    watch,
    setValue,
    setError,
    reset,
    formState: { errors, isDirty, isSubmitting },
  } = useForm<EventFormValues>({
    resolver: zodResolver(eventSchema),
    defaultValues: initial
      ? {
          title: initial.title,
          slug: initial.slug,
          era: initial.era ?? "",
          period: initial.period ?? "",
          startYear: initial.startYear?.toString() ?? "",
          location: initial.location ?? "",
          summary: initial.summary,
          description: initial.description ?? "",
          coverAssetKey: initial.coverAssetKey ?? "",
          tags: (initial.tags ?? []).map((t) => ({ value: t })),
        }
      : {
          title: "",
          slug: "",
          era: "",
          period: "",
          startYear: "",
          location: "",
          summary: "",
          description: "",
          coverAssetKey: "",
          tags: [],
        },
  });

  const tags = useFieldArray({ control, name: "tags" });
  const titleValue = watch("title");

  // Auto-suggest slug from title until the admin touches the slug field.
  useEffect(() => {
    if (!slugTouched) setValue("slug", toSlug(titleValue), { shouldDirty: false });
  }, [titleValue, slugTouched, setValue]);

  useUnsavedChangesGuard(isDirty);

  const onSubmit = handleSubmit(async (v) => {
    setServerError(null);
    const payload = {
      title: v.title.trim(),
      slug: v.slug.trim(),
      era: v.era?.trim() || undefined,
      period: v.period?.trim() || undefined,
      startYear:
        v.startYear && v.startYear.trim() !== "" ? Number(v.startYear) : undefined,
      location: v.location?.trim() || undefined,
      summary: v.summary,
      description: v.description?.trim() || undefined,
      coverAssetKey: v.coverAssetKey?.trim() || undefined,
      tags: v.tags.map((t) => t.value.trim()).filter(Boolean),
    };
    try {
      if (isEdit && initial) {
        const res = await apiFetch<AdminEventDetail>(`/admin/events/${initial.id}`, {
          method: "PATCH",
          body: JSON.stringify({ ...payload, expectedRowVersion: initial.rowVersion }),
        });
        reset({
          title: res.title,
          slug: res.slug,
          era: res.era ?? "",
          period: res.period ?? "",
          startYear: res.startYear?.toString() ?? "",
          location: res.location ?? "",
          summary: res.summary,
          description: res.description ?? "",
          coverAssetKey: res.coverAssetKey ?? "",
          tags: (res.tags ?? []).map((t: string) => ({ value: t })),
        });
        setSavedTick(true);
        setTimeout(() => setSavedTick(false), 3000);
        qc.invalidateQueries({ queryKey: ["events"] });
      } else {
        const res = await apiFetch<AdminEventDetail>("/admin/events", {
          method: "POST",
          body: JSON.stringify(payload),
        });
        qc.invalidateQueries({ queryKey: ["events"] });
        router.push(`/events/${res.id}`);
      }
    } catch (err) {
      const mapped = applyServerFieldErrors(err, setError, [
        "title",
        "slug",
        "era",
        "period",
        "startYear",
        "location",
        "summary",
        "description",
        "coverAssetKey",
      ] as const);
      if (!mapped) setServerError(toUserMessage(err));
      if (err instanceof ApiClientError && err.isConflict) {
        setServerError(
          "Sự kiện đã bị ai đó sửa đồng thời. Tải lại trang để lấy dữ liệu mới.",
        );
      }
    }
  });

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
      <div className="grid gap-4 md:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="title">Tiêu đề *</Label>
          <Input
            id="title"
            placeholder="Trận Bạch Đằng năm 938"
            aria-invalid={Boolean(errors.title)}
            {...register("title")}
          />
          {errors.title && <p role="alert" className="text-xs text-error">{errors.title.message}</p>}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="slug">Đường dẫn rút gọn *</Label>
          <Input
            id="slug"
            placeholder="tran-bach-dang-938"
            aria-invalid={Boolean(errors.slug)}
            {...register("slug", {
              onChange: () => setSlugTouched(true),
            })}
          />
          <p className="text-xs text-ink-muted">Dùng trong đường dẫn trang — chỉ chữ thường không dấu, số và gạch ngang.</p>
          {errors.slug && <p role="alert" className="text-xs text-error">{errors.slug.message}</p>}
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="era">Thời kỳ</Label>
          <Input id="era" placeholder="Thời Ngô — Đinh — Tiền Lê" {...register("era")} />
          {errors.era && <p role="alert" className="text-xs text-error">{errors.era.message}</p>}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="period">Giai đoạn</Label>
          <Input id="period" placeholder="Mùa Đông 938" {...register("period")} />
          {errors.period && <p role="alert" className="text-xs text-error">{errors.period.message}</p>}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="startYear">Năm bắt đầu</Label>
          <Input id="startYear" inputMode="numeric" placeholder="938" {...register("startYear")} />
          {errors.startYear && <p role="alert" className="text-xs text-error">{errors.startYear.message}</p>}
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="location">Địa điểm</Label>
        <Input id="location" placeholder="Sông Bạch Đằng, Quảng Ninh" {...register("location")} />
        {errors.location && <p role="alert" className="text-xs text-error">{errors.location.message}</p>}
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="summary">Tóm tắt *</Label>
        <Textarea
          id="summary"
          rows={3}
          placeholder="Một đoạn ngắn giới thiệu sự kiện cho học viên."
          aria-invalid={Boolean(errors.summary)}
          {...register("summary")}
        />
        {errors.summary && <p role="alert" className="text-xs text-error">{errors.summary.message}</p>}
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="description">Mô tả chi tiết</Label>
        <Textarea
          id="description"
          rows={6}
          placeholder="Bối cảnh lịch sử, diễn biến chính, ý nghĩa."
          {...register("description")}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="coverAssetKey">Ảnh bìa</Label>
        <Input
          id="coverAssetKey"
          placeholder="events/bach-dang-938/hero.jpg"
          {...register("coverAssetKey")}
        />
        <p className="text-xs text-ink-muted">
          Chức năng tải ảnh sẽ có sau — hiện để trống hoặc liên hệ quản trị để gắn ảnh.
        </p>
        {errors.coverAssetKey && <p role="alert" className="text-xs text-error">{errors.coverAssetKey.message}</p>}
      </div>

      <div className="flex flex-col gap-2">
        <Label>Tags</Label>
        {tags.fields.map((f, i) => (
          <div key={f.id} className="flex items-center gap-2">
            <Input placeholder="ngô-quyền" {...register(`tags.${i}.value` as const)} />
            <Button
              type="button"
              variant="secondary"
              onClick={() => tags.remove(i)}
              aria-label={`Xoá tag ${i + 1}`}
            >
              Xoá
            </Button>
          </div>
        ))}
        <Button
          type="button"
          variant="secondary"
          className="self-start"
          onClick={() => tags.append({ value: "" })}
        >
          + Thêm tag
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

      <div className="flex items-center gap-3">
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? "Đang lưu..." : isEdit ? "Lưu thay đổi" : "Tạo sự kiện"}
        </Button>
        <Button
          type="button"
          variant="secondary"
          onClick={() => {
            if (confirmDiscard(isDirty)) router.push("/events");
          }}
        >
          Huỷ
        </Button>
      </div>
    </form>
  );
}
