"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
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
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";
import { ErrorState } from "@/components/error-state";

const LAT_RE = /^-?\d+(\.\d+)?$/;

const schema = z.object({
  title: z.string().min(1, "Vui lòng nhập tên địa điểm").max(255, "Tối đa 255 ký tự"),
  description: z.string().max(4000, "Tối đa 4000 ký tự").optional().or(z.literal("")),
  latitude: z
    .string()
    .min(1, "Vui lòng nhập vĩ độ")
    .regex(LAT_RE, "Vĩ độ phải là số")
    .refine((v) => Number(v) >= -90 && Number(v) <= 90, "Vĩ độ từ -90 đến 90"),
  longitude: z
    .string()
    .min(1, "Vui lòng nhập kinh độ")
    .regex(LAT_RE, "Kinh độ phải là số")
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
 * FR-36 — map-location config nested inside the event editor. Same-event
 * lesson link rule is enforced server-side (composite FK); the dropdown only
 * lists lessons of this event so admins can't pick a wrong one by accident.
 */
export function MapLocationsSection({ eventId }: { eventId: string }) {
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
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const invalidate = () =>
    qc.invalidateQueries({ queryKey: qk.mapLocations.list(eventId) });

  const save = useMutation({
    mutationFn: async (v: FormValues) => {
      if (editing) {
        return apiFetch<AdminMapLocation>(
          `${base(eventId)}/${editing.id}${toQuery({ expectedRowVersion: editing.rowVersion })}`,
          { method: "PATCH", body: JSON.stringify(toPayload(v)) },
        );
      }
      return apiFetch<AdminMapLocation>(base(eventId), {
        method: "POST",
        body: JSON.stringify(toPayload(v)),
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
    <section aria-labelledby="map-locations-heading" className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 id="map-locations-heading" className="text-base font-semibold">
          Địa điểm trên bản đồ
        </h2>
        {!showForm && (
          <Button type="button" variant="secondary" onClick={startCreate}>
            + Thêm địa điểm
          </Button>
        )}
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
        <p className="text-sm text-ink-muted">
          Chưa có địa điểm nào — thêm địa điểm để hiển thị trên bản đồ của học viên.
        </p>
      )}

      {listQuery.data && listQuery.data.length > 0 && (
        <ul className="flex flex-col gap-2">
          {listQuery.data.map((loc) => (
            <li
              key={loc.id}
              className="flex flex-wrap items-center gap-3 rounded-md border border-border px-3 py-2"
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
          className="flex flex-col gap-4 rounded-md border border-border p-4"
        >
          <p className="text-sm font-medium">
            {editing ? "Sửa địa điểm" : "Thêm địa điểm mới"}
          </p>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="ml-title">Tên địa điểm *</Label>
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
              <Label htmlFor="ml-order">Thứ tự hiển thị</Label>
              <Input id="ml-order" inputMode="numeric" placeholder="0" {...register("displayOrder")} />
              {errors.displayOrder && (
                <p role="alert" className="text-xs text-error">{errors.displayOrder.message}</p>
              )}
            </div>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="ml-lat">Vĩ độ *</Label>
              <Input
                id="ml-lat"
                inputMode="decimal"
                placeholder="20.9101"
                aria-invalid={Boolean(errors.latitude)}
                {...register("latitude")}
              />
              {errors.latitude && (
                <p role="alert" className="text-xs text-error">{errors.latitude.message}</p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="ml-lng">Kinh độ *</Label>
              <Input
                id="ml-lng"
                inputMode="decimal"
                placeholder="106.8231"
                aria-invalid={Boolean(errors.longitude)}
                {...register("longitude")}
              />
              {errors.longitude && (
                <p role="alert" className="text-xs text-error">{errors.longitude.message}</p>
              )}
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="ml-desc">Mô tả</Label>
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
            <Label htmlFor="ml-lesson">Bài học mở khoá</Label>
            {lessonsQuery.isPending ? (
              <Skeleton className="h-9 w-full" />
            ) : lessonsQuery.isError ? (
              <ErrorState
                error={lessonsQuery.error}
                onRetry={() => lessonsQuery.refetch()}
              />
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
            <p className="text-xs text-ink-muted">
              Học viên phải hoàn thành bài học này để mở khoá địa điểm. Chỉ chọn được bài học của sự kiện này.
              Địa điểm chỉ xuất bản được nếu bài học liên kết đã PUBLISHED.
            </p>
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
  );
}
