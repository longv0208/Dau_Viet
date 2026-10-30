"use client";

import { skipToken, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  CheckCircle2,
  Crosshair,
  FolderOpen,
  ImageIcon,
  Lock,
  RotateCcw,
  Sparkles,
  Trash2,
  Upload,
} from "lucide-react";
import { useRef, useState, type MouseEvent } from "react";

import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { uploadAsset, validateAssetFile } from "@/features/assets/asset-api";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";
import { useAssetObjectUrl } from "@/features/assets/use-asset-object-url";
import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { AdminAsset } from "@/lib/dto/evidence";
import {
  applyHeritagePreset,
  defaultHeritageBackgroundConfig,
  extractHeritageAssetId,
  HERITAGE_BACKGROUND_PRESETS,
  HERITAGE_TINT_OPTIONS,
  normalizeHeritageBackgroundConfig,
  updateHeritageBackgroundImage,
  type HeritageBackgroundConfig,
  type HeritageBackgroundMode,
  type HeritageTintPreset,
} from "@/lib/dto/heritage-background";
import { qk } from "@/lib/query-keys";
import { cn } from "@/lib/utils";

const ALLOWED_IMAGE_MIMES: Record<string, true> = {
  "image/jpeg": true,
  "image/png": true,
  "image/webp": true,
};

export type HeritagePreviewContext = "period" | "event" | "lesson";

interface HeritageBackgroundEditorProps {
  value: HeritageBackgroundConfig;
  onChange: (next: HeritageBackgroundConfig) => void;
  disabled?: boolean;
  contextType?: HeritagePreviewContext;
  previewTitle?: string;
  previewSubtitle?: string;
  previewParentTitle?: string;
}

function resolveTintFilter(
  mode: HeritageBackgroundMode,
  tint: HeritageTintPreset,
): string {
  const baseDesaturate = mode === "heritage_fade" ? "saturate(0.82) " : "";
  switch (tint) {
    case "warm":
      return `${baseDesaturate}sepia(0.28) contrast(0.96) brightness(1.01)`;
    case "sepia":
      return `${baseDesaturate}sepia(0.58) contrast(0.94) brightness(0.98)`;
    case "cool":
      return `${baseDesaturate}hue-rotate(-8deg) saturate(0.85) contrast(0.97)`;
    case "neutral":
      return `${baseDesaturate}saturate(0.75) contrast(0.97)`;
    case "none":
    default:
      return mode === "heritage_fade" ? "saturate(0.9)" : "none";
  }
}

function resolveTintOverlayColor(tint: HeritageTintPreset): string {
  switch (tint) {
    case "warm":
      return "rgba(224, 174, 69, 0.16)";
    case "sepia":
      return "rgba(169, 121, 50, 0.22)";
    case "cool":
      return "rgba(36, 125, 120, 0.14)";
    case "neutral":
      return "rgba(248, 240, 224, 0.18)";
    case "none":
    default:
      return "rgba(248, 240, 224, 0.08)";
  }
}

