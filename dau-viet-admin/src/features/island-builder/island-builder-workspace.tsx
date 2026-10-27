"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import {
  AlertTriangle,
  ArrowDown,
  ArrowLeft,
  ArrowUp,
  CheckCircle2,
  Copy,
  Eye,
  Grid,
  Image as ImageIcon,
  Layers,
  Lock,
  MapPin,
  Maximize2,
  PanelLeftClose,
  PanelLeftOpen,
  PanelRightClose,
  PanelRightOpen,
  Plus,
  RotateCcw,
  Save,
  ShieldCheck,
  Sparkles,
  Trash2,
  Undo2,
  ZoomIn,
  ZoomOut,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import { cn } from "@/lib/utils";

import {
  islandBuilderApi,
  parseRegionBounds,
  parseVisibilityRule,
  serializeRegionBounds,
  serializeVisibilityRule,
  type RegionDto,
  type SceneLayerDto,
  type SlotDto,
  type ValidationErrorDto,
  type VersionDetailDto,
} from "./island-builder-api";

type SelectedObject =
  | { type: "SLOT"; key: string }
  | { type: "REGION"; key: string }
  | { type: "SCENE_LAYER"; key: string }
  | null;

interface DraftSnapshotState {
  canvasWidth: number;
  canvasHeight: number;
  themeKey: string;
  regions: RegionDto[];
  sceneLayers: SceneLayerDto[];
  slots: SlotDto[];
}

type DragState =
  | {
      kind: "PAN";
      startClientX: number;
      startClientY: number;
      origPanX: number;
      origPanY: number;
    }
  | {
      kind: "SLOT";
      slotKey: string;
      startClientX: number;
      startClientY: number;
      origX: number;
      origY: number;
    }
  | {
      kind: "REGION_MOVE";
      regionCode: string;
      startClientX: number;
      startClientY: number;
      origX: number;
      origY: number;
      width: number;
      height: number;
    }
  | {
      kind: "REGION_RESIZE";
      regionCode: string;
      startClientX: number;
      startClientY: number;
      origX: number;
      origY: number;
      origW: number;
      origH: number;
    };

const TIER_COLORS: Record<
  number,
  { border: string; bg: string; badge: string; text: string }
> = {
  1: {
    border: "border-emerald-500",
    bg: "bg-emerald-500/15",
    badge: "bg-emerald-600 text-white",
    text: "text-emerald-800",
  },
  2: {
    border: "border-amber-500",
    bg: "bg-amber-500/15",
    badge: "bg-amber-600 text-white",
    text: "text-amber-800",
  },
  3: {
    border: "border-purple-500",
    bg: "bg-purple-500/15",
    badge: "bg-purple-600 text-white",
    text: "text-purple-800",
  },
};

