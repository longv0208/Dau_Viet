"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  Copy,
  Eye,
  Grid,
  Layers,
  Lock,
  MapPin,
  Paintbrush,
  PanelLeftClose,
  PanelLeftOpen,
  PanelRightClose,
  PanelRightOpen,
  Plus,
  RotateCcw,
  Save,
  Trash2,
  Undo2,
  ZoomIn,
  ZoomOut,
  Eraser,
  Sparkles,
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
  type BoardDto,
  type RegionDto,
  type SceneLayerDto,
  type SlotDto,
  type TerrainType,
  type TileDto,
  type ValidationErrorDto,
  type VersionDetailDto,
} from "./island-builder-api";
import { IslandIsometricCanvas } from "./island-isometric-canvas";
import { createDefaultIsometricBoard } from "./island-builder-fixture";

interface DraftSnapshotState {
  canvasWidth: number;
  canvasHeight: number;
  themeKey: string;
  regions: RegionDto[];
  sceneLayers: SceneLayerDto[];
  slots: SlotDto[];
  board: BoardDto;
}

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

const TERRAIN_CONFIGS: {
  type: TerrainType;
  label: string;
  color: string;
  desc: string;
}[] = [
  { type: "GRASS", label: "Cỏ xanh", color: "bg-[#8FBA63]", desc: "Mặt cỏ xanh mềm dịu" },
  { type: "DIRT", label: "Đất vàng", color: "bg-[#9B744B]", desc: "Nền đất ấm đặt công trình" },
  { type: "STONE", label: "Đá khối", color: "bg-[#74857F]", desc: "Phiến đá tự nhiên cổ kính" },
  { type: "PATH", label: "Đường gạch", color: "bg-[#B86644]", desc: "Lối đi gạch đất nung nối liền" },
  { type: "DECORATIVE", label: "Tiểu cảnh", color: "bg-[#7EA858]", desc: "Bụi tre, ao sen, đèn đá" },
  { type: "WATER", label: "Mặt nước", color: "bg-[#5CAFB9]", desc: "Mặt nước ngọc bích ven đảo" },
];

