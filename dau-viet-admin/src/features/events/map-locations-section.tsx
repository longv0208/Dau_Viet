"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import dynamic from "next/dynamic";
import Link from "next/link";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";

import { apiFetch, toQuery } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import type {
  AdminMapLocation,
  AdminMapLocationRequest,
  MapLocationStatus,
} from "@/lib/dto/map-location";
import { qk } from "@/lib/query-keys";
import { EmptyStateCard } from "@/components/atoms/empty-state-card";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";
import { ErrorState } from "@/components/error-state";

const NUM_RE = /^-?\d+(\.\d+)?$/;

// Picker thuần DOM — không cần window ở module scope, nhưng giữ dynamic để
// nhất quán & tránh SSR render ảnh nặng.
const LatLngMapPicker = dynamic(
  () =>
    import("./lat-lng-map-picker").then((m) => ({
      default: m.LatLngMapPicker,
    })),
  { ssr: false, loading: () => <Skeleton className="h-80 w-full" /> },
);

/**
 * Vị trí địa điểm lưu theo WGS84 trên World Map Việt Nam.
 */
const schema = z.object({
  title: z.string().min(1, "Vui lòng nhập tên địa điểm").max(255, "Tối đa 255 ký tự"),
  description: z.string().max(4000, "Tối đa 4000 ký tự").optional().or(z.literal("")),
  latitude: z
    .string()
    .min(1, "Vui lòng chọn vị trí trên bản đồ")
    .regex(NUM_RE, "Vĩ độ phải là số")
    .refine((v) => Number(v) >= -90 && Number(v) <= 90, "Vĩ độ từ -90 đến 90"),
  longitude: z
    .string()
    .min(1, "Vui lòng chọn vị trí trên bản đồ")
    .regex(NUM_RE, "Kinh độ phải là số")
    .refine((v) => Number(v) >= -180 && Number(v) <= 180, "Kinh độ từ -180 đến 180"),
  unlockLessonId: z.string().optional().or(z.literal("")),
  displayOrder: z
    .string()
    .optional()
    .refine((v) => v === undefined || v === "" || /^-?\d+$/.test(v), "Thứ tự phải là số nguyên"),
});

type FormValues = z.infer<typeof schema>;

function base(eventId: string) {
  return `/admin/events/${eventId}/map-locations`;
}

function toPayload(v: FormValues): AdminMapLocationRequest {
  return {
    title: v.title.trim(),
    description: v.description?.trim() || undefined,
    latitude: Number(v.latitude),
    longitude: Number(v.longitude),
    unlockLessonId: v.unlockLessonId?.trim() || null,
    displayOrder:
      v.displayOrder && v.displayOrder.trim() !== "" ? Number(v.displayOrder) : undefined,
  };
}

/**
 * Đã từng publish (everPublished=true) → unlockLessonId immutable — gửi giá
 * trị gốc từ record, không tin form value (readonly/disabled select có thể
 * bị drop bởi RHF).
 */
function resolveUnlockLessonId(
  editing: AdminMapLocation | null,
  formValue: string | undefined,
): string | null {
  if (editing?.everPublished) {
    return editing.unlockLessonId;
  }
  return formValue?.trim() || null;
}

/**
 * FR-36 — map-location config nested inside the event editor. Same-event
 * lesson link rule is enforced server-side (composite FK); the dropdown only
 * lists lessons of this event so admins can't pick a wrong one by accident.
 */