export function IslandBuilderWorkspace({ versionId }: { versionId: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const qc = useQueryClient();

  const initialPreview = searchParams?.get("mode") === "preview";

  const [snapshot, setSnapshot] = useState<DraftSnapshotState | null>(null);
  const [rowVersion, setRowVersion] = useState<number>(0);
  const [undoStack, setUndoStack] = useState<DraftSnapshotState[]>([]);
  const [isDirty, setIsDirty] = useState(false);

  const [selected, setSelected] = useState<SelectedObject>(null);
  const [leftCollapsed, setLeftCollapsed] = useState(false);
  const [rightCollapsed, setRightCollapsed] = useState(false);

  // Canvas controls
  const [zoom, setZoom] = useState(0.78);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [showGrid, setShowGrid] = useState(true);
  const [showRegionsOverlay, setShowRegionsOverlay] = useState(true);
  const [previewTier, setPreviewTier] = useState<number | null>(
    initialPreview ? 1 : null,
  );

  // Validation & Modals
  const [validationErrors, setValidationErrors] = useState<
    ValidationErrorDto[]
  >([]);
  const [validationPassed, setValidationPassed] = useState<boolean | null>(
    null,
  );
  const [bannerMessage, setBannerMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);
  const [showPublishModal, setShowPublishModal] = useState(false);

  const canvasRef = useRef<HTMLDivElement | null>(null);
  const [dragState, setDragState] = useState<DragState | null>(null);

  const versionQuery = useQuery({
    queryKey: ["admin-island-version", versionId],
    queryFn: () => islandBuilderApi.getVersion(versionId),
  });

  const assetsQuery = useQuery({
    queryKey: ["admin-island-assets"],
    queryFn: () => islandBuilderApi.listAssets(0, 48),
    staleTime: 60_000,
  });

  useEffect(() => {
    if (versionQuery.data && !snapshot) {
      const d = versionQuery.data;
      setSnapshot({
        canvasWidth: d.canvasWidth || 960,
        canvasHeight: d.canvasHeight || 720,
        themeKey: d.themeKey || "heritage",
        regions: d.regions,
        sceneLayers: d.sceneLayers,
        slots: d.slots,
      });
      setRowVersion(d.rowVersion);
      setIsDirty(false);
      if (d.status !== "DRAFT" && previewTier === null) {
        setPreviewTier(1);
      }
    }
  }, [versionQuery.data, snapshot, previewTier]);

  const isReadOnly =
    versionQuery.data?.status !== "DRAFT" || previewTier !== null;

  function pushUndo(prev: DraftSnapshotState) {
    setUndoStack((stack) => [...stack.slice(-24), structuredClone(prev)]);
  }

  function updateSnapshot(
    updater: (prev: DraftSnapshotState) => DraftSnapshotState,
    recordUndo = true,
  ) {
    setSnapshot((prev) => {
      if (!prev) return prev;
      if (recordUndo) pushUndo(prev);
      const next = updater(prev);
      setIsDirty(true);
      setValidationPassed(null);
      return next;
    });
  }

  function handleUndo() {
    setUndoStack((stack) => {
      if (stack.length === 0) return stack;
      const previous = stack[stack.length - 1];
      setSnapshot(previous);
      setIsDirty(true);
      return stack.slice(0, -1);
    });
  }

  // Global mouse move / up for canvas dragging
  useEffect(() => {
    if (!dragState || !snapshot) return;

    function onMouseMove(e: MouseEvent) {
      if (!dragState || !snapshot) return;
      const cw = (snapshot.canvasWidth || 960) * zoom;
      const ch = (snapshot.canvasHeight || 720) * zoom;

      if (dragState.kind === "PAN") {
        const dx = e.clientX - dragState.startClientX;
        const dy = e.clientY - dragState.startClientY;
        setPan({
          x: dragState.origPanX + dx,
          y: dragState.origPanY + dy,
        });
        return;
      }

      const normDx = (e.clientX - dragState.startClientX) / cw;
      const normDy = (e.clientY - dragState.startClientY) / ch;

      if (dragState.kind === "SLOT") {
        const nx = Number(
          Math.max(0.02, Math.min(0.98, dragState.origX + normDx)).toFixed(4),
        );
        const ny = Number(
          Math.max(0.02, Math.min(0.98, dragState.origY + normDy)).toFixed(4),
        );
        setSnapshot((prev) => {
          if (!prev) return prev;
          return {
            ...prev,
            slots: prev.slots.map((s) =>
              s.stableSlotKey === dragState.slotKey
                ? { ...s, coordX: nx, coordY: ny }
                : s,
            ),
          };
        });
        setIsDirty(true);
      } else if (dragState.kind === "REGION_MOVE") {
        const nx = Number(
          Math.max(
            0,
            Math.min(1 - dragState.width, dragState.origX + normDx),
          ).toFixed(4),
        );
        const ny = Number(
          Math.max(
            0,
            Math.min(1 - dragState.height, dragState.origY + normDy),
          ).toFixed(4),
        );
        setSnapshot((prev) => {
          if (!prev) return prev;
          return {
            ...prev,
            regions: prev.regions.map((r) =>
              r.regionCode === dragState.regionCode
                ? {
                    ...r,
                    boundsJson: serializeRegionBounds({
                      x: nx,
                      y: ny,
                      width: dragState.width,
                      height: dragState.height,
                    }),
                  }
                : r,
            ),
          };
        });
        setIsDirty(true);
      } else if (dragState.kind === "REGION_RESIZE") {
        const nw = Number(
          Math.max(
            0.08,
            Math.min(1 - dragState.origX, dragState.origW + normDx),
          ).toFixed(4),
        );
        const nh = Number(
          Math.max(
            0.08,
            Math.min(1 - dragState.origY, dragState.origH + normDy),
          ).toFixed(4),
        );
        setSnapshot((prev) => {
          if (!prev) return prev;
          return {
            ...prev,
            regions: prev.regions.map((r) =>
              r.regionCode === dragState.regionCode
                ? {
                    ...r,
                    boundsJson: serializeRegionBounds({
                      x: dragState.origX,
                      y: dragState.origY,
                      width: nw,
                      height: nh,
                    }),
                  }
                : r,
            ),
          };
        });
        setIsDirty(true);
      }
    }

    function onMouseUp() {
      setDragState(null);
    }

    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onMouseUp);
    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", onMouseUp);
    };
  }, [dragState, snapshot, zoom]);

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!snapshot || !versionQuery.data) throw new Error("Chưa tải dữ liệu");
      const meta = versionQuery.data;
      if (
        snapshot.canvasWidth !== meta.canvasWidth ||
        snapshot.canvasHeight !== meta.canvasHeight ||
        snapshot.themeKey !== (meta.themeKey ?? "heritage")
      ) {
        await islandBuilderApi.updateLayout(meta.definitionId, {
          canvasWidth: snapshot.canvasWidth,
          canvasHeight: snapshot.canvasHeight,
          themeKey: snapshot.themeKey,
        });
      }
      return islandBuilderApi.saveDraftSnapshot(versionId, {
        expectedRevision: rowVersion,
        regions: snapshot.regions,
        slots: snapshot.slots,
        sceneLayers: snapshot.sceneLayers,
      });
    },
    onSuccess: (saved: VersionDetailDto) => {
      setRowVersion(saved.rowVersion);
      setSnapshot({
        canvasWidth: saved.canvasWidth,
        canvasHeight: saved.canvasHeight,
        themeKey: saved.themeKey ?? "heritage",
        regions: saved.regions,
        sceneLayers: saved.sceneLayers,
        slots: saved.slots,
      });
      setIsDirty(false);
      setBannerMessage({
        type: "success",
        text: `Đã lưu bản nháp v${saved.versionNumber} thành công.`,
      });
      qc.invalidateQueries({ queryKey: ["admin-island-version", versionId] });
      qc.invalidateQueries({ queryKey: ["admin-island-layouts"] });
    },
    onError: (err) => {
      setBannerMessage({ type: "error", text: toUserMessage(err) });
    },
  });

  const validateMutation = useMutation({
    mutationFn: async () => {
      if (isDirty && versionQuery.data?.status === "DRAFT" && snapshot) {
        const saved = await islandBuilderApi.saveDraftSnapshot(versionId, {
          expectedRevision: rowVersion,
          regions: snapshot.regions,
          slots: snapshot.slots,
          sceneLayers: snapshot.sceneLayers,
        });
        setRowVersion(saved.rowVersion);
        setIsDirty(false);
      }
      return islandBuilderApi.validateVersion(versionId);
    },
    onSuccess: (report) => {
      setValidationErrors(report.errors);
      setValidationPassed(report.valid);
      if (report.valid) {
        setBannerMessage({
          type: "success",
          text: "Kiểm tra hợp lệ: Toàn bộ vùng đất (Tier 1/2/3), 12 ô đặt vật phẩm và các lớp cảnh quan đều đạt chuẩn xuất bản!",
        });
      } else {
        setBannerMessage({
          type: "error",
          text: `Phát hiện ${report.errors.length} lỗi bố cục. Nhấn vào từng lỗi bên dưới để chuyển tới đối tượng cần sửa.`,
        });
      }
    },
    onError: (err) => {
      setBannerMessage({ type: "error", text: toUserMessage(err) });
    },
  });

  const publishMutation = useMutation({
    mutationFn: async () => {
      let currentRev = rowVersion;
      if (isDirty && snapshot) {
        const saved = await islandBuilderApi.saveDraftSnapshot(versionId, {
          expectedRevision: currentRev,
          regions: snapshot.regions,
          slots: snapshot.slots,
          sceneLayers: snapshot.sceneLayers,
        });
        currentRev = saved.rowVersion;
        setRowVersion(currentRev);
        setIsDirty(false);
      }
      return islandBuilderApi.publishVersion(versionId, currentRev);
    },
    onSuccess: (published) => {
      setShowPublishModal(false);
      setRowVersion(published.rowVersion);
      setValidationErrors([]);
      setValidationPassed(true);
      setPreviewTier(1);
      setBannerMessage({
        type: "success",
        text: `Đã xuất bản phiên bản v${published.versionNumber} thành công!`,
      });
      qc.invalidateQueries({ queryKey: ["admin-island-version", versionId] });
      qc.invalidateQueries({ queryKey: ["admin-island-layouts"] });
    },
    onError: (err) => {
      setShowPublishModal(false);
      if (err instanceof ApiClientError && Array.isArray(err.details)) {
        const structured = err.details as unknown as ValidationErrorDto[];
        setValidationErrors(structured);
        setValidationPassed(false);
      }
      setBannerMessage({ type: "error", text: toUserMessage(err) });
    },
  });

  const cloneMutation = useMutation({
    mutationFn: () => islandBuilderApi.cloneVersion(versionId),
    onSuccess: (draft) => {
      qc.invalidateQueries({ queryKey: ["admin-island-layouts"] });
      router.push(`/island-builder/${draft.id}`);
    },
    onError: (err) => {
      setBannerMessage({ type: "error", text: toUserMessage(err) });
    },
  });

  // Toolbox actions
  function handleAddRegion() {
    if (!snapshot || isReadOnly) return;
    const existingCodes = new Set(snapshot.regions.map((r) => r.regionCode));
    const nextTier = !existingCodes.has("TIER_1")
      ? 1
      : !existingCodes.has("TIER_2")
        ? 2
        : !existingCodes.has("TIER_3")
          ? 3
          : 1;
    let code = `TIER_${nextTier}`;
    let idx = snapshot.regions.length + 1;
    while (existingCodes.has(code)) {
      code = `REGION_${idx++}`;
    }
    const newRegion: RegionDto = {
      regionCode: code,
      unlockTier: nextTier,
      label: `Vùng Cấp ${nextTier}`,
      boundsJson: serializeRegionBounds({
        x: 0.1,
        y: 0.15 + ((idx - 1) % 3) * 0.2,
        width: 0.8,
        height: 0.25,
      }),
      sortOrder: snapshot.regions.length,
    };
    updateSnapshot((prev) => ({
      ...prev,
      regions: [...prev.regions, newRegion],
    }));
    setSelected({ type: "REGION", key: code });
  }

  function handleAddSlot() {
    if (!snapshot || isReadOnly) return;
    const usedIndices = new Set(snapshot.slots.map((s) => s.slotIndex));
    let nextIndex = 1;
    while (usedIndices.has(nextIndex)) nextIndex++;

    const usedKeys = new Set(snapshot.slots.map((s) => s.stableSlotKey));
    let nextKey = `SLOT_${String(nextIndex).padStart(2, "0")}`;
    let suffix = nextIndex;
    while (usedKeys.has(nextKey)) {
      suffix++;
      nextKey = `SLOT_${String(suffix).padStart(2, "0")}`;
    }

    const tierRequired = nextIndex <= 4 ? 1 : nextIndex <= 8 ? 2 : 3;
    const region =
      snapshot.regions.find((r) => r.unlockTier === tierRequired) ??
      snapshot.regions[0];
    const bounds = parseRegionBounds(region?.boundsJson ?? null);
    const cx = Number(
      Math.min(0.92, Math.max(0.08, bounds.x + bounds.width * 0.5)).toFixed(4),
    );
    const cy = Number(
      Math.min(0.92, Math.max(0.08, bounds.y + bounds.height * 0.5)).toFixed(4),
    );

    const newSlot: SlotDto = {
      slotIndex: nextIndex,
      stableSlotKey: nextKey,
      regionCode: region?.regionCode ?? `TIER_${tierRequired}`,
      tierRequired,
      coordX: cx,
      coordY: cy,
      zIndex: nextIndex * 10,
      anchorX: 0.5,
      anchorY: 1.0,
      widthNorm: 0.1,
      heightNorm: 0.12,
      allowedCategories: ["DECOR"],
    };
    updateSnapshot((prev) => ({
      ...prev,
      slots: [...prev.slots, newSlot],
    }));
    setSelected({ type: "SLOT", key: nextKey });
  }

  function handleAddLayer() {
    if (!snapshot || isReadOnly) return;
    const usedKeys = new Set(snapshot.sceneLayers.map((l) => l.layerKey));
    let idx = snapshot.sceneLayers.length + 1;
    let key = `layer_${idx}`;
    while (usedKeys.has(key)) {
      idx++;
      key = `layer_${idx}`;
    }
    const maxOrder = snapshot.sceneLayers.reduce(
      (m, l) => Math.max(m, l.renderOrder),
      0,
    );
    const newLayer: SceneLayerDto = {
      layerKey: key,
      layerType: "STATIC_IMAGE",
      renderOrder: maxOrder + 5,
      assetRef: "assets/images/dv_ISL_generic_island-base-tiers_v01.jpg",
      visibilityRuleJson: serializeVisibilityRule({ minTier: 1, maxTier: 3 }),
    };
    updateSnapshot((prev) => ({
      ...prev,
      sceneLayers: [...prev.sceneLayers, newLayer],
    }));
    setSelected({ type: "SCENE_LAYER", key });
  }

  function handleSelectValidationError(err: ValidationErrorDto) {
    if (err.objectType === "SLOT") {
      const found = snapshot?.slots.find(
        (s) =>
          s.stableSlotKey === err.objectKey ||
          `SLOT_${s.slotIndex}` === err.objectKey ||
          `slot_${s.slotIndex}` === err.objectKey,
      );
      if (found) setSelected({ type: "SLOT", key: found.stableSlotKey });
    } else if (err.objectType === "REGION") {
      setSelected({ type: "REGION", key: err.objectKey });
    } else if (err.objectType === "LAYER") {
      setSelected({ type: "SCENE_LAYER", key: err.objectKey });
    }
    setRightCollapsed(false);
  }

  const sortedLayers = useMemo(() => {
    if (!snapshot) return [];
    return [...snapshot.sceneLayers].sort(
      (a, b) => a.renderOrder - b.renderOrder,
    );
  }, [snapshot]);

  const sortedSlots = useMemo(() => {
    if (!snapshot) return [];
    return [...snapshot.slots].sort((a, b) => {
      if (a.zIndex !== b.zIndex) return a.zIndex - b.zIndex;
      return a.slotIndex - b.slotIndex;
    });
  }, [snapshot]);

  const errorKeys = useMemo(() => {
    const set = new Set<string>();
    for (const e of validationErrors) {
      set.add(`${e.objectType}:${e.objectKey}`);
    }
    return set;
  }, [validationErrors]);

  if (versionQuery.isLoading || !snapshot) {
    return (
      <div className="space-y-3">
        <Skeleton className="h-14 w-full" />
        <Skeleton className="h-[calc(100vh-11rem)] w-full" />
      </div>
    );
  }

  if (versionQuery.isError) {
    return (
      <ErrorState
        message={toUserMessage(versionQuery.error)}
        onRetry={() => versionQuery.refetch()}
      />
    );
  }

  const meta = versionQuery.data!;
  const isDraft = meta.status === "DRAFT";
  const maxPolicySlots =
    meta.tierPolicies && meta.tierPolicies.length > 0
      ? Math.max(...meta.tierPolicies.map((p) => p.slotCount))
      : 12;
  const slotCountForPreviewTier = (tier: number) => {
    const found = meta.tierPolicies?.find((p) => p.tier === tier);
    if (found) return found.slotCount;
    return snapshot.slots.filter((s) => s.tierRequired <= tier).length;
  };
  const unsupportedLayers = snapshot.sceneLayers.filter(
    (l) => !LAYER_TYPES.includes(l.layerType as (typeof LAYER_TYPES)[number]),
  );

  const selectedSlot =
    selected?.type === "SLOT"
      ? snapshot.slots.find((s) => s.stableSlotKey === selected.key) ?? null
      : null;
  const selectedRegion =
    selected?.type === "REGION"
      ? snapshot.regions.find((r) => r.regionCode === selected.key) ?? null
      : null;
  const selectedLayer =
    selected?.type === "SCENE_LAYER"
      ? snapshot.sceneLayers.find((l) => l.layerKey === selected.key) ?? null
      : null;

  return (
    <div className="flex h-[calc(100vh-6.25rem)] flex-col gap-2 overflow-hidden">
      {/* 1. Top Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-border bg-white px-3 py-2 shadow-sm">
        <div className="flex items-center gap-2.5">
          <Button
            size="sm"
            variant="ghost"
            onClick={() => router.push("/island-builder")}
            title="Quay lại danh sách bố cục"
          >
            <ArrowLeft className="mr-1 size-4" />
            Danh sách
          </Button>
          <div className="h-5 w-px bg-border" />
          <div>
            <div className="flex items-center gap-2">
              <span className="font-bold text-ink">{meta.layoutName}</span>
              <span className="rounded bg-surface-alt px-1.5 py-0.5 font-mono text-xs text-ink-muted">
                v{meta.versionNumber}
              </span>
              <span
                className={cn(
                  "rounded-full px-2 py-0.5 text-[11px] font-semibold",
                  meta.status === "PUBLISHED"
                    ? "bg-emerald-100 text-emerald-800"
                    : meta.status === "DRAFT"
                      ? "bg-blue-100 text-blue-800"
                      : "bg-gray-100 text-gray-700",
                )}
              >
                {meta.status}
              </span>
              {isDraft && (
                <span
                  className={cn(
                    "rounded-full px-2 py-0.5 text-[11px] font-medium",
                    isDirty
                      ? "bg-amber-100 text-amber-800"
                      : "bg-emerald-50 text-emerald-700",
                  )}
                >
                  {isDirty ? "● Chưa lưu thay đổi" : "✓ Đã lưu"}
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Mode Switcher: Edit vs Preview Tier 1/2/3 */}
        <div className="flex items-center gap-1 rounded-lg border border-border bg-surface-alt p-1">
          {isDraft && (
            <button
              type="button"
              onClick={() => setPreviewTier(null)}
              className={cn(
                "rounded-md px-2.5 py-1 text-xs font-semibold transition-colors",
                previewTier === null
                  ? "bg-brand text-white shadow-sm"
                  : "text-ink-muted hover:text-ink",
              )}
            >
              Thiết kế
            </button>
          )}
          {[
            { tier: 1, label: "Xem trước: Đảo nhỏ (T1)" },
            { tier: 2, label: "Đảo vừa (T2)" },
            { tier: 3, label: "Đảo lớn (T3)" },
          ].map((t) => (
            <button
              key={t.tier}
              type="button"
              onClick={() => setPreviewTier(t.tier)}
              className={cn(
                "rounded-md px-2.5 py-1 text-xs font-semibold transition-colors",
                previewTier === t.tier
                  ? "bg-emerald-700 text-white shadow-sm"
                  : "text-ink-muted hover:text-ink",
              )}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Action Buttons */}
        <div className="flex items-center gap-1.5">
          {isDraft ? (
            <>
              <Button
                size="sm"
                variant="ghost"
                disabled={undoStack.length === 0 || previewTier !== null}
                onClick={handleUndo}
                title="Hoàn tác thao tác trước"
              >
                <Undo2 className="mr-1 size-3.5" />
                Hoàn tác
              </Button>
              <Button
                size="sm"
                variant="secondary"
                disabled={saveMutation.isPending}
                onClick={() => saveMutation.mutate()}
              >
                <Save className="mr-1 size-3.5" />
                {saveMutation.isPending ? "Đang lưu..." : "Lưu nháp"}
              </Button>
              <Button
                size="sm"
                variant="secondary"
                disabled={validateMutation.isPending}
                onClick={() => validateMutation.mutate()}
              >
                <ShieldCheck className="mr-1 size-3.5" />
                {validateMutation.isPending ? "Đang kiểm tra..." : "Kiểm tra"}
              </Button>
              <Button
                size="sm"
                disabled={publishMutation.isPending}
                onClick={() => setShowPublishModal(true)}
              >
                <Sparkles className="mr-1 size-3.5" />
                Xuất bản
              </Button>
            </>
          ) : (
            <Button
              size="sm"
              disabled={cloneMutation.isPending}
              onClick={() => cloneMutation.mutate()}
            >
              <Copy className="mr-1.5 size-3.5" />
              {cloneMutation.isPending
                ? "Đang nhân bản..."
                : "Nhân bản thành Draft để chỉnh sửa"}
            </Button>
          )}
        </div>
      </div>

      {/* Status / Validation Banner */}
      {(bannerMessage || validationErrors.length > 0) && (
        <div
          className={cn(
            "flex flex-col gap-1.5 rounded-lg border px-3 py-2 text-xs",
            validationErrors.length > 0 || bannerMessage?.type === "error"
              ? "border-error/40 bg-error/10 text-error"
              : "border-emerald-300 bg-emerald-50 text-emerald-800",
          )}
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 font-semibold">
              {validationErrors.length > 0 ||
              bannerMessage?.type === "error" ? (
                <AlertTriangle className="size-4 shrink-0" />
              ) : (
                <CheckCircle2 className="size-4 shrink-0" />
              )}
              <span>
                {bannerMessage?.text ??
                  `Có ${validationErrors.length} lỗi cần khắc phục trước khi xuất bản:`}
              </span>
            </div>
            <button
              type="button"
              onClick={() => {
                setBannerMessage(null);
                setValidationErrors([]);
              }}
              className="text-xs underline"
            >
              Ẩn
            </button>
          </div>
          {validationErrors.length > 0 && (
            <div className="flex max-h-24 flex-wrap gap-1.5 overflow-y-auto pt-1">
              {validationErrors.map((err, i) => (
                <button
                  key={`${err.objectKey}-${err.field}-${i}`}
                  type="button"
                  onClick={() => handleSelectValidationError(err)}
                  className="inline-flex items-center gap-1 rounded border border-error/30 bg-white px-2 py-0.5 text-left text-[11px] font-medium text-error hover:bg-error/5"
                >
                  <span className="font-mono font-bold">
                    [{err.objectType}:{err.objectKey}]
                  </span>
                  <span>{err.message}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {/* 2. Main 3-Column Builder Area */}
      <div className="flex min-h-0 flex-1 gap-2 overflow-hidden">
        {/* LEFT COLUMN — Toolbox & Object Lists (Independent Scroll) */}
        <aside
          className={cn(
            "flex h-full flex-col rounded-xl border border-border bg-white shadow-sm transition-all",
            leftCollapsed ? "w-11" : "w-72 shrink-0",
          )}
        >
          <div className="flex h-10 items-center justify-between border-b border-border px-2.5">
            {!leftCollapsed && (
              <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
                Công cụ & Lớp cảnh
              </span>
            )}
            <button
              type="button"
              onClick={() => setLeftCollapsed((c) => !c)}
              className="flex size-7 items-center justify-center rounded hover:bg-surface-alt"
              title={leftCollapsed ? "Mở bảng công cụ" : "Thu gọn bảng công cụ"}
            >
              {leftCollapsed ? (
                <PanelLeftOpen className="size-4" />
              ) : (
                <PanelLeftClose className="size-4" />
              )}
            </button>
          </div>

          {!leftCollapsed && (
            <div className="flex-1 space-y-4 overflow-y-auto p-3 text-xs">
              {/* Quick Add Toolbox */}
              {!isReadOnly && (
                <div className="space-y-1.5">
                  <div className="font-semibold text-ink">Thêm phần tử</div>
                  <div className="grid grid-cols-1 gap-1.5">
                    <Button
                      size="sm"
                      variant="secondary"
                      className="justify-start text-xs"
                      onClick={handleAddSlot}
                    >
                      <Plus className="mr-1.5 size-3.5 text-brand" />
                      Thêm ô đặt vật phẩm (Slot)
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      className="justify-start text-xs"
                      onClick={handleAddRegion}
                    >
                      <Plus className="mr-1.5 size-3.5 text-emerald-600" />
                      Thêm vùng đất (Region)
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      className="justify-start text-xs"
                      onClick={handleAddLayer}
                    >
                      <Plus className="mr-1.5 size-3.5 text-blue-600" />
                      Thêm lớp cảnh quan (Scene Layer)
                    </Button>
                  </div>
                </div>
              )}

              {/* Scene Layers */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between font-semibold text-ink">
                  <span className="flex items-center gap-1">
                    <Layers className="size-3.5 text-blue-600" />
                    Scene Layers ({sortedLayers.length})
                  </span>
                </div>
                <div className="space-y-1">
                  {sortedLayers.map((layer) => {
                    const active =
                      selected?.type === "SCENE_LAYER" &&
                      selected.key === layer.layerKey;
                    const hasErr = errorKeys.has(
                      `LAYER:${layer.layerKey}`,
                    );
                    return (
                      <div
                        key={layer.layerKey}
                        onClick={() => {
                          setSelected({
                            type: "SCENE_LAYER",
                            key: layer.layerKey,
                          });
                          setRightCollapsed(false);
                        }}
                        className={cn(
                          "flex cursor-pointer items-center justify-between rounded-md border px-2 py-1.5 transition-colors",
                          active
                            ? "border-brand bg-brand/10 font-semibold text-brand"
                            : hasErr
                              ? "border-error bg-error/5 text-error"
                              : "border-border hover:bg-surface-alt",
                        )}
                      >
                        <div className="min-w-0 flex-1">
                          <div className="truncate">{layer.layerKey}</div>
                          <div className="text-[10px] text-ink-muted">
                            {layer.layerType} • #{layer.renderOrder}
                          </div>
                        </div>
                        {!isReadOnly && (
                          <div className="flex items-center gap-0.5">
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                updateSnapshot((prev) => ({
                                  ...prev,
                                  sceneLayers: prev.sceneLayers.map((l) =>
                                    l.layerKey === layer.layerKey
                                      ? { ...l, renderOrder: l.renderOrder - 5 }
                                      : l,
                                  ),
                                }));
                              }}
                              className="rounded p-0.5 hover:bg-white"
                              title="Giảm thứ tự render"
                            >
                              <ArrowUp className="size-3" />
                            </button>
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                updateSnapshot((prev) => ({
                                  ...prev,
                                  sceneLayers: prev.sceneLayers.map((l) =>
                                    l.layerKey === layer.layerKey
                                      ? { ...l, renderOrder: l.renderOrder + 5 }
                                      : l,
                                  ),
                                }));
                              }}
                              className="rounded p-0.5 hover:bg-white"
                              title="Tăng thứ tự render"
                            >
                              <ArrowDown className="size-3" />
                            </button>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Regions List */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between font-semibold text-ink">
                  <span>Vùng đất theo Tier ({snapshot.regions.length})</span>
                </div>
                <div className="space-y-1">
                  {snapshot.regions.map((region) => {
                    const active =
                      selected?.type === "REGION" &&
                      selected.key === region.regionCode;
                    const hasErr = errorKeys.has(`REGION:${region.regionCode}`);
                    const slotCount = snapshot.slots.filter(
                      (s) => s.regionCode === region.regionCode,
                    ).length;
                    return (
                      <div
                        key={region.regionCode}
                        onClick={() => {
                          setSelected({
                            type: "REGION",
                            key: region.regionCode,
                          });
                          setRightCollapsed(false);
                        }}
                        className={cn(
                          "flex cursor-pointer items-center justify-between rounded-md border px-2 py-1.5 transition-colors",
                          active
                            ? "border-brand bg-brand/10 font-semibold text-brand"
                            : hasErr
                              ? "border-error bg-error/5 text-error"
                              : "border-border hover:bg-surface-alt",
                        )}
                      >
                        <div>
                          <div className="font-medium">
                            {region.label || region.regionCode}
                          </div>
                          <div className="text-[10px] text-ink-muted">
                            {region.regionCode} • Mở ở Tier {region.unlockTier}{" "}
                            • {slotCount} slot
                          </div>
                        </div>
                        <span
                          className={cn(
                            "rounded px-1.5 py-0.5 text-[10px] font-bold",
                            TIER_COLORS[region.unlockTier]?.badge ??
                              "bg-gray-600 text-white",
                          )}
                        >
                          T{region.unlockTier}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Slots List */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between font-semibold text-ink">
                  <span className="flex items-center gap-1">
                    <MapPin className="size-3.5 text-brand" />
                    Ô đặt vật phẩm ({snapshot.slots.length}/12)
                  </span>
                </div>
                <div className="grid grid-cols-1 gap-1">
                  {[...snapshot.slots]
                    .sort((a, b) => a.slotIndex - b.slotIndex)
                    .map((slot) => {
                      const active =
                        selected?.type === "SLOT" &&
                        selected.key === slot.stableSlotKey;
                      const hasErr =
                        errorKeys.has(`SLOT:${slot.stableSlotKey}`) ||
                        errorKeys.has(`SLOT:SLOT_${slot.slotIndex}`);
                      return (
                        <div
                          key={slot.stableSlotKey}
                          onClick={() => {
                            setSelected({
                              type: "SLOT",
                              key: slot.stableSlotKey,
                            });
                            setRightCollapsed(false);
                          }}
                          className={cn(
                            "flex cursor-pointer items-center justify-between rounded-md border px-2 py-1.5 transition-colors",
                            active
                              ? "border-brand bg-brand/10 font-semibold text-brand"
                              : hasErr
                                ? "border-error bg-error/5 text-error"
                                : "border-border hover:bg-surface-alt",
                          )}
                        >
                          <div className="min-w-0">
                            <div className="truncate font-mono text-[11px] font-bold">
                              #{slot.slotIndex} • {slot.stableSlotKey}
                            </div>
                            <div className="text-[10px] text-ink-muted">
                              {slot.regionCode || "Chưa gán"} • (
                              {slot.coordX.toFixed(2)}, {slot.coordY.toFixed(2)}
                              )
                            </div>
                          </div>
                          <span
                            className={cn(
                              "rounded px-1.5 py-0.5 text-[10px] font-bold",
                              TIER_COLORS[slot.tierRequired]?.badge ??
                                "bg-gray-600 text-white",
                            )}
                          >
                            T{slot.tierRequired}
                          </span>
                        </div>
                      );
                    })}
                </div>
              </div>

              {/* Asset Picker from Media Library */}
              <div className="space-y-1.5 border-t border-border pt-3">
                <div className="flex items-center gap-1 font-semibold text-ink">
                  <ImageIcon className="size-3.5 text-amber-700" />
                  Thư viện Media (/admin/assets)
                </div>
                <p className="text-[11px] text-ink-muted">
                  Chọn một Scene Layer kiểu STATIC_IMAGE rồi bấm vào asset bên dưới để gán hình nền.
                </p>
                <div className="max-h-40 space-y-1 overflow-y-auto rounded border border-border p-1.5">
                  <button
                    type="button"
                    disabled={
                      isReadOnly || selectedLayer?.layerType !== "STATIC_IMAGE"
                    }
                    onClick={() => {
                      if (!selectedLayer) return;
                      updateSnapshot((prev) => ({
                        ...prev,
                        sceneLayers: prev.sceneLayers.map((l) =>
                          l.layerKey === selectedLayer.layerKey
                            ? {
                                ...l,
                                assetRef:
                                  "assets/images/dv_ISL_generic_island-base-tiers_v01.jpg",
                              }
                            : l,
                        ),
                      }));
                    }}
                    className="w-full rounded px-2 py-1 text-left text-[11px] hover:bg-surface-alt disabled:opacity-50"
                  >
                    ★ Mặc định: dv_ISL_generic_island-base-tiers_v01.jpg
                  </button>
                  {(assetsQuery.data?.items ?? []).map((asset) => {
                    const url = `/api/v1/assets/${asset.id}/content`;
                    return (
                      <button
                        key={asset.id}
                        type="button"
                        disabled={
                          isReadOnly ||
                          selectedLayer?.layerType !== "STATIC_IMAGE"
                        }
                        onClick={() => {
                          if (!selectedLayer) return;
                          updateSnapshot((prev) => ({
                            ...prev,
                            sceneLayers: prev.sceneLayers.map((l) =>
                              l.layerKey === selectedLayer.layerKey
                                ? { ...l, assetRef: url }
                                : l,
                            ),
                          }));
                        }}
                        className="w-full truncate rounded px-2 py-1 text-left text-[11px] hover:bg-surface-alt disabled:opacity-50"
                        title={asset.altText || asset.id}
                      >
                        • {asset.altText || asset.mimeType} (
                        {asset.id.slice(0, 8)})
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>
          )}
        </aside>

        {/* CENTER COLUMN — Interactive 2.5D Canvas */}
        <section className="relative flex min-w-0 flex-1 flex-col overflow-hidden rounded-xl border border-border bg-slate-900 shadow-inner">
          {/* Canvas Floating Controls */}
          <div className="absolute left-3 top-3 z-30 flex flex-wrap items-center gap-1.5 rounded-lg border border-white/15 bg-slate-900/85 px-2.5 py-1.5 text-xs text-white backdrop-blur">
            <button
              type="button"
              onClick={() =>
                setZoom((z) => Number(Math.max(0.45, z - 0.1).toFixed(2)))
              }
              className="rounded p-1 hover:bg-white/15"
              title="Thu nhỏ"
            >
              <ZoomOut className="size-4" />
            </button>
            <span className="min-w-[44px] text-center font-mono">
              {Math.round(zoom * 100)}%
            </span>
            <button
              type="button"
              onClick={() =>
                setZoom((z) => Number(Math.min(1.6, z + 0.1).toFixed(2)))
              }
              className="rounded p-1 hover:bg-white/15"
              title="Phóng to"
            >
              <ZoomIn className="size-4" />
            </button>
            <div className="h-4 w-px bg-white/20" />
            <button
              type="button"
              onClick={() => {
                setZoom(0.78);
                setPan({ x: 0, y: 0 });
              }}
              className="flex items-center gap-1 rounded px-1.5 py-1 hover:bg-white/15"
              title="Đặt lại góc nhìn"
            >
              <RotateCcw className="size-3.5" />
              Reset
            </button>
            <div className="h-4 w-px bg-white/20" />
            <button
              type="button"
              onClick={() => setShowGrid((g) => !g)}
              className={cn(
                "flex items-center gap-1 rounded px-1.5 py-1",
                showGrid ? "bg-brand text-white" : "hover:bg-white/15",
              )}
            >
              <Grid className="size-3.5" />
              Lưới
            </button>
            <button
              type="button"
              onClick={() => setShowRegionsOverlay((r) => !r)}
              className={cn(
                "flex items-center gap-1 rounded px-1.5 py-1",
                showRegionsOverlay
                  ? "bg-emerald-600 text-white"
                  : "hover:bg-white/15",
              )}
            >
              <Eye className="size-3.5" />
              Vùng Tier
            </button>
          </div>

          {previewTier !== null && (
            <div className="absolute right-3 top-3 z-30 flex flex-col items-end gap-1.5">
              <div className="flex items-center gap-2 rounded-lg border border-emerald-400/40 bg-emerald-950/90 px-3 py-1.5 text-xs font-semibold text-emerald-100 shadow-lg">
                <Eye className="size-4 text-emerald-400" />
                <span>
                  Chế độ Xem trước người học —{" "}
                  {previewTier === 1
                    ? `Đảo nhỏ (Tier 1 • ${slotCountForPreviewTier(1)} ô mở)`
                    : previewTier === 2
                      ? `Đảo vừa (Tier 2 • ${slotCountForPreviewTier(2)} ô mở)`
                      : `Đảo lớn (Tier 3 • ${slotCountForPreviewTier(3)} ô mở)`}
                </span>
              </div>
              {unsupportedLayers.length > 0 && (
                <div className="flex items-center gap-1.5 rounded-lg border border-amber-400/50 bg-amber-950/90 px-2.5 py-1 text-[11px] font-medium text-amber-200 shadow">
                  <AlertTriangle className="size-3.5 text-amber-400" />
                  <span>
                    Có {unsupportedLayers.length} layer dùng loại không được mobile hỗ trợ:{" "}
                    {unsupportedLayers.map((l) => l.layerKey).join(", ")}
                  </span>
                </div>
              )}
            </div>
          )}

          {/* Viewport Container */}
          <div
            ref={canvasRef}
            onMouseDown={(e) => {
              if (e.target === e.currentTarget) {
                setSelected(null);
                setDragState({
                  kind: "PAN",
                  startClientX: e.clientX,
                  startClientY: e.clientY,
                  origPanX: pan.x,
                  origPanY: pan.y,
                });
              }
            }}
            className="flex flex-1 cursor-grab items-center justify-center overflow-hidden active:cursor-grabbing"
          >
            {/* Scaled Virtual Canvas */}
            <div
              style={{
                width: snapshot.canvasWidth,
                height: snapshot.canvasHeight,
                transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})`,
                transformOrigin: "center center",
              }}
              onMouseDown={(e) => {
                if (e.target === e.currentTarget) {
                  setSelected(null);
                  setDragState({
                    kind: "PAN",
                    startClientX: e.clientX,
                    startClientY: e.clientY,
                    origPanX: pan.x,
                    origPanY: pan.y,
                  });
                }
              }}
              className="relative select-none rounded-2xl shadow-2xl ring-2 ring-white/20"
            >
              {/* Render Scene Layers in renderOrder */}
              {sortedLayers.map((layer) => {
                const rule = parseVisibilityRule(layer.visibilityRuleJson);
                if (
                  previewTier !== null &&
                  (previewTier < rule.minTier || previewTier > rule.maxTier)
                ) {
                  return null;
                }

                if (layer.layerType === "ANIMATED_WATER") {
                  return (
                    <div
                      key={layer.layerKey}
                      style={{ zIndex: layer.renderOrder }}
                      className="pointer-events-none absolute inset-0 rounded-2xl bg-[radial-gradient(circle_at_center,#86B9CF_0%,#4A89A6_85%)]"
                    />
                  );
                }

                if (
                  layer.layerType === "STATIC_IMAGE" ||
                  layer.layerType === "FALLBACK_GRAPHICS"
                ) {
                  const ref = layer.assetRef?.trim() ?? "";
                  const imgSrc = ref.startsWith("/api/")
                    ? `/api/proxy${ref.replace(/^\/api\/v1/, "")}`
                    : ref.startsWith("http")
                      ? ref
                      : null;

                  return (
                    <div
                      key={layer.layerKey}
                      style={{ zIndex: layer.renderOrder }}
                      className="pointer-events-none absolute inset-0 flex items-center justify-center overflow-hidden rounded-2xl"
                    >
                      {imgSrc ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={imgSrc}
                          alt={layer.layerKey}
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        /* Fallback Isometric Heritage Island Graphic */
                        <div className="relative flex h-[78%] w-[84%] items-center justify-center rounded-[50%] border-4 border-[#613B28] bg-[radial-gradient(circle_at_50%_40%,#E6D5B8_0%,#C8B08A_70%,#9C7E54_100%)] shadow-[0_24px_48px_rgba(0,0,0,0.45)]">
                          <div className="pointer-events-none absolute inset-4 rounded-[50%] border-2 border-dashed border-[#613B28]/30" />
                          <span className="rounded-full bg-[#613B28]/80 px-3 py-1 text-xs font-semibold text-amber-100">
                            {layer.assetRef || "Đảo Di Sản 2.5D Base"}
                          </span>
                        </div>
                      )}
                    </div>
                  );
                }

                if (layer.layerType === "AMBIENT_OVERLAY") {
                  return (
                    <div
                      key={layer.layerKey}
                      style={{ zIndex: layer.renderOrder }}
                      className="pointer-events-none absolute inset-0 rounded-2xl border border-white/20 bg-[radial-gradient(circle_at_25%_75%,rgba(255,255,255,0.12)_0%,transparent_45%)]"
                    />
                  );
                }

                return null;
              })}

              {/* Optional Coordinate Grid */}
              {showGrid && (
                <div
                  style={{ zIndex: 22 }}
                  className="pointer-events-none absolute inset-0 bg-[linear-gradient(to_right,rgba(255,255,255,0.14)_1px,transparent_1px),linear-gradient(to_bottom,rgba(255,255,255,0.14)_1px,transparent_1px)] bg-[size:48px_36px]"
                />
              )}

              {/* Regions Overlay */}
              {showRegionsOverlay &&
                snapshot.regions.map((region) => {
                  const b = parseRegionBounds(region.boundsJson);
                  const isLockedInPreview =
                    previewTier !== null && region.unlockTier > previewTier;
                  const isSelected =
                    selected?.type === "REGION" &&
                    selected.key === region.regionCode;
                  const colors = TIER_COLORS[region.unlockTier] ?? TIER_COLORS[1];

                  return (
                    <div
                      key={region.regionCode}
                      style={{
                        zIndex: isLockedInPreview ? 26 : 18,
                        left: `${b.x * 100}%`,
                        top: `${b.y * 100}%`,
                        width: `${b.width * 100}%`,
                        height: `${b.height * 100}%`,
                      }}
                      onMouseDown={(e) => {
                        e.stopPropagation();
                        setSelected({
                          type: "REGION",
                          key: region.regionCode,
                        });
                        setRightCollapsed(false);
                        if (!isReadOnly) {
                          pushUndo(snapshot);
                          setDragState({
                            kind: "REGION_MOVE",
                            regionCode: region.regionCode,
                            startClientX: e.clientX,
                            startClientY: e.clientY,
                            origX: b.x,
                            origY: b.y,
                            width: b.width,
                            height: b.height,
                          });
                        }
                      }}
                      className={cn(
                        "absolute rounded-2xl border-2 transition-shadow",
                        isLockedInPreview
                          ? "border-amber-300/60 bg-slate-900/55 backdrop-blur-[1px]"
                          : `${colors.border} ${colors.bg}`,
                        isSelected && "ring-4 ring-white",
                        !isReadOnly && "cursor-move",
                      )}
                    >
                      <div className="flex items-center justify-between px-2.5 py-1">
                        <span
                          className={cn(
                            "rounded px-2 py-0.5 text-[11px] font-bold shadow",
                            isLockedInPreview
                              ? "bg-slate-900/90 text-amber-200"
                              : colors.badge,
                          )}
                        >
                          {region.label || region.regionCode} • Tier{" "}
                          {region.unlockTier}
                          {isLockedInPreview ? " (Đang khóa)" : ""}
                        </span>
                      </div>

                      {/* Resize Handle in Edit Mode */}
                      {!isReadOnly && (
                        <div
                          onMouseDown={(e) => {
                            e.stopPropagation();
                            setSelected({
                              type: "REGION",
                              key: region.regionCode,
                            });
                            pushUndo(snapshot);
                            setDragState({
                              kind: "REGION_RESIZE",
                              regionCode: region.regionCode,
                              startClientX: e.clientX,
                              startClientY: e.clientY,
                              origX: b.x,
                              origY: b.y,
                              origW: b.width,
                              origH: b.height,
                            });
                          }}
                          title="Kéo để thay đổi kích thước vùng đất"
                          className="absolute bottom-1 right-1 flex size-5 cursor-nwse-resize items-center justify-center rounded bg-white/90 text-ink shadow"
                        >
                          <Maximize2 className="size-3" />
                        </div>
                      )}
                    </div>
                  );
                })}

              {/* Slots Layer */}
              {sortedSlots.map((slot) => {
                const slotW = (slot.widthNorm || 0.1) * snapshot.canvasWidth;
                const slotH = (slot.heightNorm || 0.12) * snapshot.canvasHeight;
                const leftPx =
                  slot.coordX * snapshot.canvasWidth -
                  slotW * (slot.anchorX ?? 0.5);
                const topPx =
                  slot.coordY * snapshot.canvasHeight -
                  slotH * (slot.anchorY ?? 1.0);
                const isSelected =
                  selected?.type === "SLOT" &&
                  selected.key === slot.stableSlotKey;
                const isLockedInPreview =
                  previewTier !== null && slot.tierRequired > previewTier;
                const hasError =
                  errorKeys.has(`SLOT:${slot.stableSlotKey}`) ||
                  errorKeys.has(`SLOT:SLOT_${slot.slotIndex}`);
                const colors = TIER_COLORS[slot.tierRequired] ?? TIER_COLORS[1];

                return (
                  <div
                    key={slot.stableSlotKey}
                    style={{
                      zIndex: 30 + slot.zIndex,
                      left: leftPx,
                      top: topPx,
                      width: slotW,
                      height: slotH,
                    }}
                    onMouseDown={(e) => {
                      e.stopPropagation();
                      if (isLockedInPreview) return;
                      setSelected({ type: "SLOT", key: slot.stableSlotKey });
                      setRightCollapsed(false);
                      if (!isReadOnly) {
                        pushUndo(snapshot);
                        setDragState({
                          kind: "SLOT",
                          slotKey: slot.stableSlotKey,
                          startClientX: e.clientX,
                          startClientY: e.clientY,
                          origX: slot.coordX,
                          origY: slot.coordY,
                        });
                      }
                    }}
                    className={cn(
                      "group absolute flex flex-col items-center justify-end pb-1 transition-transform",
                      !isReadOnly && "cursor-grab active:cursor-grabbing",
                      isLockedInPreview && "cursor-not-allowed opacity-75",
                    )}
                  >
                    {/* Isometric Platform Base */}
                    <div
                      className={cn(
                        "flex size-11 items-center justify-center rounded-full border-2 shadow-md transition-all",
                        isLockedInPreview
                          ? "border-amber-200/50 bg-slate-800/90 text-amber-200"
                          : hasError
                            ? "border-error bg-error text-white"
                            : `${colors.border} bg-white text-ink`,
                        isSelected && "scale-110 ring-4 ring-amber-400",
                      )}
                    >
                      {isLockedInPreview ? (
                        <Lock className="size-4" />
                      ) : (
                        <span className="font-mono text-xs font-extrabold">
                          #{slot.slotIndex}
                        </span>
                      )}
                    </div>

                    {/* Label Pill */}
                    <div
                      className={cn(
                        "mt-1 max-w-[110px] truncate rounded-full px-2 py-0.5 text-[10px] font-bold shadow",
                        isSelected
                          ? "bg-amber-400 text-slate-950"
                          : "bg-slate-900/90 text-white",
                      )}
                    >
                      {slot.stableSlotKey} (T{slot.tierRequired})
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        {/* RIGHT COLUMN — Property Inspector (Independent Scroll) */}
        <aside
          className={cn(
            "flex h-full flex-col rounded-xl border border-border bg-white shadow-sm transition-all",
            rightCollapsed ? "w-11" : "w-80 shrink-0",
          )}
        >
          <div className="flex h-10 items-center justify-between border-b border-border px-2.5">
            <button
              type="button"
              onClick={() => setRightCollapsed((c) => !c)}
              className="flex size-7 items-center justify-center rounded hover:bg-surface-alt"
              title={
                rightCollapsed ? "Mở bảng thuộc tính" : "Thu gọn bảng thuộc tính"
              }
            >
              {rightCollapsed ? (
                <PanelRightOpen className="size-4" />
              ) : (
                <PanelRightClose className="size-4" />
              )}
            </button>
            {!rightCollapsed && (
              <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
                Thuộc tính chi tiết
              </span>
            )}
          </div>

          {!rightCollapsed && (
            <div className="flex-1 space-y-4 overflow-y-auto p-3.5 text-xs">
              {!selected && (
                <div className="space-y-3">
                  <div className="rounded-lg border border-border bg-surface-alt p-3 text-ink-muted">
                    Nhấn vào một <strong>Ô đặt (Slot)</strong>,{" "}
                    <strong>Vùng đất (Region)</strong> hoặc{" "}
                    <strong>Scene Layer</strong> trên canvas để xem và chỉnh sửa thuộc tính trực tiếp.
                  </div>

                  {/* Global Canvas Settings */}
                  <div className="space-y-2 border-t border-border pt-3">
                    <div className="font-bold text-ink">
                      Cấu hình Canvas chung
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <Label>Rộng (px)</Label>
                        <Input
                          type="number"
                          disabled={isReadOnly}
                          value={snapshot.canvasWidth}
                          onChange={(e) =>
                            updateSnapshot((prev) => ({
                              ...prev,
                              canvasWidth: Number(e.target.value) || 960,
                            }))
                          }
                        />
                      </div>
                      <div>
                        <Label>Cao (px)</Label>
                        <Input
                          type="number"
                          disabled={isReadOnly}
                          value={snapshot.canvasHeight}
                          onChange={(e) =>
                            updateSnapshot((prev) => ({
                              ...prev,
                              canvasHeight: Number(e.target.value) || 720,
                            }))
                          }
                        />
                      </div>
                    </div>
                    <div>
                      <Label>Theme Key</Label>
                      <Input
                        disabled={isReadOnly}
                        value={snapshot.themeKey}
                        onChange={(e) =>
                          updateSnapshot((prev) => ({
                            ...prev,
                            themeKey: e.target.value,
                          }))
                        }
                      />
                    </div>
                  </div>
                </div>
              )}

              {/* 5.1 Slot Inspector */}
              {selectedSlot && (
                <div className="space-y-3">
                  <div className="flex items-center justify-between border-b border-border pb-2">
                    <div>
                      <span className="text-[10px] font-bold uppercase text-brand">
                        Ô ĐẶT VẬT PHẨM (SLOT)
                      </span>
                      <h4 className="font-mono text-sm font-bold text-ink">
                        #{selectedSlot.slotIndex} — {selectedSlot.stableSlotKey}
                      </h4>
                    </div>
                    {!isReadOnly && (
                      <Button
                        size="sm"
                        variant="ghost"
                        className="text-error hover:bg-error/10"
                        onClick={() => {
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.filter(
                              (s) =>
                                s.stableSlotKey !== selectedSlot.stableSlotKey,
                            ),
                          }));
                          setSelected(null);
                        }}
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    )}
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <Label>Thứ tự (slotIndex 1..{maxPolicySlots})</Label>
                      <Input
                        type="number"
                        min={1}
                        max={maxPolicySlots}
                        disabled={isReadOnly}
                        value={selectedSlot.slotIndex}
                        onChange={(e) => {
                          const val = Number(e.target.value) || 1;
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, slotIndex: val }
                                : s,
                            ),
                          }));
                        }}
                      />
                    </div>
                    <div>
                      <Label>Tier mở khóa (1..3)</Label>
                      <select
                        disabled={isReadOnly}
                        value={selectedSlot.tierRequired}
                        onChange={(e) => {
                          const tier = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, tierRequired: tier }
                                : s,
                            ),
                          }));
                        }}
                        className="h-9 w-full rounded-md border border-border bg-white px-2 text-xs"
                      >
                        <option value={1}>Tier 1 — Đảo nhỏ</option>
                        <option value={2}>Tier 2 — Đảo vừa</option>
                        <option value={3}>Tier 3 — Đảo lớn</option>
                      </select>
                    </div>
                  </div>

                  <div>
                    <Label>Mã định danh ổn định (stableSlotKey)</Label>
                    <Input
                      disabled={isReadOnly}
                      value={selectedSlot.stableSlotKey}
                      onChange={(e) => {
                        const newKey = e.target.value.trim();
                        if (!newKey) return;
                        updateSnapshot((prev) => ({
                          ...prev,
                          slots: prev.slots.map((s) =>
                            s.stableSlotKey === selectedSlot.stableSlotKey
                              ? { ...s, stableSlotKey: newKey }
                              : s,
                          ),
                        }));
                        setSelected({ type: "SLOT", key: newKey });
                      }}
                    />
                  </div>

                  <div>
                    <Label>Thuộc Vùng đất (regionCode)</Label>
                    <select
                      disabled={isReadOnly}
                      value={selectedSlot.regionCode ?? ""}
                      onChange={(e) => {
                        const rc = e.target.value;
                        updateSnapshot((prev) => ({
                          ...prev,
                          slots: prev.slots.map((s) =>
                            s.stableSlotKey === selectedSlot.stableSlotKey
                              ? { ...s, regionCode: rc }
                              : s,
                          ),
                        }));
                      }}
                      className="h-9 w-full rounded-md border border-border bg-white px-2 text-xs"
                    >
                      <option value="">-- Chọn vùng đất --</option>
                      {snapshot.regions.map((r) => (
                        <option key={r.regionCode} value={r.regionCode}>
                          {r.regionCode} ({r.label || `Tier ${r.unlockTier}`})
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <Label>Tọa độ X [0..1]</Label>
                      <Input
                        type="number"
                        step="0.01"
                        min={0}
                        max={1}
                        disabled={isReadOnly}
                        value={selectedSlot.coordX}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, coordX: v }
                                : s,
                            ),
                          }));
                        }}
                      />
                    </div>
                    <div>
                      <Label>Tọa độ Y [0..1]</Label>
                      <Input
                        type="number"
                        step="0.01"
                        min={0}
                        max={1}
                        disabled={isReadOnly}
                        value={selectedSlot.coordY}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, coordY: v }
                                : s,
                            ),
                          }));
                        }}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <Label>Rộng chuẩn hóa (widthNorm)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        min={0.02}
                        max={0.5}
                        disabled={isReadOnly}
                        value={selectedSlot.widthNorm}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, widthNorm: v }
                                : s,
                            ),
                          }));
                        }}
                      />
                    </div>
                    <div>
                      <Label>Cao chuẩn hóa (heightNorm)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        min={0.02}
                        max={0.5}
                        disabled={isReadOnly}
                        value={selectedSlot.heightNorm}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, heightNorm: v }
                                : s,
                            ),
                          }));
                        }}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-3 gap-2">
                    <div>
                      <Label>Anchor X</Label>
                      <Input
                        type="number"
                        step="0.1"
                        min={0}
                        max={1}
                        disabled={isReadOnly}
                        value={selectedSlot.anchorX}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, anchorX: v }
                                : s,
                            ),
                          }));
                        }}
                      />
                    </div>
                    <div>
                      <Label>Anchor Y</Label>
                      <Input
                        type="number"
                        step="0.1"
                        min={0}
                        max={1}
                        disabled={isReadOnly}
                        value={selectedSlot.anchorY}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, anchorY: v }
                                : s,
                            ),
                          }));
                        }}
                      />
                    </div>
                    <div>
                      <Label>zIndex</Label>
                      <Input
                        type="number"
                        disabled={isReadOnly}
                        value={selectedSlot.zIndex}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            slots: prev.slots.map((s) =>
                              s.stableSlotKey === selectedSlot.stableSlotKey
                                ? { ...s, zIndex: v }
                                : s,
                            ),
                          }));
                        }}
                      />
                    </div>
                  </div>

                  <div>
                    <Label>Danh mục cho phép (phân cách bằng dấu phẩy)</Label>
                    <Input
                      disabled={isReadOnly}
                      value={(selectedSlot.allowedCategories ?? ["DECOR"]).join(
                        ", ",
                      )}
                      onChange={(e) => {
                        const cats = e.target.value
                          .split(",")
                          .map((c) => c.trim())
                          .filter(Boolean);
                        updateSnapshot((prev) => ({
                          ...prev,
                          slots: prev.slots.map((s) =>
                            s.stableSlotKey === selectedSlot.stableSlotKey
                              ? {
                                  ...s,
                                  allowedCategories:
                                    cats.length > 0 ? cats : ["DECOR"],
                                }
                              : s,
                          ),
                        }));
                      }}
                    />
                  </div>
                </div>
              )}

              {/* 5.2 Region Inspector */}
              {selectedRegion && (
                <div className="space-y-3">
                  <div className="flex items-center justify-between border-b border-border pb-2">
                    <div>
                      <span className="text-[10px] font-bold uppercase text-emerald-700">
                        VÙNG ĐẤT THEO TIER (REGION)
                      </span>
                      <h4 className="font-mono text-sm font-bold text-ink">
                        {selectedRegion.regionCode}
                      </h4>
                    </div>
                    {!isReadOnly && (
                      <Button
                        size="sm"
                        variant="ghost"
                        className="text-error hover:bg-error/10"
                        onClick={() => {
                          updateSnapshot((prev) => ({
                            ...prev,
                            regions: prev.regions.filter(
                              (r) => r.regionCode !== selectedRegion.regionCode,
                            ),
                          }));
                          setSelected(null);
                        }}
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    )}
                  </div>

                  <div>
                    <Label>Mã vùng (regionCode)</Label>
                    <Input
                      disabled={isReadOnly}
                      value={selectedRegion.regionCode}
                      onChange={(e) => {
                        const newCode = e.target.value.trim();
                        if (!newCode) return;
                        updateSnapshot((prev) => ({
                          ...prev,
                          regions: prev.regions.map((r) =>
                            r.regionCode === selectedRegion.regionCode
                              ? { ...r, regionCode: newCode }
                              : r,
                          ),
                          slots: prev.slots.map((s) =>
                            s.regionCode === selectedRegion.regionCode
                              ? { ...s, regionCode: newCode }
                              : s,
                          ),
                        }));
                        setSelected({ type: "REGION", key: newCode });
                      }}
                    />
                  </div>

                  <div>
                    <Label>Tên hiển thị (label)</Label>
                    <Input
                      disabled={isReadOnly}
                      value={selectedRegion.label ?? ""}
                      onChange={(e) => {
                        const val = e.target.value;
                        updateSnapshot((prev) => ({
                          ...prev,
                          regions: prev.regions.map((r) =>
                            r.regionCode === selectedRegion.regionCode
                              ? { ...r, label: val }
                              : r,
                          ),
                        }));
                      }}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <Label>Mở khóa ở Tier</Label>
                      <select
                        disabled={isReadOnly}
                        value={selectedRegion.unlockTier}
                        onChange={(e) => {
                          const tier = Number(e.target.value);
                          updateSnapshot((prev) => ({
                            ...prev,
                            regions: prev.regions.map((r) =>
                              r.regionCode === selectedRegion.regionCode
                                ? { ...r, unlockTier: tier }
                                : r,
                            ),
                          }));
                        }}
                        className="h-9 w-full rounded-md border border-border bg-white px-2 text-xs"
                      >
                        <option value={1}>Tier 1 — Đảo nhỏ</option>
                        <option value={2}>Tier 2 — Đảo vừa</option>
                        <option value={3}>Tier 3 — Đảo lớn</option>
                      </select>
                    </div>
                    <div>
                      <Label>Thứ tự sắp xếp</Label>
                      <Input
                        type="number"
                        disabled={isReadOnly}
                        value={selectedRegion.sortOrder}
                        onChange={(e) => {
                          const so = Number(e.target.value) || 0;
                          updateSnapshot((prev) => ({
                            ...prev,
                            regions: prev.regions.map((r) =>
                              r.regionCode === selectedRegion.regionCode
                                ? { ...r, sortOrder: so }
                                : r,
                            ),
                          }));
                        }}
                      />
                    </div>
                  </div>

                  {(() => {
                    const b = parseRegionBounds(selectedRegion.boundsJson);
                    const updateBounds = (
                      patch: Partial<typeof b>,
                    ) => {
                      const next = { ...b, ...patch };
                      updateSnapshot((prev) => ({
                        ...prev,
                        regions: prev.regions.map((r) =>
                          r.regionCode === selectedRegion.regionCode
                            ? { ...r, boundsJson: serializeRegionBounds(next) }
                            : r,
                        ),
                      }));
                    };
                    return (
                      <div className="grid grid-cols-2 gap-2">
                        <div>
                          <Label>Tọa độ X [0..1]</Label>
                          <Input
                            type="number"
                            step="0.01"
                            disabled={isReadOnly}
                            value={b.x}
                            onChange={(e) =>
                              updateBounds({ x: Number(e.target.value) })
                            }
                          />
                        </div>
                        <div>
                          <Label>Tọa độ Y [0..1]</Label>
                          <Input
                            type="number"
                            step="0.01"
                            disabled={isReadOnly}
                            value={b.y}
                            onChange={(e) =>
                              updateBounds({ y: Number(e.target.value) })
                            }
                          />
                        </div>
                        <div>
                          <Label>Chiều rộng [0..1]</Label>
                          <Input
                            type="number"
                            step="0.01"
                            disabled={isReadOnly}
                            value={b.width}
                            onChange={(e) =>
                              updateBounds({ width: Number(e.target.value) })
                            }
                          />
                        </div>
                        <div>
                          <Label>Chiều cao [0..1]</Label>
                          <Input
                            type="number"
                            step="0.01"
                            disabled={isReadOnly}
                            value={b.height}
                            onChange={(e) =>
                              updateBounds({ height: Number(e.target.value) })
                            }
                          />
                        </div>
                      </div>
                    );
                  })()}
                </div>
              )}

              {/* 5.3 Scene Layer Inspector */}
              {selectedLayer && (
                <div className="space-y-3">
                  <div className="flex items-center justify-between border-b border-border pb-2">
                    <div>
                      <span className="text-[10px] font-bold uppercase text-blue-700">
                        LỚP CẢNH QUAN (SCENE LAYER)
                      </span>
                      <h4 className="font-mono text-sm font-bold text-ink">
                        {selectedLayer.layerKey}
                      </h4>
                    </div>
                    {!isReadOnly && (
                      <Button
                        size="sm"
                        variant="ghost"
                        className="text-error hover:bg-error/10"
                        onClick={() => {
                          updateSnapshot((prev) => ({
                            ...prev,
                            sceneLayers: prev.sceneLayers.filter(
                              (l) => l.layerKey !== selectedLayer.layerKey,
                            ),
                          }));
                          setSelected(null);
                        }}
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    )}
                  </div>

                  <div>
                    <Label>Mã lớp (layerKey)</Label>
                    <Input
                      disabled={isReadOnly}
                      value={selectedLayer.layerKey}
                      onChange={(e) => {
                        const nk = e.target.value.trim();
                        if (!nk) return;
                        updateSnapshot((prev) => ({
                          ...prev,
                          sceneLayers: prev.sceneLayers.map((l) =>
                            l.layerKey === selectedLayer.layerKey
                              ? { ...l, layerKey: nk }
                              : l,
                          ),
                        }));
                        setSelected({ type: "SCENE_LAYER", key: nk });
                      }}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <Label>Loại Layer (layerType)</Label>
                      <select
                        disabled={isReadOnly}
                        value={selectedLayer.layerType}
                        onChange={(e) => {
                          const lt = e.target
                            .value as SceneLayerDto["layerType"];
                          updateSnapshot((prev) => ({
                            ...prev,
                            sceneLayers: prev.sceneLayers.map((l) =>
                              l.layerKey === selectedLayer.layerKey
                                ? { ...l, layerType: lt }
                                : l,
                            ),
                          }));
                        }}
                        className="h-9 w-full rounded-md border border-border bg-white px-2 text-xs"
                      >
                        <option value="ANIMATED_WATER">ANIMATED_WATER</option>
                        <option value="STATIC_IMAGE">STATIC_IMAGE</option>
                        <option value="AMBIENT_OVERLAY">AMBIENT_OVERLAY</option>
                        <option value="REGION_OVERLAY">REGION_OVERLAY</option>
                        <option value="ITEM_LAYER">ITEM_LAYER</option>
                        <option value="FALLBACK_GRAPHICS">
                          FALLBACK_GRAPHICS
                        </option>
                      </select>
                    </div>
                    <div>
                      <Label>Thứ tự Render</Label>
                      <Input
                        type="number"
                        disabled={isReadOnly}
                        value={selectedLayer.renderOrder}
                        onChange={(e) => {
                          const ro = Number(e.target.value) || 0;
                          updateSnapshot((prev) => ({
                            ...prev,
                            sceneLayers: prev.sceneLayers.map((l) =>
                              l.layerKey === selectedLayer.layerKey
                                ? { ...l, renderOrder: ro }
                                : l,
                            ),
                          }));
                        }}
                      />
                    </div>
                  </div>

                  <div>
                    <Label>Đường dẫn Asset (assetRef)</Label>
                    <Input
                      disabled={isReadOnly}
                      placeholder="assets/images/... hoặc /api/v1/assets/{id}/content"
                      value={selectedLayer.assetRef ?? ""}
                      onChange={(e) => {
                        const ar = e.target.value;
                        updateSnapshot((prev) => ({
                          ...prev,
                          sceneLayers: prev.sceneLayers.map((l) =>
                            l.layerKey === selectedLayer.layerKey
                              ? { ...l, assetRef: ar }
                              : l,
                          ),
                        }));
                      }}
                    />
                  </div>

                  {(() => {
                    const rule = parseVisibilityRule(
                      selectedLayer.visibilityRuleJson,
                    );
                    const updateRule = (patch: Partial<typeof rule>) => {
                      const next = { ...rule, ...patch };
                      updateSnapshot((prev) => ({
                        ...prev,
                        sceneLayers: prev.sceneLayers.map((l) =>
                          l.layerKey === selectedLayer.layerKey
                            ? {
                                ...l,
                                visibilityRuleJson:
                                  serializeVisibilityRule(next),
                              }
                            : l,
                        ),
                      }));
                    };
                    return (
                      <div className="grid grid-cols-2 gap-2">
                        <div>
                          <Label>Hiện từ Tier tối thiểu</Label>
                          <select
                            disabled={isReadOnly}
                            value={rule.minTier}
                            onChange={(e) =>
                              updateRule({ minTier: Number(e.target.value) })
                            }
                            className="h-9 w-full rounded-md border border-border bg-white px-2 text-xs"
                          >
                            <option value={1}>Tier 1</option>
                            <option value={2}>Tier 2</option>
                            <option value={3}>Tier 3</option>
                          </select>
                        </div>
                        <div>
                          <Label>Đến Tier tối đa</Label>
                          <select
                            disabled={isReadOnly}
                            value={rule.maxTier}
                            onChange={(e) =>
                              updateRule({ maxTier: Number(e.target.value) })
                            }
                            className="h-9 w-full rounded-md border border-border bg-white px-2 text-xs"
                          >
                            <option value={1}>Tier 1</option>
                            <option value={2}>Tier 2</option>
                            <option value={3}>Tier 3</option>
                          </select>
                        </div>
                      </div>
                    );
                  })()}
                </div>
              )}
            </div>
          )}
        </aside>
      </div>

      {/* Confirmation Modal for Publishing */}
      {showPublishModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border border-border bg-white p-6 shadow-xl">
            <h3 className="text-lg font-bold text-ink">
              Xác nhận xuất bản bố cục v{meta.versionNumber}
            </h3>
            <p className="mt-2 text-xs leading-relaxed text-ink-muted">
              Khi xuất bản <strong>{meta.layoutName}</strong> (Phiên bản{" "}
              <strong>v{meta.versionNumber}</strong>):
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5 text-xs text-ink">
              <li>
                Hệ thống sẽ tự động kiểm tra toàn bộ quy tắc Tier 1/2/3 (4/8/12 slot), vùng đất và lớp cảnh quan.
              </li>
              <li>
                Phiên bản đang PUBLISHED trước đó (nếu có) sẽ được chuyển sang trạng thái{" "}
                <strong>ARCHIVED</strong>.
              </li>
              <li>
                Phiên bản v{meta.versionNumber} sau khi xuất bản sẽ bất biến (immutable) để bảo toàn vị trí vật phẩm của người học.
              </li>
            </ul>

            <div className="mt-6 flex justify-end gap-2">
              <Button
                variant="secondary"
                onClick={() => setShowPublishModal(false)}
              >
                Hủy
              </Button>
              <Button
                disabled={publishMutation.isPending}
                onClick={() => publishMutation.mutate()}
              >
                {publishMutation.isPending
                  ? "Đang kiểm tra & xuất bản..."
                  : `Xuất bản v${meta.versionNumber}`}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
