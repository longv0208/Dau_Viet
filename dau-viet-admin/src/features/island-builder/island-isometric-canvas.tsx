"use client";

import React, { useCallback, useMemo, useRef, useState } from "react";
import {
  type BoardDto,
  type RegionDto,
  type SlotDto,
  type TerrainType,
  type TileDto,
} from "./island-builder-api";

interface IslandIsometricCanvasProps {
  board: BoardDto;
  regions: RegionDto[];
  slots: SlotDto[];
  selectedTileKey: string | null;
  activeTool: "SELECT" | "BRUSH" | "ERASE" | "SLOT";
  activeTerrainBrush: TerrainType;
  previewTier: number | null;
  zoom: number;
  pan: { x: number; y: number };
  onSelectTile: (tile: TileDto | null) => void;
  onUpdateTile: (tileKey: string, updates: Partial<TileDto>) => void;
  onAddTile: (row: number, col: number) => void;
  onDeleteTile: (tileKey: string) => void;
}

const TERRAIN_STYLES: Record<
  TerrainType,
  { base: string; highlight: string; border: string; label: string }
> = {
  GRASS: {
    base: "#8FBA63",
    highlight: "#A5CF76",
    border: "#6F9845",
    label: "Cỏ xanh",
  },
  DIRT: {
    base: "#9B744B",
    highlight: "#B58C5E",
    border: "#7A5835",
    label: "Đất vàng",
  },
  STONE: {
    base: "#74857F",
    highlight: "#90A19B",
    border: "#596964",
    label: "Đá khối",
  },
  PATH: {
    base: "#B86644",
    highlight: "#CF7F5D",
    border: "#944E31",
    label: "Đường gạch",
  },
  DECORATIVE: {
    base: "#7EA858",
    highlight: "#98C46E",
    border: "#5E853C",
    label: "Tiểu cảnh",
  },
  WATER: {
    base: "#5CAFB9",
    highlight: "#7AC9D2",
    border: "#3D8C9F",
    label: "Mặt nước",
  },
};