export function IslandBuilderWorkspace({ versionId }: { versionId: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const qc = useQueryClient();

  const initialPreview = searchParams?.get("mode") === "preview";

  const [snapshot, setSnapshot] = useState<DraftSnapshotState | null>(null);
  const [rowVersion, setRowVersion] = useState<number>(0);
  const [undoStack, setUndoStack] = useState<DraftSnapshotState[]>([]);
  const [isDirty, setIsDirty] = useState(false);

  // Tools & Selection
  const [activeTool, setActiveTool] = useState<"SELECT" | "BRUSH" | "ERASE" | "SLOT">("BRUSH");
  const [activeTerrainBrush, setActiveTerrainBrush] = useState<TerrainType>("GRASS");
  const [activeRegionCode, setActiveRegionCode] = useState<string>("TIER_1");
  const [selectedTileKey, setSelectedTileKey] = useState<string | null>(null);

  // Panels Collapse
  const [leftCollapsed, setLeftCollapsed] = useState(false);
  const [rightCollapsed, setRightCollapsed] = useState(false);

  // Canvas Controls
  const [zoom, setZoom] = useState(0.85);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [previewTier, setPreviewTier] = useState<number | null>(initialPreview ? 1 : null);

  // Grid Dimensions (Issue #50: mặc định 10x10 đồng tâm 6x6 / 8x8 / 10x10)
  const [gridRowsInput, setGridRowsInput] = useState<number>(10);
  const [gridColsInput, setGridColsInput] = useState<number>(10);
  const [validationErrors, setValidationErrors] = useState<ValidationErrorDto[]>([]);
  const [validationPassed, setValidationPassed] = useState<boolean | null>(null);
  const [bannerMessage, setBannerMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);
  const [showPublishModal, setShowPublishModal] = useState(false);

  const versionQuery = useQuery({
    queryKey: ["admin-island-version", versionId],
    queryFn: () => islandBuilderApi.getVersion(versionId),
  });

  useEffect(() => {
    if (versionQuery.data && !snapshot) {
      const d = versionQuery.data;
      const board = d.board || createDefaultIsometricBoard(10, 10, 84, 42);
      setSnapshot({
        canvasWidth: d.canvasWidth || 960,
        canvasHeight: d.canvasHeight || 720,
        themeKey: d.themeKey || "heritage",
        regions: d.regions || [],
        sceneLayers: d.sceneLayers || [],
        slots: d.slots || [],
        board,
      });
      setRowVersion(d.rowVersion);
      setGridRowsInput(board.rows);
      setGridColsInput(board.cols);
      setIsDirty(false);
      if (d.status !== "DRAFT" && previewTier === null) {
        setPreviewTier(1);
      }
    }
  }, [versionQuery.data, snapshot, previewTier]);

  function pushUndo() {
    if (!snapshot) return;
    setUndoStack((prev) => [...prev.slice(-20), structuredClone(snapshot)]);
  }

  function handleUndo() {
    setUndoStack((stack) => {
      if (stack.length === 0) return stack;
      const last = stack[stack.length - 1];
      if (!last) return stack;
      setSnapshot(last);
      setIsDirty(true);
      return stack.slice(0, -1);
    });
  }

  // Cập nhật thuộc tính của một tile
  const handleUpdateTile = (tileKey: string, updates: Partial<TileDto>) => {
    if (!snapshot) return;
    pushUndo();

    const updatedTiles = snapshot.board.tiles.map((t) => {
      if (t.key === tileKey) {
        return { ...t, ...updates };
      }
      return t;
    });

    setSnapshot({
      ...snapshot,
      board: {
        ...snapshot.board,
        tiles: updatedTiles,
      },
    });
    setIsDirty(true);
  };

  // Thêm một tile mới vào lưới
  const handleAddTile = (row: number, col: number) => {
    if (!snapshot) return;
    pushUndo();

    const newKey = `tile_${row}_${col}`;
    const newTile: TileDto = {
      key: newKey,
      row,
      col,
      terrainType: activeTerrainBrush,
      regionCode: activeRegionCode,
      unlockTier: activeRegionCode === "TIER_3" ? 3 : activeRegionCode === "TIER_2" ? 2 : 1,
      elevation: 0,
    };

    setSnapshot({
      ...snapshot,
      board: {
        ...snapshot.board,
        tiles: [...snapshot.board.tiles.filter((t) => t.key !== newKey), newTile],
      },
    });
    setIsDirty(true);
  };

  // Xóa một tile khỏi lưới
  const handleDeleteTile = (tileKey: string) => {
    if (!snapshot) return;
    pushUndo();

    setSnapshot({
      ...snapshot,
      board: {
        ...snapshot.board,
        tiles: snapshot.board.tiles.filter((t) => t.key !== tileKey),
      },
    });
    if (selectedTileKey === tileKey) {
      setSelectedTileKey(null);
    }
    setIsDirty(true);
  };

  // Thay đổi kích thước lưới rows x cols
  const handleResizeGrid = () => {
    if (!snapshot) return;
    const r = Math.max(6, Math.min(24, gridRowsInput));
    const c = Math.max(6, Math.min(24, gridColsInput));
    pushUndo();

    setSnapshot({
      ...snapshot,
      board: {
        ...snapshot.board,
        rows: r,
        cols: c,
        tiles: snapshot.board.tiles.filter((t) => t.row < r && t.col < c),
      },
    });
    setIsDirty(true);
  };

  const selectedTile = useMemo(() => {
    if (!snapshot || !selectedTileKey) return null;
    return snapshot.board.tiles.find((t) => t.key === selectedTileKey) || null;
  }, [snapshot, selectedTileKey]);

  // Mutations
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
        board: snapshot.board,
      });
    },
    onSuccess: (saved: VersionDetailDto) => {
      setRowVersion(saved.rowVersion);
      setSnapshot((prev) => (prev ? { ...prev, board: saved.board || prev.board } : null));
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
          board: snapshot.board,
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
          text: "Kiểm tra hợp lệ: Bản đồ Isometric đạt chuẩn xuất bản!",
        });
      } else {
        setBannerMessage({
          type: "error",
          text: `Phát hiện ${report.errors.length} lỗi bố cục.`,
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
          board: snapshot.board,
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
      setBannerMessage({ type: "error", text: toUserMessage(err) });
    },
  });

  if (versionQuery.isLoading) {
    return (
      <div className="p-8 space-y-4">
        <Skeleton className="h-12 w-1/3" />
        <Skeleton className="h-[600px] w-full" />
      </div>
    );
  }

  if (versionQuery.isError || !versionQuery.data) {
    return (
      <div className="p-8">
        <ErrorState
          error={versionQuery.error}
          onRetry={() => void versionQuery.refetch()}
        />
      </div>
    );
  }

  const vData = versionQuery.data;
  const isDraft = vData.status === "DRAFT";

  return (
    <div className="flex flex-col h-[calc(100vh-4rem)] bg-slate-950 text-slate-100 overflow-hidden select-none">
      {/* 1. Header Toolbar */}
      <header className="h-14 bg-slate-900 border-b border-slate-800 px-4 flex items-center justify-between shrink-0 z-20">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => router.push(`/island-builder/${vData.definitionId}`)}
            className="text-slate-400 hover:text-slate-100"
          >
            <ArrowLeft className="w-4 h-4 mr-1.5" />
            Quay lại
          </Button>
          <div className="h-4 w-px bg-slate-800" />
          <div>
            <h1 className="text-sm font-bold flex items-center gap-2">
              <span>{vData.layoutName}</span>
              <span className="text-xs px-2 py-0.5 rounded font-mono bg-slate-800 text-amber-400">
                v{vData.versionNumber}
              </span>
              <span
                className={cn(
                  "text-xs px-2 py-0.5 rounded font-medium",
                  vData.status === "PUBLISHED"
                    ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                    : "bg-amber-500/20 text-amber-400 border border-amber-500/30",
                )}
              >
                {vData.status}
              </span>
            </h1>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-2">
          {bannerMessage && (
            <div
              className={cn(
                "text-xs px-3 py-1 rounded-md flex items-center gap-1.5 max-w-sm truncate",
                bannerMessage.type === "success"
                  ? "bg-emerald-950/80 text-emerald-300 border border-emerald-800"
                  : "bg-rose-950/80 text-rose-300 border border-rose-800",
              )}
            >
              {bannerMessage.text}
            </div>
          )}

          <Button
            variant="outline"
            size="sm"
            onClick={handleUndo}
            disabled={undoStack.length === 0}
            className="border-slate-700 text-slate-300"
          >
            <Undo2 className="w-4 h-4 mr-1" />
            Undo
          </Button>

          {isDraft && (
            <>
              <Button
                variant="outline"
                size="sm"
                onClick={() => saveMutation.mutate()}
                disabled={!isDirty || saveMutation.isPending}
                className="border-slate-700 text-slate-200"
              >
                <Save className="w-4 h-4 mr-1.5" />
                {saveMutation.isPending ? "Đang lưu..." : isDirty ? "Lưu Nháp *" : "Đã Lưu"}
              </Button>

              <Button
                variant="outline"
                size="sm"
                onClick={() => validateMutation.mutate()}
                disabled={validateMutation.isPending}
                className="border-amber-600/60 text-amber-400 hover:bg-amber-950/40"
              >
                Kiểm tra hợp lệ
              </Button>

              <Button
                size="sm"
                onClick={() => setShowPublishModal(true)}
                className="bg-emerald-600 hover:bg-emerald-500 text-white font-semibold"
              >
                Xuất Bản
              </Button>
            </>
          )}
        </div>
      </header>

      {/* 2. Main 3-Panel Layout */}
      <div className="flex-1 flex overflow-hidden relative">
        {/* Panel Trái — Toolbox */}
        <div
          className={cn(
            "bg-slate-900 border-r border-slate-800 flex flex-col shrink-0 transition-all duration-200 z-10",
            leftCollapsed ? "w-12" : "w-72",
          )}
        >
          <div className="h-10 px-3 border-b border-slate-800 flex items-center justify-between">
            {!leftCollapsed && (
              <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">
                Hộp Công Cụ
              </span>
            )}
            <button
              onClick={() => setLeftCollapsed(!leftCollapsed)}
              className="p-1 rounded hover:bg-slate-800 text-slate-400"
            >
              {leftCollapsed ? <PanelLeftOpen className="w-4 h-4" /> : <PanelLeftClose className="w-4 h-4" />}
            </button>
          </div>

          {!leftCollapsed && (
            <div className="flex-1 overflow-y-auto p-3.5 space-y-5 text-xs">
              {/* Chế độ vẽ / chọn */}
              <div>
                <Label className="text-slate-400 block mb-2 font-semibold">Chế độ Thao tác</Label>
                <div className="grid grid-cols-2 gap-1.5">
                  <Button
                    variant={activeTool === "BRUSH" ? "default" : "outline"}
                    size="sm"
                    onClick={() => setActiveTool("BRUSH")}
                    className={cn(
                      "justify-start text-xs",
                      activeTool === "BRUSH" && "bg-amber-600 hover:bg-amber-500",
                    )}
                  >
                    <Paintbrush className="w-3.5 h-3.5 mr-1.5" />
                    Cọ vẽ
                  </Button>
                  <Button
                    variant={activeTool === "SELECT" ? "default" : "outline"}
                    size="sm"
                    onClick={() => setActiveTool("SELECT")}
                    className={cn(
                      "justify-start text-xs",
                      activeTool === "SELECT" && "bg-amber-600 hover:bg-amber-500",
                    )}
                  >
                    <MapPin className="w-3.5 h-3.5 mr-1.5" />
                    Chọn Tile
                  </Button>
                  <Button
                    variant={activeTool === "SLOT" ? "default" : "outline"}
                    size="sm"
                    onClick={() => setActiveTool("SLOT")}
                    className={cn(
                      "justify-start text-xs",
                      activeTool === "SLOT" && "bg-amber-600 hover:bg-amber-500",
                    )}
                  >
                    <Plus className="w-3.5 h-3.5 mr-1.5" />
                    Đặt Slot
                  </Button>
                  <Button
                    variant={activeTool === "ERASE" ? "default" : "outline"}
                    size="sm"
                    onClick={() => setActiveTool("ERASE")}
                    className={cn(
                      "justify-start text-xs",
                      activeTool === "ERASE" && "bg-rose-700 hover:bg-rose-600",
                    )}
                  >
                    <Eraser className="w-3.5 h-3.5 mr-1.5" />
                    Xóa Tile
                  </Button>
                </div>
              </div>

              {/* Bảng cọ Terrain */}
              <div>
                <Label className="text-slate-400 block mb-2 font-semibold">Địa hình (Terrain Brush)</Label>
                <div className="space-y-1.5">
                  {TERRAIN_CONFIGS.map((cfg) => (
                    <button
                      key={cfg.type}
                      onClick={() => {
                        setActiveTerrainBrush(cfg.type);
                        setActiveTool("BRUSH");
                      }}
                      className={cn(
                        "w-full px-2.5 py-1.5 rounded flex items-center justify-between border text-left transition-colors",
                        activeTerrainBrush === cfg.type && activeTool === "BRUSH"
                          ? "border-amber-400 bg-slate-800"
                          : "border-slate-800 hover:bg-slate-800/60 text-slate-300",
                      )}
                    >
                      <div className="flex items-center gap-2">
                        <span className={cn("w-3.5 h-3.5 rounded-sm", cfg.color)} />
                        <span>{cfg.label}</span>
                      </div>
                      <span className="text-[10px] text-slate-500">{cfg.type}</span>
                    </button>
                  ))}
                </div>
              </div>

              {/* Vùng đất gán mặc định */}
              <div>
                <Label className="text-slate-400 block mb-2 font-semibold">Khu vực Gán (Region)</Label>
                <div className="grid grid-cols-3 gap-1">
                  {[
                    { code: "TIER_1", label: "An Lạc (T1)" },
                    { code: "TIER_2", label: "Phồn Thịnh (T2)" },
                    { code: "TIER_3", label: "Trường Tồn (T3)" },
                  ].map((item) => (
                    <Button
                      key={item.code}
                      variant={activeRegionCode === item.code ? "default" : "outline"}
                      size="sm"
                      onClick={() => setActiveRegionCode(item.code)}
                      className={cn(
                        "text-[11px] p-1 h-8",
                        activeRegionCode === item.code && "bg-emerald-600 hover:bg-emerald-500",
                      )}
                    >
                      {item.label}
                    </Button>
                  ))}
                </div>
              </div>

              {/* Kích thước lưới */}
              <div className="border-t border-slate-800 pt-3">
                <Label className="text-slate-400 block mb-2 font-semibold">Kích thước Lưới (Hàng × Cột)</Label>
                <div className="flex items-center gap-2">
                  <Input
                    type="number"
                    min={6}
                    max={24}
                    value={gridRowsInput}
                    onChange={(e) => setGridRowsInput(Number(e.target.value))}
                    className="h-8 text-xs bg-slate-950 border-slate-700"
                  />
                  <span>×</span>
                  <Input
                    type="number"
                    min={6}
                    max={24}
                    value={gridColsInput}
                    onChange={(e) => setGridColsInput(Number(e.target.value))}
                    className="h-8 text-xs bg-slate-950 border-slate-700"
                  />
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={handleResizeGrid}
                    className="h-8 text-xs border-slate-700 shrink-0"
                  >
                    Đổi
                  </Button>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Panel Giữa — Isometric Map Canvas */}
        <div className="flex-1 flex flex-col relative overflow-hidden">
          {/* Canvas Floating Top Controls */}
          <div className="absolute top-3 left-4 z-10 flex items-center gap-2 bg-slate-900/90 p-1.5 rounded-lg border border-slate-800 shadow-lg backdrop-blur-md">
            <span className="text-xs text-slate-400 px-2 font-semibold">Xem trước Cấp:</span>
            <Button
              size="sm"
              variant={previewTier === null ? "default" : "ghost"}
              onClick={() => setPreviewTier(null)}
              className="h-7 text-xs px-2.5"
            >
              Tất cả
            </Button>
            {[
              { tier: 1, label: "Đảo Nhỏ" },
              { tier: 2, label: "Đảo Vừa" },
              { tier: 3, label: "Đảo Lớn" },
            ].map((item) => (
              <Button
                key={item.tier}
                size="sm"
                variant={previewTier === item.tier ? "default" : "ghost"}
                onClick={() => setPreviewTier(item.tier)}
                className="h-7 text-xs px-2.5"
              >
                {item.label}
              </Button>
            ))}
          </div>

          <div className="absolute top-3 right-4 z-10 flex items-center gap-1.5 bg-slate-900/90 p-1 rounded-lg border border-slate-800 shadow-lg backdrop-blur-md">
            <Button
              size="sm"
              variant="ghost"
              onClick={() => setZoom((z) => Math.max(0.4, Number((z - 0.1).toFixed(2))))}
              className="h-7 w-7 p-0"
              title="Thu nhỏ"
            >
              <ZoomOut className="w-3.5 h-3.5" />
            </Button>
            <span className="text-xs font-mono w-10 text-center text-slate-300">
              {Math.round(zoom * 100)}%
            </span>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => setZoom((z) => Math.min(2.0, Number((z + 0.1).toFixed(2))))}
              className="h-7 w-7 p-0"
              title="Phóng to"
            >
              <ZoomIn className="w-3.5 h-3.5" />
            </Button>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => {
                setZoom(0.85);
                setPan({ x: 0, y: 0 });
              }}
              className="h-7 px-2 text-xs"
              title="Đặt lại góc nhìn"
            >
              Căn giữa
            </Button>
          </div>

          {/* Isometric Interactive Canvas */}
          {snapshot && (
            <IslandIsometricCanvas
              board={snapshot.board}
              regions={snapshot.regions}
              slots={snapshot.slots}
              selectedTileKey={selectedTileKey}
              activeTool={activeTool}
              activeTerrainBrush={activeTerrainBrush}
              previewTier={previewTier}
              zoom={zoom}
              pan={pan}
              onSelectTile={(t) => setSelectedTileKey(t ? t.key : null)}
              onUpdateTile={handleUpdateTile}
              onAddTile={handleAddTile}
              onDeleteTile={handleDeleteTile}
            />
          )}
        </div>

        {/* Panel Phải — Inspector */}
        <div
          className={cn(
            "bg-slate-900 border-l border-slate-800 flex flex-col shrink-0 transition-all duration-200 z-10",
            rightCollapsed ? "w-12" : "w-80",
          )}
        >
          <div className="h-10 px-3 border-b border-slate-800 flex items-center justify-between">
            <button
              onClick={() => setRightCollapsed(!rightCollapsed)}
              className="p-1 rounded hover:bg-slate-800 text-slate-400"
            >
              {rightCollapsed ? <PanelRightClose className="w-4 h-4" /> : <PanelRightOpen className="w-4 h-4" />}
            </button>
            {!rightCollapsed && (
              <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">
                Thuộc Tính & Kiểm Tra
              </span>
            )}
          </div>

          {!rightCollapsed && (
            <div className="flex-1 overflow-y-auto p-4 space-y-5 text-xs">
              {selectedTile ? (
                <div className="space-y-4">
                  <div className="bg-slate-950 p-3 rounded-lg border border-slate-800">
                    <h3 className="font-bold text-amber-300 text-sm mb-1">
                      Tile [{selectedTile.row}, {selectedTile.col}]
                    </h3>
                    <p className="text-slate-400 text-[11px]">Key: {selectedTile.key}</p>
                  </div>

                  {/* Chọn Terrain */}
                  <div>
                    <Label className="text-slate-400 block mb-1.5 font-semibold">Loại Địa hình</Label>
                    <select
                      value={selectedTile.terrainType}
                      onChange={(e) =>
                        handleUpdateTile(selectedTile.key, {
                          terrainType: e.target.value as TerrainType,
                        })
                      }
                      className="w-full h-8 px-2 bg-slate-950 border border-slate-700 rounded text-xs text-slate-200"
                    >
                      {TERRAIN_CONFIGS.map((c) => (
                        <option key={c.type} value={c.type}>
                          {c.label} ({c.type})
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* Tiểu cảnh Tự nhiên (Scenery Decor) */}
                  <div>
                    <Label className="text-slate-400 block mb-1.5 font-semibold">Tiểu Cảnh Tự Nhiên</Label>
                    <select
                      value={selectedTile.decorKey || selectedTile.visualKey || ""}
                      onChange={(e) =>
                        handleUpdateTile(selectedTile.key, {
                          decorKey: e.target.value || null,
                          visualKey: e.target.value || null,
                        })
                      }
                      className="w-full h-8 px-2 bg-slate-950 border border-slate-700 rounded text-xs text-slate-200"
                    >
                      <option value="">-- Mặc định theo địa hình --</option>
                      <option value="bamboo">Bụi Tre Làng Cổ (bamboo)</option>
                      <option value="lotus">Ao Sen Nhỏ (lotus)</option>
                      <option value="lantern">Đèn Đá Sân Đình (lantern)</option>
                      <option value="well">Giếng Làng Cổ (well)</option>
                      <option value="rice">Thửa Ruộng Lúa (rice)</option>
                      <option value="flower">Khóm Hoa Dại (flower)</option>
                      <option value="rock">Tảng Đá Rêu Phong (rock)</option>
                      <option value="tree">Cây Nhỏ Bóng Mát (tree)</option>
                    </select>
                  </div>

                  {/* Chọn Region / Tier */}
                  <div>
                    <Label className="text-slate-400 block mb-1.5 font-semibold">Khu vực & Mở khóa</Label>
                    <div className="grid grid-cols-3 gap-1">
                      {[1, 2, 3].map((tier) => (
                        <Button
                          key={tier}
                          variant={selectedTile.unlockTier === tier ? "default" : "outline"}
                          size="sm"
                          onClick={() =>
                            handleUpdateTile(selectedTile.key, {
                              unlockTier: tier,
                              regionCode: `TIER_${tier}`,
                            })
                          }
                          className={cn(
                            "h-7 text-xs",
                            selectedTile.unlockTier === tier && "bg-amber-600 hover:bg-amber-500",
                          )}
                        >
                          Cấp {tier}
                        </Button>
                      ))}
                    </div>
                  </div>

                  {/* Buildable Slot Toggle */}
                  <div className="border-t border-slate-800 pt-3">
                    <div className="flex items-center justify-between mb-2">
                      <Label className="text-slate-300 font-semibold">Ô Xây dựng (Buildable Slot)</Label>
                      <input
                        type="checkbox"
                        checked={Boolean(selectedTile.slotId)}
                        onChange={(e) =>
                          handleUpdateTile(selectedTile.key, {
                            slotId: e.target.checked
                              ? `SLOT_${selectedTile.row}_${selectedTile.col}`
                              : null,
                            terrainType: e.target.checked ? "DIRT" : "GRASS",
                          })
                        }
                        className="w-4 h-4 accent-amber-500 rounded"
                      />
                    </div>
                    {selectedTile.slotId && (
                      <div className="bg-slate-950 p-2.5 rounded border border-slate-800 space-y-2">
                        <div>
                          <span className="text-[10px] text-slate-500 block">Mã Slot:</span>
                          <span className="font-mono text-amber-400">{selectedTile.slotId}</span>
                        </div>
                        <div>
                          <span className="text-[10px] text-slate-500 block">Danh mục cho phép:</span>
                          <span className="text-slate-300">DECOR, HERITAGE</span>
                        </div>
                      </div>
                    )}
                  </div>

                  <div className="pt-2">
                    <Button
                      variant="destructive"
                      size="sm"
                      onClick={() => handleDeleteTile(selectedTile.key)}
                      className="w-full text-xs"
                    >
                      <Trash2 className="w-3.5 h-3.5 mr-1.5" />
                      Xóa Tile này
                    </Button>
                  </div>
                </div>
              ) : (
                <div className="text-center py-8 text-slate-500 space-y-2">
                  <MapPin className="w-8 h-8 mx-auto opacity-40" />
                  <p>Chạm vào một ô tile trên bản đồ Isometric để chỉnh sửa thuộc tính.</p>
                </div>
              )}

              {/* Báo cáo Validation */}
              <div className="border-t border-slate-800 pt-4">
                <h4 className="font-bold text-slate-300 mb-2 flex items-center justify-between">
                  <span>Kiểm tra Hợp lệ</span>
                  {validationPassed !== null && (
                    <span
                      className={cn(
                        "text-[10px] px-1.5 py-0.5 rounded font-bold",
                        validationPassed ? "bg-emerald-950 text-emerald-400" : "bg-rose-950 text-rose-400",
                      )}
                    >
                      {validationPassed ? "ĐẠT CHUẨN" : "CÓ LỖI"}
                    </span>
                  )}
                </h4>

                {validationErrors.length > 0 ? (
                  <div className="space-y-1.5 max-h-48 overflow-y-auto">
                    {validationErrors.map((err, i) => (
                      <div
                        key={i}
                        className="bg-rose-950/40 border border-rose-900/60 p-2 rounded text-[11px] text-rose-300"
                      >
                        <div className="font-semibold">{err.code}</div>
                        <div>{err.message}</div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-[11px] text-slate-500">
                    Chưa phát hiện lỗi bố cục. Nhấn &quot;Kiểm tra hợp lệ&quot; trước khi xuất bản.
                  </p>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Modal xác nhận Xuất bản */}
      {showPublishModal && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 max-w-md w-full space-y-4 shadow-2xl">
            <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-amber-400" />
              Xuất bản Bản đồ Đảo Di Sản v{vData.versionNumber}?
            </h3>
            <p className="text-xs text-slate-300 leading-relaxed">
              Bản nháp Isometric sẽ được xuất bản chính thức. Người học trên toàn hệ thống sẽ trải nghiệm bố cục đảo di sản mới này.
            </p>
            <div className="flex justify-end gap-2 pt-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setShowPublishModal(false)}
                className="border-slate-700"
              >
                Hủy
              </Button>
              <Button
                size="sm"
                onClick={() => publishMutation.mutate()}
                disabled={publishMutation.isPending}
                className="bg-emerald-600 hover:bg-emerald-500 text-white font-semibold"
              >
                {publishMutation.isPending ? "Đang xuất bản..." : "Xác nhận Xuất bản"}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
