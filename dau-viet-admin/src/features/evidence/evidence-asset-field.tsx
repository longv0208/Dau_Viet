"use client";

import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import type { AdminAsset } from "@/lib/dto/evidence";
import { AssetImage } from "@/features/assets/asset-image";

/** Attached-asset block inside the evidence form. */
export function EvidenceAssetField({
  attached,
  onPick,
  onClear,
}: {
  attached: AdminAsset | null;
  onPick: () => void;
  onClear: () => void;
}) {
  return (
    <div className="flex flex-col gap-2 rounded-md border border-border bg-surface p-4">
      <Label>Ảnh đính kèm</Label>
      {attached ? (
        <div className="flex items-start gap-3">
          <AssetImage
            asset={attached}
            className="size-20 rounded-md border border-border object-cover"
          />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-ink">
              {attached.originalFilename ?? "Ảnh đính kèm"}
            </p>
            <div className="mt-2 flex gap-2">
              <Button type="button" variant="secondary" size="sm" onClick={onPick}>
                Đổi ảnh
              </Button>
              <Button type="button" variant="secondary" size="sm" onClick={onClear}>
                Gỡ ảnh
              </Button>
            </div>
          </div>
        </div>
      ) : (
        <div className="flex items-center gap-3">
          <Button type="button" variant="secondary" onClick={onPick}>
            Chọn ảnh từ thư viện
          </Button>
          <p className="text-xs text-ink-muted">Tuỳ chọn — hỗ trợ minh hoạ bằng chứng.</p>
        </div>
      )}
    </div>
  );
}
