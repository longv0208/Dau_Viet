"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { skipToken, useQuery, useQueryClient } from "@tanstack/react-query";
import { FolderOpen, ImageIcon, Trash2, Upload } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { AdminEventDetail } from "@/lib/dto/event";
import type { AdminAsset } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { uploadAsset, validateAssetFile } from "@/features/assets/asset-api";
import { AssetImage } from "@/features/assets/asset-image";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";
import { HeritageBackgroundEditor } from "@/components/heritage/heritage-background-editor";
import {
  normalizeHeritageBackgroundConfig,
  type HeritageBackgroundConfig,
} from "@/lib/dto/heritage-background";
import { applyServerFieldErrors, toSlug } from "@/lib/form-utils";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  confirmDiscard,
  useUnsavedChangesGuard,
} from "@/components/unsaved-changes-guard";

const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ALLOWED_COVER_MIMES: Record<string, true> = {
  "image/jpeg": true,
  "image/png": true,
  "image/webp": true,
};

const LEGACY_COVER_PREVIEW_BY_KEY: Record<string, string> = {
  "events/hung-vuong/hero.jpg": "/heritage/den-hung-phong-chau.jpg",
  "events/hai-ba-trung-40/hero.jpg": "/heritage/me-linh-hai-ba-trung.jpg",
  "events/hai-ba-trung/hero.jpg": "/heritage/me-linh-hai-ba-trung.jpg",
  "events/bach-dang-938/hero.jpg": "/heritage/bai-coc-bach-dang.jpg",
  "events/thang-long-1010/hero.jpg": "/heritage/hoang-thanh-thang-long.jpg",
  "events/nhu-nguyet-1077/hero.jpg": "/heritage/phong-tuyen-nhu-nguyet.jpg",
  "events/dien-bien-phu-1954/hero.jpg": "/heritage/doi-a1-dien-bien-phu.jpg",
};

