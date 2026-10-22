"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import type { AdminAsset } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { AssetImage } from "@/features/assets/asset-image";
import { Textarea } from "@/components/ui/textarea";

import type { PreviewActivityProps } from "./types";

/** READ — instruction + paragraphs from config.text. */
export function ReadActivityView({ activity }: PreviewActivityProps) {
  const text = typeof activity.config?.text === "string" ? activity.config.text : "";
  const animationKey =
    typeof activity.config?.animationKey === "string"
      ? activity.config.animationKey
      : null;
  const paragraphs = text.split(/\n{2,}/).filter(Boolean);
  return (
    <div className="flex flex-col gap-3">
      {animationKey && (
        <p className="rounded-md border border-dashed border-border bg-surface-alt px-3 py-2 text-xs italic text-ink-muted">
          Hoạt họa Flutter: <code className="font-mono">{animationKey}</code> — mở
          trên ứng dụng để chạy tương tác (bản web chỉ xem trước nội dung đọc).
        </p>
      )}
      {paragraphs.length > 0 ? (
        paragraphs.map((p, i) => (
          <p key={i} className="whitespace-pre-line text-sm leading-relaxed text-ink">
            {p}
          </p>
        ))
      ) : (
        <p className="text-sm italic text-ink-muted">Chưa có nội dung đọc.</p>
      )}
    </div>
  );
}

/** VIEW_IMAGE — image via authenticated blob fetch + caption. */
export function ViewImageActivityView({ activity }: PreviewActivityProps) {
  const assetId =
    typeof activity.config?.imageAssetId === "string" ? activity.config.imageAssetId : null;
  const caption =
    typeof activity.config?.caption === "string" ? activity.config.caption : null;
  const assetQuery = useQuery({
    queryKey: qk.assets.detail(assetId ?? "none"),
    queryFn: () => apiFetch<AdminAsset>(`/admin/assets/${assetId}`),
    enabled: Boolean(assetId),
  });

  return (
    <div className="flex flex-col gap-2">
      {assetId ? (
        assetQuery.data ? (
          <AssetImage
            asset={assetQuery.data}
            className="w-full rounded-md border border-border object-cover"
          />
        ) : assetQuery.isError ? (
          <p className="rounded bg-error/10 px-3 py-2 text-xs text-error">
            Không tải được ảnh minh họa.
          </p>
        ) : (
          <div className="h-40 animate-pulse rounded-md bg-surface-alt" />
        )
      ) : (
        <p className="text-sm italic text-ink-muted">Chưa chọn hình ảnh.</p>
      )}
      {caption && <p className="text-xs italic text-ink-muted">{caption}</p>}
    </div>
  );
}

/** REFLECTION_PROMPT — prompt + free-text box (demo input, never submitted). */
export function ReflectionPromptActivityView({ activity }: PreviewActivityProps) {
  const [value, setValue] = useState("");
  const prompt =
    typeof activity.config?.prompt === "string" ? activity.config.prompt : "";
  return (
    <div className="flex flex-col gap-2">
      <p className="text-sm text-ink">{prompt || "Chưa có câu hỏi suy ngẫm."}</p>
      <Textarea
        rows={4}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Học viên viết suy nghĩ tại đây…"
        aria-label="Câu trả lời suy ngẫm (xem trước)"
      />
      <p className="text-[11px] text-ink-muted">Chế độ xem trước — câu trả lời không được lưu.</p>
    </div>
  );
}
