"use client";

import { useRef, useState } from "react";
import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query";
import { Upload } from "lucide-react";

import { apiFetch, toQuery } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminAsset } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { Dialog } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";
import { EmptyState } from "@/components/empty-state";

import { assetContentSrc, uploadAsset } from "./asset-api";

const PAGE_SIZE = 24;

/** Modal grid of ACTIVE assets. `onSelect` fires once when the user clicks a tile. */
export function AssetPickerDialog({
  open,
  onOpenChange,
  onSelect,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelect: (asset: AdminAsset) => void;
}) {
  const qc = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [page, setPage] = useState(0);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  const query = useQuery({
    queryKey: qk.assets.list({ page, size: PAGE_SIZE }),
    queryFn: () =>
      apiFetch<PageResponse<AdminAsset>>(
        `/admin/assets${toQuery({ page, size: PAGE_SIZE })}`,
      ),
    placeholderData: keepPreviousData,
    enabled: open,
  });

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setUploading(true);
    setUploadError(null);
    try {
      await uploadAsset(file);
      await qc.invalidateQueries({ queryKey: ["assets"] });
    } catch (err) {
      setUploadError(toUserMessage(err));
    } finally {
      setUploading(false);
    }
  }

  const totalPages = query.data?.totalPages ?? 0;
  const items = query.data?.content ?? [];

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Chọn ảnh từ thư viện"
      description="Chọn một ảnh đã tải lên để gắn vào nội dung."
      size="xl"
      footer={
        <>
          <input
            ref={fileRef}
            type="file"
            accept="image/png,image/jpeg,image/webp"
            className="hidden"
            onChange={handleUpload}
          />
          <Button
            type="button"
            variant="secondary"
            onClick={() => fileRef.current?.click()}
            disabled={uploading}
          >
            <Upload aria-hidden /> {uploading ? "Đang tải..." : "Tải ảnh lên"}
          </Button>
          <Button type="button" variant="secondary" onClick={() => onOpenChange(false)}>
            Đóng
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {uploadError && (
          <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
            {uploadError}
          </p>
        )}

        {query.isPending && (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
            {Array.from({ length: 8 }).map((_, i) => (
              <Skeleton key={i} className="aspect-square w-full rounded-md" />
            ))}
          </div>
        )}
        {query.isError && (
          <ErrorState error={query.error} onRetry={() => query.refetch()} />
        )}
        {query.isSuccess && items.length === 0 && (
          <EmptyState
            title="Chưa có ảnh nào"
            description="Tải ảnh lên bằng nút bên dưới để bắt đầu sử dụng."
          />
        )}
        {query.isSuccess && items.length > 0 && (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
            {items.map((a) => (
              <button
                key={a.id}
                type="button"
                onClick={() => {
                  onSelect(a);
                  onOpenChange(false);
                }}
                className="group flex flex-col overflow-hidden rounded-md border border-border bg-white text-left transition-colors hover:border-brand hover:bg-brand/5"
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={assetContentSrc(a.contentUrl)}
                  alt={a.altText ?? a.originalFilename ?? "Ảnh"}
                  className="aspect-square w-full bg-surface-alt object-cover"
                  loading="lazy"
                />
                <span className="truncate px-2 py-1.5 text-xs text-ink group-hover:text-brand">
                  {a.originalFilename ?? a.id}
                </span>
              </button>
            ))}
          </div>
        )}

        {totalPages > 1 && (
          <div className="flex items-center justify-between text-sm text-ink-muted">
            <span>
              Trang {page + 1} / {totalPages}
            </span>
            <div className="flex gap-2">
              <Button variant="secondary" size="sm" disabled={page === 0} onClick={() => setPage(page - 1)}>
                Trước
              </Button>
              <Button
                variant="secondary"
                size="sm"
                disabled={page + 1 >= totalPages}
                onClick={() => setPage(page + 1)}
              >
                Sau
              </Button>
            </div>
          </div>
        )}
      </div>
    </Dialog>
  );
}