export function IslandIsometricCanvas({
  board,
  regions,
  slots,
  selectedTileKey,
  activeTool,
  activeTerrainBrush,
  previewTier,
  zoom,
  pan,
  onSelectTile,
  onUpdateTile,
  onAddTile,
  onDeleteTile,
}: IslandIsometricCanvasProps) {
  const [hoveredCoord, setHoveredCoord] = useState<{
    row: number;
    col: number;
  } | null>(null);
  const [isMouseDown, setIsMouseDown] = useState(false);

  const tileW = board.tileWidth || 72;
  const tileH = board.tileHeight || 36;
  const halfW = tileW * 0.5;
  const halfH = tileH * 0.5;
  const cliffDepth = 16;

  const totalRows = board.rows || 12;
  const totalCols = board.cols || 12;

  const sceneW = (totalRows + totalCols) * halfW + tileW * 2.0;
  const sceneH = (totalRows + totalCols) * halfH + tileH * 4.0;
  const originX = sceneW * 0.5;
  const originY = tileH * 2.0;

  // Map key -> Tile
  const tileMap = useMemo(() => {
    const map = new Map<string, TileDto>();
    for (const t of board.tiles) {
      map.set(`r${t.row}_c${t.col}`, t);
    }
    return map;
  }, [board.tiles]);

  // Map slotId -> SlotDto
  const slotMap = useMemo(() => {
    const map = new Map<string, SlotDto>();
    for (const s of slots) {
      if (s.id) map.set(s.id, s);
      if (s.stableSlotKey) map.set(s.stableSlotKey, s);
    }
    return map;
  }, [slots]);

  // Depth-sorted tiles (painter's algorithm)
  const sortedTiles = useMemo(() => {
    return [...board.tiles].sort((a, b) => {
      const depthA = a.row + a.col;
      const depthB = b.row + b.col;
      if (depthA !== depthB) return depthA - depthB;
      return a.row - b.row;
    });
  }, [board.tiles]);

  // Set of existing coordinates for cliff edge detection
  const existingCoords = useMemo(() => {
    const set = new Set<string>();
    for (const t of board.tiles) {
      set.add(`${t.row}_${t.col}`);
    }
    return set;
  }, [board.tiles]);

  const toScreen = useCallback(
    (row: number, col: number) => {
      const isoX = (col - row) * halfW + originX;
      const isoY = (col + row) * halfH + originY;
      return { x: isoX, y: isoY };
    },
    [halfW, halfH, originX, originY],
  );

  const handleTileInteraction = (tile: TileDto | null, r: number, c: number) => {
    if (activeTool === "SELECT") {
      onSelectTile(tile);
    } else if (activeTool === "BRUSH") {
      if (tile) {
        onUpdateTile(tile.key, { terrainType: activeTerrainBrush });
      } else {
        onAddTile(r, c);
      }
    } else if (activeTool === "ERASE") {
      if (tile) {
        onDeleteTile(tile.key);
      }
    } else if (activeTool === "SLOT") {
      if (tile) {
        onUpdateTile(tile.key, {
          slotId: tile.slotId ? null : `SLOT_${tile.row}_${tile.col}`,
          terrainType: tile.slotId ? "GRASS" : "DIRT",
        });
      }
    }
  };

  return (
    <div
      className="relative w-full h-full select-none overflow-hidden cursor-crosshair"
      style={{
        background: "radial-gradient(circle at 50% 40%, #7AC9D2 0%, #5CAFB9 45%, #3D8C9F 85%, #2E6E7C 100%)",
      }}
      onMouseLeave={() => {
        setHoveredCoord(null);
        setIsMouseDown(false);
      }}
      onMouseUp={() => setIsMouseDown(false)}
    >
      {/* Transform Container with Pan & Zoom */}
      <div
        className="absolute left-1/2 top-1/2 transition-transform duration-75 origin-top-left"
        style={{
          transform: `translate(calc(-50% + ${pan.x}px), calc(-50% + ${pan.y}px)) scale(${zoom})`,
          width: sceneW,
          height: sceneH,
        }}
      >
        <svg
          width={sceneW}
          height={sceneH}
          className="overflow-visible"
          onMouseDown={() => setIsMouseDown(true)}
        >
          <defs>
            <filter id="soft-shadow" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="8" result="blur" />
            </filter>
          </defs>

          {/* 1. Subtle Island Base Drop Shadow on Water */}
          <g opacity="0.35">
            {board.tiles.map((t) => {
              const pos = toScreen(t.row, t.col);
              return (
                <ellipse
                  key={`sh_${t.key}`}
                  cx={pos.x}
                  cy={pos.y + tileH * 0.9}
                  rx={tileW * 0.55}
                  ry={tileH * 0.35}
                  fill="#1E4E59"
                  filter="url(#soft-shadow)"
                />
              );
            })}
          </g>

          {/* 2. Render Tiles and Cliffs in Depth Order */}
          {sortedTiles.map((tile) => {
            const pos = toScreen(tile.row, tile.col);
            const isLocked =
              previewTier !== null && tile.unlockTier > previewTier;
            const isSelected = selectedTileKey === tile.key;
            const isHovered =
              hoveredCoord?.row === tile.row && hoveredCoord?.col === tile.col;

            const style = TERRAIN_STYLES[tile.terrainType] || TERRAIN_STYLES.GRASS;
            const baseColor = isLocked ? "#7A8D8B" : style.base;
            const highlightColor = isLocked ? "#96A6A4" : style.highlight;
            const strokeColor = isSelected
              ? "#F5CD6A"
              : isHovered
              ? "#FFFFFF"
              : style.border;

            // 4 points of diamond
            const topPt = `${pos.x},${pos.y - halfH}`;
            const rightPt = `${pos.x + halfW},${pos.y}`;
            const bottomPt = `${pos.x},${pos.y + halfH}`;
            const leftPt = `${pos.x - halfW},${pos.y}`;

            const diamondPoints = `${topPt} ${rightPt} ${bottomPt} ${leftPt}`;

            // Check cliff edges (South-West and South-East)
            const hasSW = existingCoords.has(`${tile.row + 1}_${tile.col}`);
            const hasSE = existingCoords.has(`${tile.row}_${tile.col + 1}`);

            return (
              <g key={tile.key}>
                {/* Southwest Cliff Face (Left -> Bottom) */}
                {!hasSW && (
                  <polygon
                    points={`${leftPt} ${bottomPt} ${pos.x},${pos.y + halfH + cliffDepth} ${pos.x - halfW},${pos.y + cliffDepth}`}
                    fill={isLocked ? "#5A6B69" : "#8C6239"}
                    opacity={isLocked ? 0.6 : 1}
                  />
                )}

                {/* Southeast Cliff Face (Bottom -> Right) */}
                {!hasSE && (
                  <polygon
                    points={`${bottomPt} ${rightPt} ${pos.x + halfW},${pos.y + cliffDepth} ${pos.x},${pos.y + halfH + cliffDepth}`}
                    fill={isLocked ? "#6A7B79" : "#9E7244"}
                    opacity={isLocked ? 0.6 : 1}
                  />
                )}

                {/* Top Diamond Face */}
                <polygon
                  points={diamondPoints}
                  fill={isHovered ? highlightColor : baseColor}
                  stroke={strokeColor}
                  strokeWidth={isSelected ? 3 : isHovered ? 2 : 1}
                  opacity={isLocked ? 0.65 : 1}
                  onMouseEnter={() => {
                    setHoveredCoord({ row: tile.row, col: tile.col });
                    if (isMouseDown) {
                      handleTileInteraction(tile, tile.row, tile.col);
                    }
                  }}
                  onClick={() =>
                    handleTileInteraction(tile, tile.row, tile.col)
                  }
                  className="cursor-pointer transition-colors duration-75"
                />

                {/* Buildable Slot Indicator */}
                {tile.slotId && (
                  <g pointerEvents="none">
                    <circle
                      cx={pos.x}
                      cy={pos.y}
                      r={isSelected ? 11 : 9}
                      fill={isLocked ? "#475569" : "#D48B47"}
                      stroke="#FFFFFF"
                      strokeWidth={1.5}
                    />
                    <text
                      x={pos.x}
                      y={pos.y + 4}
                      textAnchor="middle"
                      fill="#FFFFFF"
                      fontSize={11}
                      fontWeight="bold"
                    >
                      +
                    </text>
                  </g>
                )}

                {/* Locked Tile Padlock Icon */}
                {isLocked && !tile.slotId && (
                  <g pointerEvents="none" opacity={0.75}>
                    <circle
                      cx={pos.x}
                      cy={pos.y}
                      r={7}
                      fill="#334155"
                      stroke="#94A3B8"
                      strokeWidth={1}
                    />
                    <text
                      x={pos.x}
                      y={pos.y + 3}
                      textAnchor="middle"
                      fill="#E2E8F0"
                      fontSize={8}
                    >
                      🔒
                    </text>
                  </g>
                )}

                {/* Decorative Indicator (bamboo / lotus) */}
                {tile.terrainType === "DECORATIVE" && !tile.slotId && (
                  <g pointerEvents="none" opacity={0.85}>
                    <circle cx={pos.x} cy={pos.y - 2} r={3} fill="#4CAF50" />
                    <circle cx={pos.x - 4} cy={pos.y + 1} r={2.5} fill="#8BC34A" />
                    <circle cx={pos.x + 4} cy={pos.y + 1} r={2.5} fill="#388E3C" />
                  </g>
                )}
              </g>
            );
          })}
        </svg>
      </div>

      {/* Floating Canvas Status HUD */}
      <div className="absolute bottom-4 left-4 z-10 flex items-center gap-3 bg-slate-900/85 text-slate-200 px-3.5 py-1.5 rounded-full text-xs backdrop-blur-md border border-slate-700 shadow-md">
        <span>
          Lưới Isometric: <strong>{totalRows}×{totalCols}</strong>
        </span>
        <span className="text-slate-500">•</span>
        <span>
          Tổng Tile: <strong>{board.tiles.length}</strong>
        </span>
        {hoveredCoord && (
          <>
            <span className="text-slate-500">•</span>
            <span className="text-amber-300 font-mono">
              Tile [{hoveredCoord.row}, {hoveredCoord.col}]
            </span>
          </>
        )}
      </div>
    </div>
  );
}