export function HeritageBackgroundEditor({
  value,
  onChange,
  disabled = false,
  contextType = "period",
  previewTitle,
  previewSubtitle,
  previewParentTitle,
}: HeritageBackgroundEditorProps) {
  const qc = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [pickedAsset, setPickedAsset] = useState<AdminAsset | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  const config = normalizeHeritageBackgroundConfig(value);
  const assetId =
    extractHeritageAssetId(config.backgroundAssetId) ??
    extractHeritageAssetId(config.backgroundImageUrl);

  const assetQuery = useQuery({
    queryKey: qk.assets.detail(assetId ?? "none"),
    queryFn:
      assetId && pickedAsset?.id !== assetId
        ? () => apiFetch<AdminAsset>(`/admin/assets/${assetId}`)
        : skipToken,
  });

  const currentAsset: AdminAsset | null =
    assetId == null
      ? null
      : pickedAsset?.id === assetId
        ? pickedAsset
        : (assetQuery.data ?? null);

  const adminContentUrl =
    currentAsset?.contentUrl ??
    (assetId ? `/api/v1/admin/assets/${assetId}/content` : null);
  const { src: blobUrl, loading: loadingBlob } =
    useAssetObjectUrl(adminContentUrl);
  const resolvedImageSrc =
    blobUrl ??
    (!assetId && config.backgroundImageUrl ? config.backgroundImageUrl : null);
  const hasImage = Boolean(assetId || config.backgroundImageUrl);

  const handleSelectAsset = (asset: AdminAsset) => {
    const mime = (asset.mimeType ?? "").toLowerCase();
    if (mime && !ALLOWED_IMAGE_MIMES[mime]) {
      setUploadError(
        `Định dạng "${asset.mimeType}" không hợp lệ cho ảnh nền. Vui lòng chọn ảnh JPEG, PNG hoặc WebP.`,
      );
      return;
    }
    setUploadError(null);
    setPickedAsset(asset);
    onChange(
      updateHeritageBackgroundImage(
        config,
        asset.id,
        `/api/v1/assets/${asset.id}/content`,
      ),
    );
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const validationErr = validateAssetFile(file);
    if (validationErr) {
      setUploadError(validationErr);
      return;
    }
    setUploading(true);
    setUploadError(null);
    try {
      const uploaded = await uploadAsset(file);
      await qc.invalidateQueries({ queryKey: ["assets"] });
      handleSelectAsset(uploaded);
    } catch (err) {
      setUploadError(toUserMessage(err));
    } finally {
      setUploading(false);
    }
  };

  const handleRemoveImage = () => {
    setUploadError(null);
    setPickedAsset(null);
    onChange(updateHeritageBackgroundImage(config, null, null));
  };

  const handleResetDefault = () => {
    setUploadError(null);
    setPickedAsset(null);
    onChange(defaultHeritageBackgroundConfig());
  };

  const handleImageFocusClick = (e: MouseEvent<HTMLDivElement>) => {
    if (disabled) return;
    const rect = e.currentTarget.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    const nextX = Math.round(((e.clientX - rect.left) / rect.width) * 100) / 100;
    const nextY = Math.round(((e.clientY - rect.top) / rect.height) * 100) / 100;
    onChange({
      ...config,
      focusX: Math.max(0, Math.min(1, nextX)),
      focusY: Math.max(0, Math.min(1, nextY)),
    });
  };

  const contextEyebrow =
    contextType === "period"
      ? "HÀNH TRÌNH THỜI KỲ"
      : contextType === "event"
        ? "CHIẾN DỊCH LỊCH SỬ"
        : "BÀI HỌC LỊCH SỬ";

  const displayTitle =
    previewTitle?.trim() ||
    (contextType === "period"
      ? "Thời nhà Lý"
      : contextType === "event"
        ? "Dời đô ra Thăng Long năm 1010"
        : "Vì sao Lý Thái Tổ dời đô về Đại La?");

  const displaySubtitle =
    previewSubtitle?.trim() ||
    (contextType === "period"
      ? "Năm 1009 – năm 1225"
      : contextType === "event"
        ? "Thăng Long · Năm 1010"
        : "Khám phá quyết sách mở đầu kỷ nguyên Đại Việt");

  const displayParent =
    previewParentTitle?.trim() || "Thời kỳ Phong kiến Độc lập Tự chủ";

  const showDynamicImage =
    config.enabled &&
    config.backgroundMode !== "none" &&
    Boolean(resolvedImageSrc);

  const fadeStopPercent = Math.round((1 - config.fadeStrength * 0.65) * 100);

  return (
    <div
      className="rounded-xl border border-border bg-surface p-4 shadow-xs"
      data-testid="heritage-background-editor"
    >
      <input
        ref={fileInputRef}
        type="file"
        accept="image/png,image/jpeg,image/webp"
        className="hidden"
        onChange={(e) => void handleFileChange(e)}
        aria-label="Tải tệp ảnh nền di sản lên"
      />

      <div className="mb-4 flex flex-wrap items-start justify-between gap-3 border-b border-border pb-3">
        <div>
          <span className="inline-flex items-center gap-1.5 text-[11px] font-bold uppercase tracking-wider text-brand">
            <Sparkles className="size-3.5" aria-hidden />
            Giao diện &amp; Ảnh nền (Dynamic Heritage Background)
          </span>
          <h3 className="mt-0.5 font-display text-base font-semibold text-ink">
            Thiết lập nền di sản &amp; xem trước trên Mobile
          </h3>
          <p className="mt-0.5 text-xs text-ink-muted">
            Chọn ảnh bình thường — hệ thống tự động hòa ảnh vào nền giấy dó cổ
            với hiệu ứng mây và chuyển sắc thống nhất.
          </p>
        </div>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          disabled={disabled || uploading}
          onClick={handleResetDefault}
          data-testid="heritage-bg-reset"
        >
          <RotateCcw className="size-3.5" aria-hidden />
          Khôi phục mặc định
        </Button>
      </div>

      <div className="grid gap-6 lg:grid-cols-[1.15fr_0.85fr] lg:items-start">
        {/* CỘT TRÁI — CẤU HÌNH */}
        <div className="space-y-4">
          {/* 1. Upload & Xem trước ảnh gốc */}
          <div className="space-y-2.5 rounded-lg border border-border bg-white p-3.5">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <Label className="text-xs font-semibold uppercase tracking-wide text-ink-secondary">
                1. Ảnh nền gốc
              </Label>
              <div className="flex flex-wrap items-center gap-1.5">
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={disabled || uploading}
                  onClick={() => fileInputRef.current?.click()}
                  data-testid="heritage-bg-upload-btn"
                >
                  <Upload className="size-3.5" aria-hidden />
                  {uploading
                    ? "Đang tải lên..."
                    : hasImage
                      ? "Tải ảnh khác"
                      : "Tải ảnh lên"}
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={disabled || uploading}
                  onClick={() => setPickerOpen(true)}
                  data-testid="heritage-bg-library-btn"
                >
                  <FolderOpen className="size-3.5" aria-hidden />
                  {hasImage ? "Thay từ thư viện" : "Chọn từ thư viện"}
                </Button>
                {hasImage && (
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={disabled || uploading}
                    onClick={handleRemoveImage}
                    data-testid="heritage-bg-remove-btn"
                  >
                    <Trash2 className="size-3.5" aria-hidden />
                    Xóa ảnh
                  </Button>
                )}
              </div>
            </div>

            {uploadError && (
              <p
                role="alert"
                className="rounded-md bg-error/10 px-3 py-2 text-xs font-medium text-error"
              >
                {uploadError}
              </p>
            )}

            {hasImage ? (
              <div className="space-y-2">
                <div
                  onClick={handleImageFocusClick}
                  role="button"
                  tabIndex={0}
                  aria-label="Nhấp vào ảnh để đặt điểm lấy nét"
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") {
                      e.preventDefault();
                      onChange({ ...config, focusX: 0.5, focusY: 0.35 });
                    }
                  }}
                  className="group relative aspect-video w-full cursor-crosshair overflow-hidden rounded-lg border border-border bg-surface"
                  data-testid="heritage-bg-source-preview"
                >
                  {resolvedImageSrc ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={resolvedImageSrc}
                      alt={currentAsset?.altText ?? "Ảnh nền gốc"}
                      className="size-full object-cover"
                    />
                  ) : (
                    <div className="flex size-full items-center justify-center text-xs text-ink-muted">
                      {loadingBlob || assetQuery.isPending
                        ? "Đang tải ảnh gốc…"
                        : "Đã chọn ảnh nền"}
                    </div>
                  )}
                  {/* Điểm lấy nét trên ảnh gốc */}
                  <div
                    className="pointer-events-none absolute -translate-x-1/2 -translate-y-1/2 transition-all duration-100"
                    style={{
                      left: `${Math.round(config.focusX * 100)}%`,
                      top: `${Math.round(config.focusY * 100)}%`,
                    }}
                  >
                    <span className="flex size-7 items-center justify-center rounded-full border-2 border-white bg-brand/85 text-white shadow-md">
                      <Crosshair className="size-3.5" aria-hidden />
                    </span>
                  </div>
                  <div className="pointer-events-none absolute bottom-2 right-2 rounded bg-black/65 px-2 py-0.5 text-[10px] font-medium text-white">
                    Nhấp lên ảnh để chọn điểm lấy nét ({Math.round(config.focusX * 100)}%,{" "}
                    {Math.round(config.focusY * 100)}%)
                  </div>
                </div>
                {currentAsset && (
                  <p className="truncate text-[11px] text-ink-muted">
                    Tệp:{" "}
                    <span className="font-medium text-ink">
                      {currentAsset.originalFilename}
                    </span>{" "}
                    · {Math.max(1, Math.round(currentAsset.sizeBytes / 1024))} KB
                  </p>
                )}
              </div>
            ) : (
              <div className="flex aspect-[21/9] w-full flex-col items-center justify-center gap-1.5 rounded-lg border border-dashed border-border bg-surface/60 px-4 text-center">
                <ImageIcon className="size-5 text-ink-muted" aria-hidden />
                <p className="text-xs font-medium text-ink">
                  Chưa chọn ảnh nền riêng — đang sử dụng Nền giấy cổ mặc định
                </p>
                <p className="text-[11px] text-ink-muted">
                  Khi tải ảnh lên, chế độ <strong>Heritage Fade</strong> sẽ tự
                  động kích hoạt.
                </p>
              </div>
            )}
          </div>

          {/* 2. Chọn Preset */}
          <div className="space-y-2 rounded-lg border border-border bg-white p-3.5">
            <Label className="text-xs font-semibold uppercase tracking-wide text-ink-secondary">
              2. Chế độ hiển thị &amp; Preset
            </Label>
            <div className="grid gap-2 sm:grid-cols-3">
              {HERITAGE_BACKGROUND_PRESETS.map((preset) => {
                const active = config.backgroundMode === preset.id;
                return (
                  <button
                    key={preset.id}
                    type="button"
                    disabled={disabled}
                    onClick={() => onChange(applyHeritagePreset(config, preset.id))}
                    data-testid={`heritage-preset-${preset.id}`}
                    className={cn(
                      "flex flex-col items-start rounded-lg border p-2.5 text-left transition-colors duration-150 cursor-pointer disabled:cursor-not-allowed",
                      active
                        ? "border-brand bg-brand/5 ring-1 ring-brand"
                        : "border-border bg-surface/50 hover:border-brand/50",
                    )}
                  >
                    <div className="flex w-full items-center justify-between gap-1">
                      <span className="text-xs font-bold text-ink">
                        {preset.label}
                      </span>
                      {preset.badge && (
                        <span className="rounded-full bg-warning/25 px-1.5 py-0.5 text-[10px] font-semibold text-ink">
                          {preset.badge}
                        </span>
                      )}
                    </div>
                    <p className="mt-1 text-[11px] leading-snug text-ink-muted">
                      {preset.description}
                    </p>
                  </button>
                );
              })}
            </div>
          </div>

          {/* 3. Tinh chỉnh Điểm lấy nét, Opacity, Fade Strength & Tông màu */}
          <div className="space-y-3 rounded-lg border border-border bg-white p-3.5">
            <Label className="text-xs font-semibold uppercase tracking-wide text-ink-secondary">
              3. Tinh chỉnh thông số nền
            </Label>

            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <div className="flex items-center justify-between text-xs">
                  <Label htmlFor="heritage-focus-x">Điểm lấy nét ngang (X)</Label>
                  <span className="font-mono text-[11px] text-ink-muted">
                    {Math.round(config.focusX * 100)}%
                  </span>
                </div>
                <input
                  id="heritage-focus-x"
                  type="range"
                  min={0}
                  max={1}
                  step={0.05}
                  disabled={disabled}
                  value={config.focusX}
                  onChange={(e) =>
                    onChange({ ...config, focusX: Number(e.target.value) })
                  }
                  className="mt-1 w-full accent-brand"
                />
              </div>

              <div>
                <div className="flex items-center justify-between text-xs">
                  <Label htmlFor="heritage-focus-y">Điểm lấy nét dọc (Y)</Label>
                  <span className="font-mono text-[11px] text-ink-muted">
                    {Math.round(config.focusY * 100)}%
                  </span>
                </div>
                <input
                  id="heritage-focus-y"
                  type="range"
                  min={0}
                  max={1}
                  step={0.05}
                  disabled={disabled}
                  value={config.focusY}
                  onChange={(e) =>
                    onChange({ ...config, focusY: Number(e.target.value) })
                  }
                  className="mt-1 w-full accent-brand"
                />
              </div>

              <div>
                <div className="flex items-center justify-between text-xs">
                  <Label htmlFor="heritage-opacity">Độ hiển thị ảnh (Opacity)</Label>
                  <span className="font-mono text-[11px] text-ink-muted">
                    {Math.round(config.imageOpacity * 100)}%
                  </span>
                </div>
                <input
                  id="heritage-opacity"
                  type="range"
                  min={0.1}
                  max={1}
                  step={0.05}
                  disabled={disabled}
                  value={config.imageOpacity}
                  onChange={(e) =>
                    onChange({ ...config, imageOpacity: Number(e.target.value) })
                  }
                  className="mt-1 w-full accent-brand"
                />
              </div>

              <div>
                <div className="flex items-center justify-between text-xs">
                  <Label htmlFor="heritage-fade">
                    Độ hòa vào nền giấy (Fade)
                  </Label>
                  <span className="font-mono text-[11px] text-ink-muted">
                    {Math.round(config.fadeStrength * 100)}%
                  </span>
                </div>
                <input
                  id="heritage-fade"
                  type="range"
                  min={0}
                  max={1}
                  step={0.05}
                  disabled={disabled}
                  value={config.fadeStrength}
                  onChange={(e) =>
                    onChange({ ...config, fadeStrength: Number(e.target.value) })
                  }
                  className="mt-1 w-full accent-brand"
                />
              </div>
            </div>

            <div className="pt-1">
              <Label className="mb-1.5 block text-xs">Tông màu di sản (Tint)</Label>
              <div className="flex flex-wrap gap-1.5">
                {HERITAGE_TINT_OPTIONS.map((opt) => {
                  const selected = config.tintPreset === opt.value;
                  return (
                    <button
                      key={opt.value}
                      type="button"
                      disabled={disabled}
                      onClick={() =>
                        onChange({ ...config, tintPreset: opt.value })
                      }
                      data-testid={`heritage-tint-${opt.value}`}
                      className={cn(
                        "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-medium transition-colors cursor-pointer",
                        selected
                          ? "border-brand bg-brand text-white"
                          : "border-border bg-surface text-ink hover:border-brand/50",
                      )}
                    >
                      <span
                        className="size-2.5 rounded-full border border-black/20"
                        style={{ backgroundColor: opt.swatch }}
                        aria-hidden
                      />
                      {opt.label}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </div>

        {/* CỘT PHẢI — LIVE MOBILE PREVIEW */}
        <div className="flex flex-col items-center">
          <div className="mb-2 flex w-full max-w-[320px] items-center justify-between text-xs text-ink-muted">
            <span className="font-semibold uppercase tracking-wider text-ink-secondary">
              Xem trước giao diện Mobile
            </span>
            <span className="rounded bg-surface-alt px-2 py-0.5 font-mono text-[11px] text-ink">
              {config.backgroundMode === "none" || !hasImage
                ? "Giấy cổ"
                : config.backgroundMode === "heritage_fade"
                  ? "Heritage Fade"
                  : "Ảnh minh họa"}
            </span>
          </div>

          {/* Khung điện thoại */}
          <div
            className="w-full max-w-[320px] overflow-hidden rounded-[28px] border-[5px] border-[#30251F] bg-[#F8F0E0] shadow-lg"
            data-testid="heritage-mobile-preview"
          >
            {/* Status bar giả lập */}
            <div className="flex items-center justify-between bg-[#30251F] px-4 py-1 text-[10px] font-medium text-[#F8F0E0]">
              <span>9:41</span>
              <span className="h-1.5 w-12 rounded-full bg-[#F8F0E0]/30" />
              <span>100%</span>
            </div>

            {/* Vùng Hero (195px) với Heritage Background */}
            <div className="relative min-h-[190px] overflow-hidden bg-[#F8F0E0]">
              {showDynamicImage && resolvedImageSrc ? (
                <>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={resolvedImageSrc}
                    alt="Xem trước nền mobile"
                    className="absolute inset-0 size-full object-cover transition-all duration-150"
                    style={{
                      objectPosition: `${Math.round(config.focusX * 100)}% ${Math.round(config.focusY * 100)}%`,
                      opacity: config.imageOpacity,
                      filter: resolveTintFilter(
                        config.backgroundMode,
                        config.tintPreset,
                      ),
                    }}
                  />
                  {/* Lớp phủ màu tông di sản */}
                  <div
                    className="pointer-events-none absolute inset-0"
                    style={{
                      backgroundColor: resolveTintOverlayColor(config.tintPreset),
                    }}
                  />
                  {/* Lớp gradient hòa vào nền giấy kem #F8F0E0 */}
                  <div
                    className="pointer-events-none absolute inset-0"
                    style={{
                      background:
                        config.backgroundMode === "heritage_fade"
                          ? `linear-gradient(180deg, rgba(248,240,224,0.18) 0%, rgba(248,240,224,${Math.min(0.95, 0.35 + config.fadeStrength * 0.45)}) ${fadeStopPercent}%, #F8F0E0 100%)`
                          : `linear-gradient(180deg, rgba(248,240,224,0.05) 0%, rgba(248,240,224,${Math.min(0.85, config.fadeStrength * 0.6)}) 78%, #F8F0E0 100%)`,
                    }}
                  />
                </>
              ) : (
                /* Nền giấy cổ + họa tiết mây truyền thống nhẹ khi không dùng ảnh */
                <div
                  className="pointer-events-none absolute inset-0"
                  style={{
                    background:
                      "radial-gradient(circle at 80% 20%, rgba(224,174,69,0.18), transparent 55%), linear-gradient(180deg, #F3E5CE 0%, #F8F0E0 100%)",
                  }}
                />
              )}

              {/* Họa tiết mây truyền thống SVG nhẹ */}
              <svg
                viewBox="0 0 320 48"
                className="pointer-events-none absolute bottom-0 left-0 w-full text-[#E0AE45]/25"
                fill="none"
                aria-hidden
              >
                <path
                  d="M0 36 C40 24, 80 44, 120 32 C160 20, 200 40, 240 28 C280 16, 300 32, 320 26 L320 48 L0 48 Z"
                  fill="currentColor"
                />
              </svg>

              {/* Nội dung Header Mobile */}
              <div className="relative z-10 flex flex-col justify-between p-3.5">
                <div className="flex items-center gap-2">
                  <span className="flex size-7 items-center justify-center rounded-full border border-[#8C6747]/35 bg-[#FBF8F1]/90 text-[#30251F] shadow-xs">
                    <ArrowLeft className="size-3.5" aria-hidden />
                  </span>
                  <span className="rounded-full border border-[#E0AE45]/60 bg-[#FBF8F1]/90 px-2.5 py-0.5 text-[9px] font-extrabold uppercase tracking-wider text-[#B93430]">
                    {contextEyebrow}
                  </span>
                </div>

                <div className="mt-7 space-y-1">
                  <p className="line-clamp-2 font-display text-base font-bold leading-snug text-[#30251F] drop-shadow-[0_1px_2px_rgba(248,240,224,0.9)]">
                    {displayTitle}
                  </p>
                  <p className="text-[11px] font-semibold text-[#B93430]">
                    {displaySubtitle}
                  </p>
                </div>
              </div>
            </div>

            {/* Vùng nội dung trên nền giấy cố định #F8F0E0 */}
            <div className="space-y-2.5 bg-[#F8F0E0] px-3 pb-4 pt-1">
              {/* Thẻ tổng quan thời kỳ */}
              <div className="rounded-xl border border-[#E0AE45]/75 bg-[#FBF8F1] p-2.5 shadow-xs">
                <div className="flex flex-wrap items-center gap-1.5">
                  <span className="inline-flex items-center gap-1 rounded-full border border-[#B93430]/40 bg-[#FCEAE8] px-2 py-0.5 text-[9px] font-bold text-[#B93430]">
                    Đang học
                  </span>
                  <span className="truncate rounded-full bg-[#F3E5CE] px-2 py-0.5 text-[9px] font-medium text-[#613B28]">
                    {displayParent}
                  </span>
                </div>
                <div className="mt-2 flex items-center justify-between text-[10px] text-[#685F56]">
                  <span>Tiến độ: 0/2 sự kiện bắt buộc</span>
                  <span className="font-bold text-[#1E4D3B]">0%</span>
                </div>
                <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-[#EFE3CC]">
                  <div className="h-full w-1/4 rounded-full bg-[#1E4D3B]" />
                </div>
              </div>

              {/* Timeline mẫu */}
              <div className="space-y-2 pl-0.5">
                <div className="flex items-stretch gap-2">
                  <div className="flex flex-col items-center">
                    <span className="flex size-5 items-center justify-center rounded-full border border-[#1E4D3B] bg-[#EBF4EF] text-[#1E4D3B]">
                      <CheckCircle2 className="size-3" aria-hidden />
                    </span>
                    <span className="w-0.5 flex-1 bg-[#D4C1A5]" />
                  </div>
                  <div className="flex-1 rounded-lg border border-[#B93430]/60 bg-[#FBF8F1] p-2 shadow-2xs">
                    <div className="flex items-center gap-1">
                      <span className="rounded-full bg-[#B93430] px-1.5 py-0.2 text-[8px] font-bold text-white">
                        Mốc tiếp theo
                      </span>
                      <span className="text-[9px] font-semibold text-[#B93430]">
                        Chặng 1 • Năm 1010
                      </span>
                    </div>
                    <p className="mt-0.5 text-[11px] font-semibold text-[#30251F]">
                      Dời đô ra Thăng Long năm 1010
                    </p>
                  </div>
                </div>

                <div className="flex items-stretch gap-2">
                  <div className="flex flex-col items-center">
                    <span className="flex size-5 items-center justify-center rounded-full border border-[#D4C1A5] bg-[#EFE3CC] text-[#685F56]">
                      <Lock className="size-2.5" aria-hidden />
                    </span>
                  </div>
                  <div className="flex-1 rounded-lg border border-[#D4C1A5] bg-[#F8F0E0] p-2">
                    <span className="text-[9px] font-medium text-[#685F56]">
                      Chặng 2 • Năm 1077
                    </span>
                    <p className="mt-0.5 text-[11px] font-semibold text-[#685F56]">
                      Chiến thắng Như Nguyệt 1077
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <AssetPickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        onSelect={handleSelectAsset}
      />
    </div>
  );
}
