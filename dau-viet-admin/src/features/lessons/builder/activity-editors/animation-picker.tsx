"use client";

import { useQuery } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { qk } from "@/lib/query-keys";

import { animationApi } from "@/features/animations/animation-api";
import { PLAYBACK_MODES, type AnimationSceneSummary } from "@/features/animations/animation-types";

const PAGE_SIZE = 50;

const PLAYBACK_LABELS: Record<string, string> = {
  AUTO: "Tự chạy (AUTO)",
  STEPPED: "Theo bước — học viên bấm tiếp (STEPPED)",
  INTERACTIVE: "Tương tác (INTERACTIVE)",
};

/**
 * Chọn cảnh hoạt họa data-driven cho activity READ:
 * ghi config.animationSceneId + animationSceneVersionId + playbackMode.
 * Không chọn → xóa cả ba key. Legacy animationKey giữ nguyên ở field riêng
 * (backend bắt buộc loại trừ lẫn nhau — chọn scene rồi phải bỏ legacy key).
 */
export function AnimationPicker({
  config,
  readOnly,
  onConfigChange,
}: {
  config: Record<string, unknown>;
  readOnly?: boolean;
  onConfigChange: (patch: Record<string, unknown>) => void;
}) {
  const sceneId = (config.animationSceneId as string) ?? "";
  const playbackMode = (config.playbackMode as string) ?? "AUTO";
  const [showLegacy, setShowLegacy] = useState(
    typeof config.animationKey === "string" && config.animationKey !== "",
  );
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");

  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => clearTimeout(t);
  }, [search]);

  const listParams = useMemo(
    () => ({ status: "PUBLISHED", size: PAGE_SIZE, q: debouncedSearch || undefined }),
    [debouncedSearch],
  );
  const scenes = useQuery({
    queryKey: qk.animationScenes.list(listParams),
    queryFn: () => animationApi.listScenes(listParams),
  });

  // Scene đang chọn có thể nằm ngoài trang kết quả — tải riêng theo id để
  // dropdown luôn hiển thị được lựa chọn hiện tại.
  const selectedDetail = useQuery({
    queryKey: qk.animationScenes.detail(sceneId),
    queryFn: () => animationApi.getScene(sceneId),
    enabled: Boolean(sceneId) && !scenes.isError,
    retry: false,
  });

  // Chỉ scene đã có phiên bản phát hành mới ghim được vào bài học.
  const published = useMemo(() => {
    const rows = (scenes.data?.content ?? []).filter((s) => s.currentVersionId);
    const detail = selectedDetail.data;
    if (detail && detail.currentVersionId && !rows.some((s) => s.id === detail.id)) {
      const summary: AnimationSceneSummary = {
        id: detail.id,
        templateId: detail.templateId,
        eventId: detail.eventId,
        title: detail.title,
        status: detail.status,
        currentVersionId: detail.currentVersionId,
        currentVersionNo: detail.currentVersionNo,
        rowVersion: detail.rowVersion,
        updatedAt: detail.updatedAt,
      };
      rows.unshift(summary);
    }
    return rows;
  }, [scenes.data, selectedDetail.data]);

  const selected = published.find((s) => s.id === sceneId);

  const setScene = (id: string) => {
    const next = { ...config };
    if (!id) {
      delete next.animationSceneId;
      delete next.animationSceneVersionId;
      delete next.playbackMode;
    } else {
      const sc = published.find((s) => s.id === id);
      next.animationSceneId = id;
      next.animationSceneVersionId = sc?.currentVersionId ?? "";
      next.playbackMode = playbackMode;
      // Loại trừ lẫn nhau với legacy animationKey.
      delete next.animationKey;
    }
    onConfigChange(next);
  };

  return (
    <div className="flex flex-col gap-2 rounded-md border border-brand/30 bg-brand/5 p-3">
      <Label htmlFor="anim-scene">Cảnh hoạt họa (data-driven)</Label>
      <Input
        id="anim-scene-search"
        value={search}
        disabled={readOnly}
        placeholder="Tìm cảnh theo tiêu đề…"
        onChange={(e) => setSearch(e.target.value)}
      />
      <Select
        id="anim-scene"
        value={sceneId}
        disabled={readOnly || scenes.isPending}
        onChange={(e) => setScene(e.target.value)}
      >
        <option value="">— Không dùng cảnh hoạt họa —</option>
        {published.map((s) => (
          <option key={s.id} value={s.id}>
            {s.title} (v{s.currentVersionNo})
          </option>
        ))}
      </Select>
      {scenes.isPending && <p className="text-xs text-ink-muted">Đang tải danh sách cảnh…</p>}
      {scenes.isError && (
        <div className="flex items-center gap-2 text-xs text-red-700">
          <span>Không tải được danh sách cảnh{scenes.error instanceof Error ? `: ${scenes.error.message}` : "."}</span>
          <button
            type="button"
            className="underline"
            onClick={() => scenes.refetch()}
          >
            Thử lại
          </button>
        </div>
      )}
      {selectedDetail.isError && Boolean(sceneId) && (
        <div className="flex items-center gap-2 text-xs text-red-700">
          <span>Không tải được cảnh đang chọn.</span>
          <button type="button" className="underline" onClick={() => selectedDetail.refetch()}>
            Thử lại
          </button>
        </div>
      )}
      {published.length === 0 && !scenes.isPending && !scenes.isError && (
        <p className="text-xs text-ink-muted">
          {debouncedSearch
            ? `Không có cảnh đã xuất bản nào khớp “${debouncedSearch}”.`
            : "Chưa có cảnh nào đã xuất bản — tạo và xuất bản cảnh ở mục “Hoạt họa lịch sử”."}
        </p>
      )}

      {selected && (
        <>
          <p className="text-xs text-ink-muted">
            Ghim phiên bản hiện hành <code>v{selected.currentVersionNo}</code> — bài học luôn
            phát đúng snapshot này kể cả khi cảnh được xuất bản phiên bản mới hơn.
          </p>
          <div className="w-64">
            <Label htmlFor="anim-playback" className="text-xs">Chế độ phát</Label>
            <Select
              id="anim-playback"
              value={playbackMode}
              disabled={readOnly}
              onChange={(e) => onConfigChange({ ...config, playbackMode: e.target.value })}
            >
              {PLAYBACK_MODES.map((m) => (
                <option key={m} value={m}>{PLAYBACK_LABELS[m] ?? m}</option>
              ))}
            </Select>
          </div>
        </>
      )}

      {/* Legacy animationKey — chỉ mở khi cần tương thích scene cũ hard-code */}
      {!sceneId && (
        <div className="mt-1">
          <button
            type="button"
            className="text-xs text-ink-muted underline"
            onClick={() => setShowLegacy((s) => !s)}
          >
            {showLegacy ? "Ẩn mã hoạt họa cũ (animationKey)" : "Dùng mã hoạt họa cũ (animationKey)…"}
          </button>
          {showLegacy && (
            <div className="mt-2 flex flex-col gap-1.5">
              <Input
                value={(config.animationKey as string) ?? ""}
                disabled={readOnly}
                placeholder="VD: bach_dang_938_tide_v1"
                onChange={(e) => {
                  const next = { ...config };
                  if (e.target.value.trim() === "") delete next.animationKey;
                  else next.animationKey = e.target.value;
                  onConfigChange(next);
                }}
              />
              <p className="text-xs text-ink-muted">
                Đường cũ hard-code trong app — chỉ dùng khi cảnh data-driven chưa thay thế được.
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
