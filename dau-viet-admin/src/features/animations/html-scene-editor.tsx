"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { StatusChip } from "@/components/status-chip";
import { ApiClientError } from "@/lib/api-error";
import { qk } from "@/lib/query-keys";

import { animationApi } from "./animation-api";
import { HtmlImportDropzone } from "./html-import-dropzone";
import type { AnimationSceneDetail } from "./animation-types";
import { PublishSection } from "./scene-editor/publish-section";
import { Section } from "./scene-editor/editor-sections";

const VIEWPORTS = [
  { label: "Điện thoại dọc", w: 390, h: 700 },
  { label: "Máy tính bảng", w: 768, h: 900 },
  { label: "Rộng", w: 1200, h: 700 },
] as const;

/**
 * Trình soạn cảnh HTML_WEBVIEW — khác hẳn manifest editor: không có
 * assets/objects/steps/timeline. Chỉ gồm: đổi tên, thay file HTML,
 * preview trong iframe sandbox (không allow-same-origin — document chạy
 * ở opaque origin, không chạm cookie/session admin), rồi publish.
 */
export function HtmlSceneEditor({ sceneId }: { sceneId: string }) {
  const router = useRouter();
  const qc = useQueryClient();
  const [scene, setScene] = useState<AnimationSceneDetail | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [title, setTitle] = useState("");
  const [viewport, setViewport] = useState(0);
  const [blobUrl, setBlobUrl] = useState<string | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [previewKey, setPreviewKey] = useState(0);
  const objectUrlRef = useRef<string | null>(null);

  const loadPreview = async (id: string) => {
    try {
      const blob = await animationApi.fetchHtmlDraft(id);
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current);
      const url = URL.createObjectURL(blob);
      objectUrlRef.current = url;
      setBlobUrl(url);
      setPreviewError(null);
      setPreviewKey((k) => k + 1);
    } catch (e) {
      setPreviewError(
        e instanceof ApiClientError ? e.message : "Không tải được bản nháp HTML.",
      );
    }
  };

  // FIX-05: sau publish/archive refetch scene để status/rowVersion/
  // currentVersionNo trên UI khớp server — tránh lần publish/replace kế
  // tiếp gửi expectedRowVersion cũ (409 giả).
  const refreshScene = async () => {
    try {
      const fresh = await animationApi.getScene(sceneId);
      setScene(fresh);
      qc.setQueryData(qk.animationScenes.detail(sceneId), fresh);
    } catch {
      // best-effort; publish success banner vẫn đúng
    }
  };

  useEffect(() => {
    let alive = true;
    animationApi
      .getScene(sceneId)
      .then((s) => {
        if (!alive) return;
        setScene(s);
        setTitle(s.title);
        loadPreview(s.id);
      })
      .catch((e) => {
        if (alive)
          setLoadError(
            e instanceof ApiClientError ? e.message : "Không tải được cảnh.",
          );
      });
    return () => {
      alive = false;
      if (objectUrlRef.current) {
        URL.revokeObjectURL(objectUrlRef.current);
        objectUrlRef.current = null;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sceneId]);

  const saveTitle = useMutation({
    mutationFn: () =>
      animationApi.updateScene(sceneId, {
        title: title.trim() || undefined,
        expectedRowVersion: scene?.rowVersion,
      }),
    onSuccess: (fresh) => {
      setScene(fresh);
      qc.setQueryData(qk.animationScenes.detail(sceneId), fresh);
    },
  });

  const replace = useMutation({
    mutationFn: (file: File) =>
      animationApi.replaceHtmlScene(sceneId, file, scene?.rowVersion),
    onSuccess: async (fresh) => {
      setScene(fresh);
      qc.setQueryData(qk.animationScenes.detail(sceneId), fresh);
      await loadPreview(fresh.id);
    },
  });

  if (loadError) {
    return (
      <p role="alert" className="text-sm text-error">
        {loadError}
      </p>
    );
  }
  if (!scene) {
    return <p className="text-sm text-ink-muted">Đang tải cảnh…</p>;
  }
  const readOnly = scene.status === "ARCHIVED";

  return (
    <div className="flex flex-col gap-4">
      <div className="sticky top-0 z-10 flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border bg-white px-4 py-3 shadow-sm">
        <div className="flex items-center gap-3">
          <div>
            <h1 className="text-base font-semibold text-ink">{scene.title}</h1>
            <p className="text-xs text-ink-muted">
              <code>HTML_WEBVIEW</code>
              {scene.currentVersionNo != null &&
                ` · đang phát hành v${scene.currentVersionNo}`}
            </p>
          </div>
          <StatusChip status={scene.status} />
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => router.push(`/animations/${sceneId}/versions`)}
        >
          Phiên bản
        </Button>
      </div>

      {readOnly && (
        <p className="rounded-md border border-border bg-surface-alt px-4 py-2 text-xs text-ink-muted">
          Cảnh đã lưu trữ — chỉ xem. Nhân bản cảnh từ thư viện để chỉnh sửa tiếp.
        </p>
      )}

      <div className="grid gap-4 lg:grid-cols-[1fr_460px]">
        <div className="flex min-w-0 flex-col gap-4">
          <Section title="Thông tin chung">
            <div className="flex flex-col gap-3">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="html-scene-title">Tên cảnh</Label>
                <div className="flex gap-2">
                  <Input
                    id="html-scene-title"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    disabled={readOnly}
                  />
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={readOnly || saveTitle.isPending || !title.trim()}
                    onClick={() => saveTitle.mutate()}
                  >
                    {saveTitle.isPending ? "Đang lưu…" : "Lưu tên"}
                  </Button>
                </div>
              </div>
              {saveTitle.isSuccess && (
                <p className="text-xs text-emerald-700">Đã lưu tên cảnh.</p>
              )}
              {saveTitle.error && (
                <p role="alert" className="text-xs text-error">
                  {saveTitle.error instanceof ApiClientError &&
                  saveTitle.error.status === 409
                    ? "Cảnh đã bị sửa đồng thời — tải lại trang."
                    : saveTitle.error.message}
                </p>
              )}
            </div>
          </Section>

          <Section title="Tệp HTML">
            <div className="flex flex-col gap-3">
              <p className="text-xs text-ink-muted">
                Thay file = cập nhật bản nháp. Phiên bản đã xuất bản giữ
                nguyên file cũ — muốn phát hành file mới hãy bấm "Xuất bản
                phiên bản mới" bên dưới.
              </p>
              {!readOnly && (
                <HtmlImportDropzone
                  disabled={replace.isPending}
                  onFile={(f) => replace.mutate(f)}
                />
              )}
              {replace.isPending && (
                <p className="text-xs text-ink-muted">Đang tải file lên…</p>
              )}
              {replace.error instanceof ApiClientError && (
                <div role="alert" className="text-xs text-error">
                  <p>{replace.error.message}</p>
                  {Array.isArray(
                    (replace.error.details as { errors?: { message: string }[] })
                      .errors,
                  ) && (
                    <ul className="mt-1 list-disc pl-4">
                      {(
                        replace.error.details as {
                          errors: { message: string }[];
                        }
                      ).errors.map((e, i) => (
                        <li key={i}>{e.message}</li>
                      ))}
                    </ul>
                  )}
                </div>
              )}
            </div>
          </Section>

          <PublishSection
            scene={scene}
            onSaved={() => {
              qc.invalidateQueries({ queryKey: ["animation-scenes"] });
              void refreshScene();
            }}
          />
        </div>

        {/* Preview — iframe sandbox KHÔNG allow-same-origin: script chạy được
            nhưng document ở opaque origin, không đọc cookie/token, không
            mở popup/form/download. Nguồn là blob: URL từ fetch có Bearer. */}
        <div className="lg:sticky lg:top-20 lg:self-start">
          <Section title="Xem trước (sandbox)">
            <div className="flex flex-col gap-2">
              <div className="flex flex-wrap items-center gap-2">
                {VIEWPORTS.map((v, i) => (
                  <Button
                    key={v.label}
                    variant={viewport === i ? "secondary" : "outline"}
                    size="sm"
                    onClick={() => setViewport(i)}
                  >
                    {v.label}
                  </Button>
                ))}
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => loadPreview(sceneId)}
                >
                  Tải lại
                </Button>
              </div>
              {previewError && (
                <p role="alert" className="text-xs text-error">
                  {previewError}
                </p>
              )}
              <div className="overflow-auto rounded-lg border border-border bg-surface-alt p-2">
                {blobUrl ? (
                  <iframe
                    key={previewKey}
                    title="Xem trước hoạt họa HTML"
                    src={blobUrl}
                    sandbox="allow-scripts"
                    style={{
                      width: VIEWPORTS[viewport]?.w ?? 390,
                      height: VIEWPORTS[viewport]?.h ?? 700,
                      maxWidth: "100%",
                      border: "none",
                      background: "#fff",
                    }}
                  />
                ) : (
                  <p className="text-xs text-ink-muted">Đang tải bản nháp…</p>
                )}
              </div>
              <p className="text-[11px] text-ink-muted">
                Preview chạy trong iframe cách ly — script của hoạt họa không
                truy cập được phiên quản trị hay dữ liệu CMS.
              </p>
            </div>
          </Section>
        </div>
      </div>
    </div>
  );
}
