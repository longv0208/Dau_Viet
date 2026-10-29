"use client";

import { useRef, useState } from "react";
import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query";
import { Upload } from "lucide-react";

import { apiFetch, toQuery } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminAsset } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { EmptyStateCard } from "@/components/atoms/empty-state-card";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";
import { uploadAsset, validateAssetFile } from "./asset-api";
import { AssetCard } from "./asset-card";
import { AssetPreviewDialog } from "./asset-preview-dialog";

const PAGE_SIZE = 24;

/** /assets — grid library: thumbnails + upload + preview modal + search + pagination. */
export function AssetsLibrary() {
  const qc = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [page, setPage] = useState(0);
  const [searchInput, setSearchInput] = useState("");
  const [q, setQ] = useState("");
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [altText, setAltText] = useState("");
  const [preview, setPreview] = useState<AdminAsset | null>(null);

  const query = useQuery({
    queryKey: qk.assets.list({ page, size: PAGE_SIZE, q: q || undefined }),
    queryFn: () =>
      apiFetch<PageResponse<AdminAsset>>(
        `/admin/assets${toQuery({ page, size: PAGE_SIZE, q: q || undefined })}`,
      ),
    placeholderData: keepPreviousData,
  });

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const invalid = validateAssetFile(file);
    if (invalid) {
      setUploadError(invalid);
      return;
    }
    setUploading(true);
    setUploadError(null);
    try {
      const created = await uploadAsset(file, altText || undefined);
      setAltText("");
      setPage(0);
      await qc.invalidateQueries({ queryKey: ["assets"] });
      setPreview(created);
    } catch (err) {
      setUploadError(toUserMessage(err));
    } finally {
      setUploading(false);
    }
  }

  const totalPages = Math.max(1, query.data?.totalPages ?? 0);
  const totalElements = query.data?.totalElements ?? 0;
  const items = query.data?.content ?? [];

  return (
    <div className="flex flex-col gap-4">
      <PaperCard className="p-5">
        <SectionDivider
          eyebrow="TẢI LÊN"
          eyebrowColor="jade"
          title="Thêm ảnh vào thư viện"
          className="mb-4"
        />
        <div className="flex flex-wrap items-end gap-3">
          <div className="flex min-w-64 flex-1 flex-col gap-1.5">
            <Label htmlFor="assetAlt" className="font-medium text-ink-secondary">Mô tả ảnh</Label>
          <Input
            id="assetAlt"
            value={altText}
            onChange={(e) => setAltText(e.target.value)}
            placeholder="Ví dụ: Tranh khắc gỗ trận Bạch Đằng"
            maxLength={255}
          />
          <p className="text-xs text-ink-muted">
            Hiển thị khi ảnh không tải được và đọc cho người khiếm thị; có thể để trống.
          </p>
        </div>
        <div>
          <input
            ref={fileRef}
            type="file"
            accept="image/png,image/jpeg,image/webp"
            className="hidden"
            onChange={handleUpload}
          />
          <Button
            type="button"
            onClick={() => fileRef.current?.click()}
            disabled={uploading}
          >
            <Upload aria-hidden /> {uploading ? "Đang tải..." : "Tải ảnh lên"}
          </Button>
          <p className="mt-1 text-xs text-ink-muted">PNG, JPEG hoặc WebP — tối đa 10&nbsp;MB.</p>
        </div>
        </div>
      </PaperCard>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          setQ(searchInput.trim());
          setPage(0);
        }}
        className="flex max-w-md items-center gap-2"
      >
        <Input
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          placeholder="Tìm theo tên tệp hoặc mô tả ảnh..."
          aria-label="Tìm kiếm ảnh trong thư viện"
        />
        <Button type="submit" variant="secondary">
          Tìm
        </Button>
      </form>

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
      {query.isError && <ErrorState error={query.error} onRetry={() => query.refetch()} />}
      {query.isSuccess && items.length === 0 && (
        <EmptyStateCard
          title="Chưa có ảnh nào trong thư viện"
          description="Tải ảnh lên để tái sử dụng trong nhiều bài học."
        />
      )}
      {query.isSuccess && items.length > 0 && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
          {items.map((a) => (
            <AssetCard key={a.id} asset={a} onPreview={setPreview} />
          ))}
        </div>
      )}

      {totalElements > 0 && (
        <div className="flex items-center justify-between text-sm text-ink-muted">
          <span>
            Trang {page + 1} / {totalPages} ({totalElements} ảnh)
          </span>
          <div className="flex gap-2">
            <Button variant="secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>
              Trước
            </Button>
            <Button
              variant="secondary"
              disabled={page + 1 >= totalPages}
              onClick={() => setPage(page + 1)}
            >
              Sau
            </Button>
          </div>
        </div>
      )}

      <AssetPreviewDialog asset={preview} onClose={() => setPreview(null)} />
    </div>
  );
}
