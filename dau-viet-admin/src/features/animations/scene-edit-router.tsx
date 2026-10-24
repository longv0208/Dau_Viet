"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";

import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";
import { ApiClientError } from "@/lib/api-error";

import { animationApi } from "./animation-api";
import { HtmlSceneEditor } from "./html-scene-editor";

/** Đọc rendererCode từ draftJson (không cần full manifest hợp lệ). */
function parseDraftRenderer(draftJson: string): string | null {
  try {
    const parsed = JSON.parse(draftJson) as { rendererCode?: string };
    return parsed?.rendererCode ?? null;
  } catch {
    return null;
  }
}

/**
 * Edit-page router: HTML_WEBVIEW → HtmlSceneEditor; scene legacy
 * (RIVER_TIDE/JOURNEY_MAP) → read-only notice — trình soạn cũ đã ngừng
 * hỗ trợ. Không render form authoring cũ, không đụng dữ liệu/phiên bản.
 */
export function SceneEditRouter({ sceneId }: { sceneId: string }) {
  const query = useQuery({
    queryKey: ["animation-scene-edit-router", sceneId],
    queryFn: () => animationApi.getScene(sceneId),
    retry: false,
  });

  if (query.isPending) {
    return <p className="text-sm text-ink-muted">Đang tải cảnh…</p>;
  }
  if (query.error || !query.data) {
    return (
      <p role="alert" className="text-sm text-error">
        {query.error instanceof ApiClientError
          ? query.error.message
          : "Không tải được cảnh."}{" "}
        <Link href="/animations" className="underline">
          Quay lại thư viện
        </Link>
      </p>
    );
  }

  const scene = query.data;
  if (parseDraftRenderer(scene.draftJson) === "HTML_WEBVIEW") {
    return <HtmlSceneEditor sceneId={sceneId} />;
  }

  // Legacy scene — trình soạn cũ (camera/keyframe/river/map) đã ngừng.
  // Chỉ hiển thị metadata read-only + đường về thư viện; dữ liệu và các
  // phiên bản đã publish giữ nguyên cho runtime/lesson cũ tham chiếu.
  return (
    <div className="flex max-w-xl flex-col gap-4">
      <div className="flex items-center gap-3">
        <h1 className="text-base font-semibold text-ink">{scene.title}</h1>
        <StatusChip status={scene.status} />
      </div>
      <div className="rounded-lg border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900">
        <p className="font-medium">Trình soạn cảnh kiểu cũ đã ngừng hỗ trợ.</p>
        <p className="mt-1 text-xs">
          Cảnh này dùng renderer{" "}
          <code className="font-mono">
            {parseDraftRenderer(scene.draftJson) ?? "?"}
          </code>{" "}
          — không còn mở được bằng giao diện camera/keyframe cũ. Nội dung và
          các phiên bản đã xuất bản vẫn được giữ nguyên; các bài học đang dùng
          phiên bản đó vẫn chạy bình thường. Để có hoạt họa mới, tải file HTML
          lên từ thư viện.
        </p>
        {scene.currentVersionNo != null && (
          <p className="mt-2 text-xs">
            Phiên bản đang phát hành:{" "}
            <Link
              href={`/animations/${scene.id}/versions`}
              className="font-medium underline"
            >
              v{scene.currentVersionNo}
            </Link>
          </p>
        )}
      </div>
      <div>
        <Button variant="outline" size="sm" asChild>
          <Link href="/animations">Quay lại thư viện</Link>
        </Button>
      </div>
    </div>
  );
}