function extractAssetId(raw: string | null | undefined): string | null {
  const trimmed = raw?.trim() ?? "";
  if (!trimmed) return null;
  if (UUID_RE.test(trimmed)) return trimmed;
  const match = trimmed.match(/^\/api\/v1\/(?:admin\/)?assets\/([0-9a-f-]{36})\/content$/i);
  const candidate = match?.[1];
  return candidate && UUID_RE.test(candidate) ? candidate : null;
}

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
  const archived = initial?.status === "ARCHIVED";
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [serverError, setServerError] = useState<string | null>(null);
  const [savedTick, setSavedTick] = useState(false);
  const [slugTouched, setSlugTouched] = useState(isEdit);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [pickedAsset, setPickedAsset] = useState<AdminAsset | null>(null);
  const [uploadingCover, setUploadingCover] = useState(false);
  const [coverUploadError, setCoverUploadError] = useState<string | null>(null);
  const [backgroundConfig, setBackgroundConfig] =
    useState<HeritageBackgroundConfig>(() =>
      normalizeHeritageBackgroundConfig(initial?.backgroundConfig),
    );
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
  const eraValue = watch("era");
  const periodValue = watch("period");
  const coverAssetKeyValue = watch("coverAssetKey") ?? "";
  const coverAssetId = extractAssetId(coverAssetKeyValue);
  const coverAssetQuery = useQuery({
    queryKey: qk.assets.detail(coverAssetId ?? "none"),
    queryFn:
      coverAssetId && pickedAsset?.id !== coverAssetId
        ? () => apiFetch<AdminAsset>(`/admin/assets/${coverAssetId}`)
        : skipToken,
  });

  const currentCoverAsset: AdminAsset | null =
    coverAssetId == null
      ? null
      : pickedAsset?.id === coverAssetId
        ? pickedAsset
        : (coverAssetQuery.data ?? null);

  const trimmedCoverKey = coverAssetKeyValue.trim();
  const hasCover = Boolean(trimmedCoverKey);
  const legacyCoverSrc =
    !coverAssetId && trimmedCoverKey
      ? (LEGACY_COVER_PREVIEW_BY_KEY[trimmedCoverKey] ?? null)
      : null;

  function handleSelectAsset(asset: AdminAsset) {
    const mime = (asset.mimeType ?? "").toLowerCase();
    if (mime && !ALLOWED_COVER_MIMES[mime]) {
      setCoverUploadError(
        `Định dạng "${asset.mimeType}" không hợp lệ cho ảnh bìa. Vui lòng chọn ảnh PNG, JPEG hoặc WebP.`,
      );
      return;
    }
    setCoverUploadError(null);
    setPickedAsset(asset);
    setValue("coverAssetKey", asset.id, { shouldDirty: true, shouldValidate: true });
  }

  async function handleDirectFileUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const invalid = validateAssetFile(file);
    if (invalid) {
      setCoverUploadError(invalid);
      return;
    }
    setUploadingCover(true);
    setCoverUploadError(null);
    try {
      const created = await uploadAsset(file);
      await qc.invalidateQueries({ queryKey: ["assets"] });
      handleSelectAsset(created);
    } catch (err) {
      setCoverUploadError(toUserMessage(err));
    } finally {
      setUploadingCover(false);
    }
  }

  function handleClearCover() {
    setCoverUploadError(null);
    setPickedAsset(null);
    setValue("coverAssetKey", "", { shouldDirty: true, shouldValidate: true });
  }

  // Auto-suggest slug from title until the admin touches the slug field.
  useEffect(() => {
    if (!slugTouched) setValue("slug", toSlug(titleValue), { shouldDirty: false });
  }, [titleValue, slugTouched, setValue]);

  useUnsavedChangesGuard(isDirty);

  const onSubmit = handleSubmit(async (v) => {
    setServerError(null);
    const nextCover = v.coverAssetKey?.trim() ?? "";
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
      coverAssetKey: nextCover
        ? nextCover
        : isEdit && initial?.coverAssetKey
          ? ""
        : undefined,
      tags: v.tags.map((t) => t.value.trim()).filter(Boolean),
      backgroundConfig,
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
        setBackgroundConfig(normalizeHeritageBackgroundConfig(res.backgroundConfig));
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
    <PaperCard className="p-5">
      <SectionDivider
        eyebrow="THÔNG TIN"
        title={isEdit ? "Thông tin sự kiện lịch sử" : "Khởi tạo sự kiện lịch sử"}
        className="mb-5"
      />
      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
        <div className="grid gap-4 md:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="title" className="font-medium text-ink-secondary">Tiêu đề *</Label>
          <Input
            id="title"
            placeholder="Trận Bạch Đằng năm 938"
            aria-invalid={Boolean(errors.title)}
            {...register("title")}
          />
          {errors.title && <p role="alert" className="text-xs text-error">{errors.title.message}</p>}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="slug" className="font-medium text-ink-secondary">Đường dẫn rút gọn *</Label>
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
          <Label htmlFor="era" className="font-medium text-ink-secondary">Thời kỳ</Label>
          <Input id="era" placeholder="Thời Ngô — Đinh — Tiền Lê" {...register("era")} />
          {errors.era && <p role="alert" className="text-xs text-error">{errors.era.message}</p>}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="period" className="font-medium text-ink-secondary">Giai đoạn</Label>
          <Input id="period" placeholder="Mùa Đông 938" {...register("period")} />
          {errors.period && <p role="alert" className="text-xs text-error">{errors.period.message}</p>}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="startYear" className="font-medium text-ink-secondary">Năm bắt đầu</Label>
          <Input id="startYear" inputMode="numeric" placeholder="938" {...register("startYear")} />
          {errors.startYear && <p role="alert" className="text-xs text-error">{errors.startYear.message}</p>}
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="location" className="font-medium text-ink-secondary">Địa điểm</Label>
        <Input id="location" placeholder="Sông Bạch Đằng, Quảng Ninh" {...register("location")} />
        {errors.location && <p role="alert" className="text-xs text-error">{errors.location.message}</p>}
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="summary" className="font-medium text-ink-secondary">Tóm tắt *</Label>
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
        <Label htmlFor="description" className="font-medium text-ink-secondary">Mô tả chi tiết</Label>
        <Textarea
          id="description"
          rows={6}
          placeholder="Bối cảnh lịch sử, diễn biến chính, ý nghĩa."
          {...register("description")}
        />
      </div>

      <div className="flex flex-col gap-3 rounded-lg border border-border bg-surface p-4">
        <input id="coverAssetKey" type="hidden" {...register("coverAssetKey")} />
        <input
          ref={fileInputRef}
          type="file"
          accept="image/png,image/jpeg,image/webp"
          className="hidden"
          onChange={handleDirectFileUpload}
          aria-label="Tải tệp ảnh bìa lên"
        />

        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="space-y-0.5">
            <Label htmlFor="coverAssetKey" className="font-medium text-ink-secondary">Ảnh bìa</Label>
            <p className="text-xs text-ink-muted">
              Tải ảnh mới lên hoặc chọn ảnh có sẵn từ thư viện media (ưu tiên tỷ lệ 16:9, PNG/JPEG/WebP ≤ 10 MB).
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={archived || uploadingCover}
              onClick={() => fileInputRef.current?.click()}
            >
              <Upload className="size-4" aria-hidden />
              {uploadingCover ? "Đang tải lên..." : "Tải ảnh lên"}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={archived || uploadingCover}
              onClick={() => setPickerOpen(true)}
            >
              <FolderOpen className="size-4" aria-hidden />
              Chọn từ thư viện
            </Button>
            {hasCover && (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                disabled={archived || uploadingCover}
                onClick={handleClearCover}
              >
                <Trash2 className="size-4" aria-hidden />
                Gỡ ảnh
              </Button>
            )}
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-[minmax(16rem,22rem)_1fr] md:items-center">
          <div className="overflow-hidden rounded-lg border border-border bg-white shadow-xs">
            {coverAssetId && currentCoverAsset ? (
              <AssetImage
                asset={currentCoverAsset}
                className="aspect-video w-full object-cover"
              />
            ) : coverAssetId && coverAssetQuery.isPending ? (
              <div className="flex aspect-video w-full items-center justify-center bg-surface text-xs text-ink-muted">
                Đang tải ảnh bìa…
              </div>
            ) : legacyCoverSrc ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={legacyCoverSrc}
                alt={titleValue || "Ảnh bìa sự kiện"}
                className="aspect-video w-full object-cover"
              />
            ) : hasCover ? (
              <div className="flex aspect-video w-full flex-col items-center justify-center gap-1.5 bg-surface/70 px-4 text-center text-ink-muted">
                <ImageIcon className="size-6 text-ink-muted" aria-hidden />
                <p className="text-xs font-medium text-ink">Đã gắn ảnh bìa</p>
                <p className="max-w-full truncate font-mono text-[11px] text-ink-muted">
                  {trimmedCoverKey}
                </p>
              </div>
            ) : (
              <div className="flex aspect-video w-full flex-col items-center justify-center gap-2 bg-surface/70 px-4 text-center text-ink-muted">
                <div className="flex size-10 items-center justify-center rounded-full border border-dashed border-border bg-white">
                  <ImageIcon className="size-5 text-ink-muted" aria-hidden />
                </div>
                <p className="text-sm font-medium text-ink">Chưa có ảnh bìa sự kiện</p>
                <p className="text-xs text-ink-muted">
                  Bấm &ldquo;Tải ảnh lên&rdquo; hoặc &ldquo;Chọn từ thư viện&rdquo; để gắn ảnh bìa.
                </p>
              </div>
            )}
          </div>

          <div className="min-w-0 space-y-2 text-xs text-ink-muted">
            {currentCoverAsset ? (
              <div className="space-y-1 rounded-lg border border-border bg-white p-3">
                <p className="truncate text-sm font-medium text-ink">
                  {currentCoverAsset.originalFilename ?? "Ảnh bìa sự kiện"}
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
            ) : hasCover ? (
              <div className="space-y-1 rounded-lg border border-border bg-white p-3">
                <p className="text-sm font-medium text-ink">Ảnh bìa hiện tại</p>
                <p className="font-mono text-[11px] text-ink-muted">{trimmedCoverKey}</p>
                <p>
                  Bạn có thể tải ảnh mới lên hoặc chọn ảnh từ thư viện media để thay thế.
                </p>
              </div>
            ) : (
              <div className="space-y-1 rounded-lg border border-dashed border-border bg-white/60 p-3">
                <p className="font-medium text-ink">Hướng dẫn ảnh bìa</p>
                <p>• Tỷ lệ hiển thị chuẩn: 16:9 (khuyến nghị 1200×675 px).</p>
                <p>• Định dạng hỗ trợ: PNG, JPEG, WebP (tối đa 10 MB).</p>
                <p>• Ảnh tải lên được lưu vào Thư viện media để có thể chọn lại.</p>
              </div>
            )}

            {coverUploadError && (
              <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-xs text-error">
                {coverUploadError}
              </p>
            )}
            {errors.coverAssetKey && (
              <p role="alert" className="text-xs text-error">
                {errors.coverAssetKey.message}
              </p>
            )}
          </div>
        </div>
      </div>

      <HeritageBackgroundEditor
        value={backgroundConfig}
        onChange={setBackgroundConfig}
        disabled={archived || isSubmitting}
        contextType="event"
        previewTitle={titleValue}
        previewSubtitle={periodValue}
        previewParentTitle={eraValue}
      />

      <div className="flex flex-col gap-2">
        <Label className="font-medium text-ink-secondary">Tags</Label>
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

      <AssetPickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        onSelect={handleSelectAsset}
      />
      </form>
    </PaperCard>
  );
}