export function MapLocationsSection({
  eventId,
}: {
  eventId: string;
  /** Giữ chữ ký cũ; World Map không còn chọn ảnh sự kiện để lưu tọa độ. */
  eventSlug?: string;
}) {
  const qc = useQueryClient();
  const [editing, setEditing] = useState<AdminMapLocation | null>(null);
  const [serverError, setServerError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);

  const listQuery = useQuery({
    queryKey: qk.mapLocations.list(eventId),
    queryFn: () => apiFetch<AdminMapLocation[]>(base(eventId)),
  });

  const lessonsQuery = useQuery({
    queryKey: ["lessons", "list", "for-map-locations", eventId],
    queryFn: async () => {
      // Fetch EVERY page — a same-event lesson may sit beyond the first
      // 100 rows; publishing would fail server-side if it were invisible
      // here.
      const pageSize = 100;
      const first = await apiFetch<PageResponse<AdminLessonSummary>>(
        `/admin/lessons${toQuery({ eventId, size: pageSize, page: 0 })}`,
      );
      const rest = await Promise.all(
        Array.from({ length: Math.max(0, first.totalPages - 1) }, (_, i) =>
          apiFetch<PageResponse<AdminLessonSummary>>(
            `/admin/lessons${toQuery({ eventId, size: pageSize, page: i + 1 })}`,
          ),
        ),
      );
      return rest.reduce<AdminLessonSummary[]>(
        (acc, p) => acc.concat(p.content),
        [...first.content],
      );
    },
  });
  const lessons = lessonsQuery.data ?? [];

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const watchedLat = watch("latitude");
  const watchedLng = watch("longitude");
  const pickerValue = (() => {
    const lat = Number(watchedLat);
    const lng = Number(watchedLng);
    return Number.isFinite(lat) && Number.isFinite(lng) && watchedLat !== "" && watchedLng !== ""
      ? { lat, lng }
      : null;
  })();
  const invalidate = () =>
    qc.invalidateQueries({ queryKey: qk.mapLocations.list(eventId) });

  const save = useMutation({
    mutationFn: async (v: FormValues) => {
      const payload = {
        ...toPayload(v),
        unlockLessonId: resolveUnlockLessonId(editing, v.unlockLessonId),
      };
      if (editing) {
        return apiFetch<AdminMapLocation>(
          `${base(eventId)}/${editing.id}${toQuery({ expectedRowVersion: editing.rowVersion })}`,
          { method: "PATCH", body: JSON.stringify(payload) },
        );
      }
      return apiFetch<AdminMapLocation>(base(eventId), {
        method: "POST",
        body: JSON.stringify(payload),
      });
    },
    onSuccess: () => {
      invalidate();
      setEditing(null);
      setShowForm(false);
      setServerError(null);
      reset();
    },
    onError: (err) => {
      setServerError(
        err instanceof ApiClientError && err.isConflict
          ? "Địa điểm đã bị sửa đồng thời — tải lại để lấy bản mới nhất."
          : toUserMessage(err),
      );
    },
  });

  const setStatus = useMutation({
    mutationFn: (p: { loc: AdminMapLocation; status: MapLocationStatus }) =>
      apiFetch<AdminMapLocation>(
        `${base(eventId)}/${p.loc.id}/status${toQuery({
          status: p.status,
          expectedRowVersion: p.loc.rowVersion,
        })}`,
        { method: "POST" },
      ),
    onSuccess: () => {
      invalidate();
      setServerError(null);
    },
    onError: (err) => {
      // 409 = bản trong list cũ — refetch để lấy rowVersion mới nhất.
      if (err instanceof ApiClientError && err.isConflict) {
        invalidate();
        setServerError(
          "Địa điểm đã bị sửa đồng thời — đã tải lại danh sách, thử lại nhé.",
        );
        return;
      }
      setServerError(toUserMessage(err));
    },
  });

  const startEdit = (loc: AdminMapLocation) => {
    setEditing(loc);
    setShowForm(true);
    setServerError(null);
    reset({
      title: loc.title,
      description: loc.description ?? "",
      latitude: String(loc.latitude),
      longitude: String(loc.longitude),
      unlockLessonId: loc.unlockLessonId ?? "",
      displayOrder: String(loc.displayOrder),
    });
  };

  const startCreate = () => {
    setEditing(null);
    setShowForm(true);
    setServerError(null);
    reset({
      title: "",
      description: "",
      latitude: "",
      longitude: "",
      unlockLessonId: "",
      displayOrder: "",
    });
  };

  return (
    <PaperCard className="p-5">
      <section aria-label="Địa điểm trên bản đồ" className="flex flex-col gap-3">
        <SectionDivider
          eyebrow="BẢN ĐỒ"
          eyebrowColor="jade"
          title={<span id="map-locations-heading">Địa điểm trên bản đồ</span>}
          action={
            !showForm ? (
              <Button type="button" variant="secondary" onClick={startCreate}>
                + Thêm địa điểm
              </Button>
            ) : undefined
          }
        />
        <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-brand/30 bg-brand/5 px-3.5 py-2.5 text-xs text-ink">
          <span>
            Để cấu hình thư viện Media (<code>PUBLIC_PREVIEW</code> / <code>UNLOCKED_ONLY</code>) và quy tắc mở khóa đa bài học (<code>NONE</code> / <code>ANY</code> / <code>ALL</code>), hãy sử dụng Không gian Địa điểm Di tích.
          </span>
          <Link
            href={`/map-locations?eventId=${eventId}`}
            className="font-semibold text-brand hover:underline"
          >
            Mở Không gian Địa điểm Di tích (Cấu hình Media &amp; Quy tắc mở khóa) →
          </Link>
        </div>
      {listQuery.isPending && (
        <div className="flex flex-col gap-2">
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
        </div>
      )}
      {listQuery.isError && (
        <ErrorState error={listQuery.error} onRetry={() => listQuery.refetch()} />
      )}
      {listQuery.data && listQuery.data.length === 0 && !showForm && (
        <EmptyStateCard
          title="Chưa có địa điểm nào"
          description="Chưa có địa điểm nào — thêm địa điểm để hiển thị trên bản đồ của học viên."
          className="py-8"
        />
      )}

      {listQuery.data && listQuery.data.length > 0 && (
        <ul className="flex flex-col gap-2">
          {listQuery.data.map((loc) => (
            <li
              key={loc.id}
              className="flex flex-wrap items-center gap-3 rounded-md border border-border bg-surface px-3.5 py-2.5"
            >
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{loc.title}</p>
                <p className="text-xs text-ink-muted">
                  {loc.latitude}, {loc.longitude}
                  {loc.unlockLessonTitle
                    ? ` · Mở khoá bằng: ${loc.unlockLessonTitle}`
                    : " · Luôn mở"}
                </p>
              </div>
              <StatusChip status={loc.status} />
              <div className="flex gap-2">
                <Button type="button" variant="secondary" onClick={() => startEdit(loc)}>
                  Sửa
                </Button>
                {loc.status === "DRAFT" && (
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={() => setStatus.mutate({ loc, status: "PUBLISHED" })}
                  >
                    Xuất bản
                  </Button>
                )}
                {loc.status === "PUBLISHED" && (
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={() => setStatus.mutate({ loc, status: "ARCHIVED" })}
                  >
                    Lưu trữ
                  </Button>
                )}
                {loc.status === "ARCHIVED" && (
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={() => setStatus.mutate({ loc, status: "PUBLISHED" })}
                  >
                    Xuất bản lại
                  </Button>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}

      {showForm && (
        <form
          onSubmit={handleSubmit((v) => save.mutate(v))}
          noValidate
          className="flex flex-col gap-4 rounded-md border border-border bg-surface p-4"
        >
          <p className="font-display text-sm font-semibold text-ink">
            {editing ? "Sửa địa điểm" : "Thêm địa điểm mới"}
          </p>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="ml-title" className="font-medium text-ink-secondary">Tên địa điểm *</Label>
              <Input
                id="ml-title"
                placeholder="Bến Bạch Đằng"
                aria-invalid={Boolean(errors.title)}
                {...register("title")}
              />
              {errors.title && (
                <p role="alert" className="text-xs text-error">{errors.title.message}</p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="ml-order" className="font-medium text-ink-secondary">Thứ tự hiển thị</Label>
              <Input id="ml-order" inputMode="numeric" placeholder="0" {...register("displayOrder")} />
              {errors.displayOrder && (
                <p role="alert" className="text-xs text-error">{errors.displayOrder.message}</p>
              )}
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <Label className="font-medium text-ink-secondary">Vị trí trên bản đồ *</Label>
            <LatLngMapPicker
              value={pickerValue}
              imageLabel="Bản đồ địa hình Việt Nam"
              onChange={({ lat, lng }) => {
                setValue("latitude", String(lat), { shouldValidate: true, shouldDirty: true });
                setValue("longitude", String(lng), { shouldValidate: true, shouldDirty: true });
              }}
            />
            {(errors.latitude || errors.longitude) && (
              <p role="alert" className="text-xs text-error">
                {errors.latitude?.message ?? errors.longitude?.message}
              </p>
            )}
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <div className="flex flex-col gap-1.5">
                  <Label htmlFor="ml-lat" className="font-medium text-ink-secondary">Vĩ độ *</Label>
                  <Input
                    id="ml-lat"
                    inputMode="decimal"
                    placeholder="21.0285"
                aria-invalid={Boolean(errors.latitude)}
                {...register("latitude")}
              />
              {errors.latitude && (
                <p role="alert" className="text-xs text-error">{errors.latitude.message}</p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
                  <Label htmlFor="ml-lng" className="font-medium text-ink-secondary">Kinh độ *</Label>
                  <Input
                    id="ml-lng"
                    inputMode="decimal"
                    placeholder="105.8542"
                aria-invalid={Boolean(errors.longitude)}
                {...register("longitude")}
              />
              {errors.longitude && (
                <p role="alert" className="text-xs text-error">{errors.longitude.message}</p>
              )}
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="ml-desc" className="font-medium text-ink-secondary">Mô tả</Label>
            <Textarea
              id="ml-desc"
              rows={3}
              placeholder="Mô tả ngắn hiển thị trong thẻ chi tiết của học viên."
              {...register("description")}
            />
            {errors.description && (
              <p role="alert" className="text-xs text-error">{errors.description.message}</p>
            )}
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="ml-lesson" className="font-medium text-ink-secondary">Bài học mở khoá</Label>
            {lessonsQuery.isPending ? (
              <Skeleton className="h-9 w-full" />
            ) : lessonsQuery.isError ? (
              <ErrorState
                error={lessonsQuery.error}
                onRetry={() => lessonsQuery.refetch()}
              />
            ) : editing?.everPublished ? (
              // Đã từng publish → immutable, chỉ hiển thị read-only.
              <p className="rounded-md border border-border bg-muted/30 px-3 py-2 text-sm">
                {editing.unlockLessonId
                  ? (lessons.find((l) => l.id === editing.unlockLessonId)?.title
                      ?? editing.unlockLessonTitle
                      ?? editing.unlockLessonId)
                  : "— Luôn mở (không yêu cầu bài học) —"}
              </p>
            ) : (
              <Select id="ml-lesson" {...register("unlockLessonId")}>
                <option value="">— Luôn mở (không yêu cầu bài học) —</option>
                {lessons.map((l) => (
                  <option key={l.id} value={l.id}>
                    {l.title}
                    {l.status === "PUBLISHED" && l.currentVersionId
                      ? ""
                      : " (chưa xuất bản — chưa thể dùng mở khoá địa điểm published)"}
                  </option>
                ))}
              </Select>
            )}
            {editing?.everPublished ? (
              <p className="text-xs text-ink-muted">
                Địa điểm đã từng xuất bản — không thể đổi bài học mở khoá.
              </p>
            ) : (
              <p className="text-xs text-ink-muted">
                Học viên phải hoàn thành bài học này để mở khoá địa điểm. Chỉ chọn được bài học của sự kiện này.
                Địa điểm chỉ xuất bản được nếu bài học liên kết đã PUBLISHED.
              </p>
            )}
          </div>

          {serverError && (
            <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
              {serverError}
            </p>
          )}

          <div className="flex gap-3">
            <Button type="submit" disabled={isSubmitting || save.isPending}>
              {save.isPending ? "Đang lưu..." : editing ? "Lưu thay đổi" : "Tạo địa điểm"}
            </Button>
            <Button
              type="button"
              variant="secondary"
              onClick={() => {
                setShowForm(false);
                setEditing(null);
                setServerError(null);
              }}
            >
              Huỷ
            </Button>
          </div>
        </form>
      )}
      </section>
    </PaperCard>
  );
}
