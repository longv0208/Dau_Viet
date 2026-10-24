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
  // FIX-04: trạng thái loading riêng — giữa replace và fetch xong,
  // iframe cũ bị gỡ (blobUrl=null), hiển thị "Đang tải" thay vì file cũ.
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [previewKey, setPreviewKey] = useState(0);
  const objectUrlRef = useRef<string | null>(null);
  // FIX-04: monotonic request seq — replace/unmount/scene-switch làm
  // mọi fetch trước đó trở thành stale; blob của request cũ bị revoke
  // ngay khi resolve (không hiển thị file cũ, không leak object URL).
  const previewSeq = useRef(0);

  // FIX-04: gỡ blob cũ TRƯỚC khi fetch — giữa lúc thay file và load xong
  // không được hiển thị iframe cũ như thể đó là file hiện tại. Request
  // hoàn thành sai thứ tự (stale) bị revoke ngay, không ghi đè state mới.
  const loadPreview = async (id: string) => {
    const seq = ++previewSeq.current;
    setPreviewLoading(true);
    try {
      const blob = await animationApi.fetchHtmlDraft(id);
      const url = URL.createObjectURL(blob);
      if (seq !== previewSeq.current) {
        URL.revokeObjectURL(url);
        return;
      }
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = url;
      setBlobUrl(url);
      setPreviewError(null);
      setPreviewKey((k) => k + 1);
    } catch (e) {
      if (seq !== previewSeq.current) return;
      // Fetch lỗi → không giữ iframe cũ: blobUrl vẫn null (đã clear trước).
      setPreviewError(
        e instanceof ApiClientError ? e.message : "Không tải được bản nháp HTML.",
      );
    } finally {
      if (seq === previewSeq.current) setPreviewLoading(false);
    }
  };

  // FIX-05: sau publish/archive refetch scene để status/rowVersion/
  // currentVersionNo trên UI khớp server — tránh lần publish/replace kế
  // tiếp gửi expectedRowVersion cũ (409 giả).
  // FIX-03+05: sau publish/archive refetch scene để status/rowVersion/
  // currentVersionNo trên UI khớp server — tránh lần publish/replace kế
  // tiếp gửi expectedRowVersion cũ (409 giả) và cập nhật file metadata.
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
        // FIX-04: gỡ blob cũ trước khi fetch — màn hình không flash file
        // của scene trước đó.
        if (objectUrlRef.current) {
          URL.revokeObjectURL(objectUrlRef.current);
          objectUrlRef.current = null;
        }
        setBlobUrl(null);
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
      // invalidate pending preview fetch khi unmount/đổi scene (seq++).
      previewSeq.current = previewSeq.current + 1;
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
      // FIX-04: blob cũ stale ngay — gỡ trước khi fetch file mới để
      // iframe cũ không hiển thị như "file hiện tại" trong lúc chờ.
      if (objectUrlRef.current) {
        URL.revokeObjectURL(objectUrlRef.current);
        objectUrlRef.current = null;
      }
      setBlobUrl(null);
      setPreviewError(null);
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

  // FIX-05: metadata file lấy từ draftJson phía server (server-managed,
  // không phải File object cũ của input). sha256/sizeBytes backend tự
  // recompute — không hiển thị như trường editable.
  const htmlMeta = (() => {
    try {
      const m = JSON.parse(scene.draftJson) as {
        html?: { filename?: string; sizeBytes: number; sha256: string };
      };
      return m.html ?? null;
    } catch {
      return null;
    }
  })();

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
              {/* FIX-05: file info read-only từ server draft metadata. */}
              {htmlMeta && (
                <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 rounded-md border border-border bg-surface-alt px-3 py-2 text-xs">
                  {htmlMeta.filename && (
                    <>
                      <dt className="text-ink-muted">Tên tệp</dt>
                      <dd className="font-mono text-ink">{htmlMeta.filename}</dd>
                    </>
                  )}
                  <dt className="text-ink-muted">Kích thước</dt>
                  <dd className="font-mono text-ink">
                    {(htmlMeta.sizeBytes / 1024).toFixed(1)} KB
                  </dd>
                  {scene.currentVersionNo != null && (
                    <>
                      <dt className="text-ink-muted">Đang xuất bản</dt>
                      <dd className="text-ink">v{scene.currentVersionNo}</dd>
                    </>
                  )}
                  <dt className="text-ink-muted">Bản nháp</dt>
                  <dd className="text-ink">
                    <StatusChip status={scene.status} />
                  </dd>
                </dl>
              )}
              <p className="text-xs text-ink-muted">
                Thay file = cập nhật bản nháp. Phiên bản đã xuất bản giữ
                nguyên file cũ — muốn phát hành file mới hãy bấm &quot;Xuất bản
                phiên bản mới&quot; bên dưới.
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
            onArchived={() => {
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
                  disabled={previewLoading}
                  onClick={() => {
                    // FIX-04: Retry thủ công — gỡ blob cũ + lỗi trước khi
                    // fetch lại, không flash file cũ.
                    if (objectUrlRef.current) {
                      URL.revokeObjectURL(objectUrlRef.current);
                      objectUrlRef.current = null;
                    }
                    setBlobUrl(null);
                    setPreviewError(null);
                    void loadPreview(sceneId);
                  }}
                >
                  {previewLoading ? "Đang tải…" : "Tải lại"}
                </Button>
              </div>
              {previewError && (
                <p role="alert" className="text-xs text-error">
                  {previewError} — bấm &quot;Tải lại&quot; để thử lại.
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
                ) : previewLoading ? (
                  <p className="text-xs text-ink-muted">Đang tải bản nháp…</p>
                ) : previewError ? (
                  <p className="text-xs text-ink-muted">
                    Không tải được bản nháp — xem lỗi phía trên.
                  </p>
                ) : (
                  <p className="text-xs text-ink-muted">Chưa có bản xem trước.</p>
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
