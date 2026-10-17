"use client";

import { ImageIcon } from "lucide-react";

import type { AdminAsset } from "@/lib/dto/evidence";

import { useAssetObjectUrl } from "./use-asset-object-url";

/**
 * <img> for a protected admin asset — fetches bytes via the authenticated
 * BFF path and shows them through a temporary object URL. Never puts the
 * Bearer token in a URL or hits the content endpoint unauthenticated.
 */
export function AssetImage({
  asset,
  className,
  alt,
}: {
  asset: AdminAsset;
  className?: string;
  /** Optional alt override; defaults to altText → filename → "Ảnh". */
  alt?: string;
}) {
  const { src, loading, error } = useAssetObjectUrl(asset.contentUrl);
  const resolvedAlt = alt ?? asset.altText ?? asset.originalFilename ?? "Ảnh";

  if (loading) {
    return (
      <div
        className={`flex items-center justify-center bg-surface-alt text-ink-muted ${className ?? ""}`}
        aria-busy="true"
        aria-label="Đang tải ảnh"
      >
        <ImageIcon className="size-5 animate-pulse" aria-hidden />
      </div>
    );
  }
  if (error || !src) {
    return (
      <div
        className={`flex flex-col items-center justify-center gap-1 bg-surface-alt p-2 text-center text-ink-muted ${className ?? ""}`}
        role="img"
        aria-label={`Không tải được ảnh: ${resolvedAlt}`}
      >
        <ImageIcon className="size-5" aria-hidden />
        <span className="text-[10px]">Không tải được ảnh</span>
      </div>
    );
  }
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={src} alt={resolvedAlt} className={className} loading="lazy" />;
}
