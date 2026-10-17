"use client";

import { Dialog } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import type { AdminAsset } from "@/lib/dto/evidence";

import { formatAssetSize } from "./asset-card";
import { AssetImage } from "./asset-image";

/** Lightbox-style preview for one asset. */
export function AssetPreviewDialog({
  asset,
  onClose,
}: {
  asset: AdminAsset | null;
  onClose: () => void;
}) {
  return (
    <Dialog
      open={Boolean(asset)}
      onOpenChange={(o) => !o && onClose()}
      title={asset?.originalFilename ?? "Xem ảnh"}
      size="lg"
      footer={
        <Button type="button" variant="secondary" onClick={onClose}>
          Đóng
        </Button>
      }
    >
      {asset && (
        <div className="flex flex-col gap-3">
          <AssetImage
            asset={asset}
            className="max-h-[60vh] w-full rounded-md object-contain"
          />
          <dl className="grid gap-1 text-xs text-ink-muted">
            <div>
              <dt className="font-medium text-ink">ID</dt>
              <dd className="break-all">{asset.id}</dd>
            </div>
            <div>
              <dt className="font-medium text-ink">Định dạng</dt>
              <dd>
                {asset.mimeType} · {formatAssetSize(asset.sizeBytes)}
              </dd>
            </div>
            {asset.altText && (
              <div>
                <dt className="font-medium text-ink">Alt text</dt>
                <dd>{asset.altText}</dd>
              </div>
            )}
          </dl>
        </div>
      )}
    </Dialog>
  );
}
