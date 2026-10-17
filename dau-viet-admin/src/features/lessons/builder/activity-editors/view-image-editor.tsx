"use client";

import { useQuery } from "@tanstack/react-query";
import { ImageIcon, RefreshCw, Trash2 } from "lucide-react";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import type { AdminAsset } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { assetContentSrc } from "@/features/assets/asset-api";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";

import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/** VIEW_IMAGE — config.imageAssetId (required at SAVE) + caption.
 *  Picker replaces manual UUID entry; preview shows the stored asset. */
export function ViewImageEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const [pickerOpen, setPickerOpen] = useState(false);
  const assetId = (activity.config?.imageAssetId as string) ?? "";
  const caption = (activity.config?.caption as string) ?? "";

  // Resolve the chosen asset for preview (cached after first select).
  const assetQuery = useQuery({
    queryKey: qk.assets.detail(assetId),
    queryFn: () => apiFetch<AdminAsset>(`/admin/assets/${assetId}`),
    enabled: Boolean(assetId),
  });
  const asset = assetQuery.data;

  function clear() {
    const cfg = { ...activity.config };
    delete cfg.imageAssetId;
    onChange({ config: cfg });
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />

      <div className="flex flex-col gap-1.5">
        <Label>Hình ảnh hiển thị *</Label>
        {assetId ? (
          <div className="flex items-start gap-3 rounded-md border border-border bg-surface p-2">
            {asset ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={assetContentSrc(asset.contentUrl)}
                alt={asset.altText ?? asset.originalFilename ?? "Ảnh đã chọn"}
                className="size-20 shrink-0 rounded-md border border-border object-cover"
              />
            ) : (
              <div className="flex size-20 shrink-0 items-center justify-center rounded-md border border-border bg-surface-alt text-ink-muted">
                <ImageIcon className="size-6" aria-hidden />
              </div>
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-ink">
                {asset?.originalFilename ?? assetId}
              </p>
              {assetQuery.isPending && (
                <p className="text-xs text-ink-muted">Đang tải thông tin ảnh…</p>
              )}
              {assetQuery.isError && (
                <p className="text-xs text-error">
                  Không tìm thấy asset (có thể đã bị xoá) — chọn lại ảnh khác.
                </p>
              )}
              {asset?.altText && (
                <p className="mt-0.5 line-clamp-2 text-xs text-ink-muted">{asset.altText}</p>
              )}
            </div>
            {!readOnly && (
              <div className="flex shrink-0 gap-1">
                <Button
                  variant="secondary"
                  className="h-9 px-2"
                  aria-label="Đổi ảnh"
                  onClick={() => setPickerOpen(true)}
                >
                  <RefreshCw className="size-3.5" />
                </Button>
                <Button
                  variant="secondary"
                  className="h-9 px-2"
                  aria-label="Gỡ ảnh"
                  onClick={clear}
                >
                  <Trash2 className="size-3.5" />
                </Button>
              </div>
            )}
          </div>
        ) : (
          <div className="rounded-md border border-dashed border-border p-4 text-center">
            <ImageIcon className="mx-auto mb-1 size-6 text-ink-muted" aria-hidden />
            <p className="mb-2 text-xs text-ink-muted">Chưa chọn hình ảnh.</p>
            {!readOnly && (
              <Button variant="secondary" size="sm" onClick={() => setPickerOpen(true)}>
                Chọn ảnh từ thư viện
              </Button>
            )}
          </div>
        )}
        {!assetId && (
          <p role="alert" className="text-xs text-error">
            Cần chọn hình ảnh để lưu hợp lệ.
          </p>
        )}
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`cap-${activity.id}`}>Chú thích hình</Label>
        <Input
          id={`cap-${activity.id}`}
          value={caption}
          disabled={readOnly}
          placeholder="Mô tả ngắn hiển thị dưới hình"
          onChange={(e) =>
            onChange({ config: { ...activity.config, caption: e.target.value } })
          }
        />
      </div>

      <AssetPickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        onSelect={(a: AdminAsset) =>
          onChange({ config: { ...activity.config, imageAssetId: a.id } })
        }
      />
    </div>
  );
}

