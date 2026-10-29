"use client";

import { Copy } from "lucide-react";
import { useState } from "react";

import { PaperCard } from "@/components/atoms/paper-card";
import { Button } from "@/components/ui/button";
import type { AdminAsset } from "@/lib/dto/evidence";

import { AssetImage } from "./asset-image";

export function formatAssetSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

/** Single tile in the asset grid: thumbnail + meta + copy-id. */
export function AssetCard({
  asset,
  onPreview,
}: {
  asset: AdminAsset;
  onPreview: (a: AdminAsset) => void;
}) {
  const [copied, setCopied] = useState(false);

  async function copyId() {
    try {
      await navigator.clipboard.writeText(asset.id);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      /* clipboard may be blocked — ignore */
    }
  }

  return (
    <PaperCard interactive className="group flex flex-col overflow-hidden p-0">
      <button
        type="button"
        onClick={() => onPreview(asset)}
        className="relative block aspect-square w-full overflow-hidden border-b border-border bg-surface"
        aria-label={`Xem ${asset.originalFilename ?? "Ảnh không tên"}`}
      >
        <AssetImage
          asset={asset}
          className="size-full object-cover transition-transform group-hover:scale-105"
        />
      </button>
      <div className="flex flex-col gap-1 px-2 py-2">
        <p
          className="truncate text-xs font-medium text-ink"
          title={asset.originalFilename ?? "Ảnh không tên"}
        >
          {asset.originalFilename ?? "Ảnh không tên"}
        </p>
        <p className="text-xs text-ink-muted">
          {formatAssetSize(asset.sizeBytes)}
        </p>
        {asset.altText && (
          <p className="truncate text-xs text-ink-muted" title={asset.altText}>
            {asset.altText}
          </p>
        )}
        <div className="mt-1 flex items-center gap-1">
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={copyId}
            aria-label={`Sao chép mã ảnh ${asset.id}`}
          >
            <Copy aria-hidden /> {copied ? "Đã chép" : "Sao chép mã ảnh"}
          </Button>
        </div>
      </div>
    </PaperCard>
  );
}
