"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { StatusChip } from "@/components/status-chip";

import { useSceneEditor } from "./use-scene-editor";
import {
  AssetsSection,
  CanvasSection,
  GeneralSection,
  InteractionsSection,
  ObjectsSection,
  Section,
  SourcesSection,
} from "./scene-editor/editor-sections";
import {
  AudioSection,
  CameraSection,
  EffectsSection,
  EnvironmentSection,
  TracksSection,
} from "./scene-editor/cinematic-sections";
import { TimelineSection } from "./scene-editor/timeline-section";
import { JourneyMapEditor, MapStateFields, RiverStakesEditor, RiverStateFields } from "./scene-editor/renderer-editors";
import { PublishSection } from "./scene-editor/publish-section";
import { ScenePreview } from "./scene-editor/scene-preview";
import { HtmlSceneEditor } from "./html-scene-editor";

/**
 * Screen C — Scene Editor: bố cục 2 cột (form trái, preview phải sticky),
 * 8 section gấp gọn + thanh lưu. Lưu tay qua PATCH kèm expectedRowVersion;
 * 409 báo tải lại. ARCHIVED → toàn bộ readOnly.
 */
/** Đọc rendererCode từ draftJson (không cần full manifest hợp lệ). */
function parseDraftRenderer(scene: { draftJson: string }): string | null {
  try {
    const parsed = JSON.parse(scene.draftJson) as { rendererCode?: string };
    return parsed?.rendererCode ?? null;
  } catch {
    return null;
  }
}

export function SceneEditor({ sceneId }: { sceneId: string }) {
  const router = useRouter();
  const ed = useSceneEditor(sceneId);

  // Cảnh báo rời trang khi còn thay đổi chưa lưu.
  useEffect(() => {
    if (!ed.dirty) return;
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  }, [ed.dirty]);

  if (ed.loading) return <p className="text-sm text-ink-muted">Đang tải cảnh…</p>;
  // HTML_WEBVIEW: giao diện riêng — file tự chứa, không có sections manifest.
  if (ed.scene && parseDraftRenderer(ed.scene) === "HTML_WEBVIEW") {
    return <HtmlSceneEditor sceneId={sceneId} />;
  }
  if (ed.error || !ed.scene) {
    return (
      <p role="alert" className="text-sm text-error">
        Không tải được cảnh.{" "}
        <Link href="/animations" className="underline">
          Quay lại thư viện
        </Link>
      </p>
    );
  }
  if (!ed.manifest) {
    return (
      <p role="alert" className="text-sm text-error">
        Bản nháp của cảnh bị hỏng (không phải JSON manifest hợp lệ).
      </p>
    );
  }

  const m = ed.manifest;
  const isRiver = m.rendererCode === "RIVER_TIDE";

  return (
    <div className="flex flex-col gap-4">
      {/* Thanh tiêu đề + lưu */}
      <div className="sticky top-0 z-10 flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border bg-white px-4 py-3 shadow-sm">
        <div className="flex items-center gap-3">
          <div>
            <h1 className="text-base font-semibold text-ink">{ed.scene.title}</h1>
            <p className="text-xs text-ink-muted">
              <code>{m.rendererCode} v{m.rendererVersion}</code>
              {ed.scene.currentVersionNo != null && ` · đang phát hành v${ed.scene.currentVersionNo}`}
            </p>
          </div>
          <StatusChip status={ed.scene.status} />
          {ed.dirty && <span className="text-xs text-amber-700">• Chưa lưu</span>}
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => router.push(`/animations/${sceneId}/versions`)}>
            Phiên bản
          </Button>
          <Button
            size="sm"
            disabled={!ed.dirty || ed.save.isPending || ed.readOnly}
            onClick={() => ed.save.mutate()}
          >
            {ed.save.isPending ? "Đang lưu…" : "Lưu nháp"}
          </Button>
        </div>
      </div>

      {ed.conflict && (
        <p role="alert" className="rounded-md border border-error/40 bg-error/5 px-4 py-3 text-sm text-error">
          Đã có thay đổi khác trên máy chủ —{" "}
          <button type="button" className="underline" onClick={() => ed.refetch()}>
            tải lại trang
          </button>{" "}
          để xem bản mới nhất (thay đổi của bạn chưa lưu sẽ mất).
        </p>
      )}
      {ed.save.isSuccess && !ed.dirty && (
        <p className="rounded-md border border-emerald-300 bg-emerald-50 px-4 py-2 text-xs text-emerald-800">
          Đã lưu nháp.
        </p>
      )}
      {ed.readOnly && (
        <p className="rounded-md border border-border bg-surface-alt px-4 py-2 text-xs text-ink-muted">
          Cảnh đã lưu trữ — chỉ xem. Nhân bản cảnh từ thư viện để chỉnh sửa tiếp.
        </p>
      )}

      <div className="grid gap-4 lg:grid-cols-[1fr_420px]">
        {/* Cột form — 8 section */}
        <div className="flex min-w-0 flex-col gap-4">
          <GeneralSection
            manifest={m}
            eventId={ed.eventId}
            readOnly={ed.readOnly}
            onChange={ed.setManifest}
            onEventChange={ed.setEventId}
          />
          <CanvasSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          <AssetsSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          <ObjectsSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />

          {/* Section theo renderer */}
          {isRiver ? (
            <Section title="Bãi cọc & sông" defaultOpen={false}>
              <RiverStakesEditor manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
            </Section>
          ) : (
            <Section title="Bản đồ & địa điểm" defaultOpen={false}>
              <JourneyMapEditor manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
            </Section>
          )}

          <TimelineSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          <InteractionsSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />

          {/* v2 cinematic — camera/tracks/effects/audio/environment.
              Các section tự bump schemaVersion khi thêm key đầu tiên. */}
          <CameraSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          <TracksSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          <EffectsSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          <AudioSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          {isRiver && (
            <EnvironmentSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          )}

          {/* Trạng thái ban đầu — cùng state-map của renderer */}
          <Section title="Trạng thái ban đầu" defaultOpen={false}>
            {isRiver ? (
              <RiverStateFields
                state={m.initialState ?? {}}
                readOnly={ed.readOnly}
                onChange={(next) => ed.setManifest({ initialState: next })}
              />
            ) : (
              <MapStateFields
                state={m.initialState ?? {}}
                locations={m.map?.locations ?? []}
                routes={m.map?.routes ?? []}
                readOnly={ed.readOnly}
                onChange={(next) => ed.setManifest({ initialState: next })}
              />
            )}
          </Section>

          <SourcesSection manifest={m} readOnly={ed.readOnly} onChange={ed.setManifest} />
          <PublishSection scene={ed.scene} onSaved={() => ed.refetch()} />
        </div>

        {/* Cột preview sticky — render manifest đang soạn (bản nháp chưa lưu),
            KHÔNG phải phiên bản đã publish. */}
        <div className="lg:sticky lg:top-20 lg:self-start">
          <Section title="Xem trước tương tác">
            <p className="mb-2 text-[11px] text-ink-muted">
              Xem trước phản ánh nội dung đang soạn{ed.dirty ? " (chưa lưu)" : " (bản nháp đã lưu)"}
              {ed.scene.currentVersionNo != null &&
                ` — phiên bản đã phát hành v${ed.scene.currentVersionNo} không đổi.`}
            </p>
            <ScenePreview manifest={m} />
          </Section>
        </div>
      </div>
    </div>
  );
}
