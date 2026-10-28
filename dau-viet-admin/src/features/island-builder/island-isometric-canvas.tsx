"use client";

import React, { useCallback, useMemo, useState } from "react";
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
    highlight: "#A2CD74",
    border: "#7DA654",
    label: "Cỏ xanh",
  },
  DIRT: {
    base: "#9B744B",
    highlight: "#B48C60",
    border: "#855F37",
    label: "Đất vàng",
  },
  STONE: {
    base: "#74857F",
    highlight: "#8FA19B",
    border: "#5E6E69",
    label: "Đá khối",
  },
  PATH: {
    base: "#B86644",
    highlight: "#CE7B57",
    border: "#984F31",
    label: "Đường gạch",
  },
  DECORATIVE: {
    base: "#82AC5A",
    highlight: "#9CC870",
    border: "#668E3E",
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
  const cliffDepth = 18;

  const totalRows = board.rows || 12;
  const totalCols = board.cols || 12;

  const sceneW = (totalRows + totalCols) * halfW + tileW * 2.0;
  const sceneH = (totalRows + totalCols) * halfH + tileH * 4.0;
  const originX = sceneW * 0.5;
  const originY = tileH * 2.0;

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

  // Helper render mini SVG decor matching Vietnamese diorama
  const renderMiniScenery = (tile: TileDto, cx: number, cy: number) => {
    const key = ((tile.decorKey || tile.visualKey || "") as string).toLowerCase().trim();

    if (key.includes("bamboo") || key.includes("tre")) {
      return (
        <g pointerEvents="none">
          <ellipse cx={cx} cy={cy + 4} rx={8} ry={3} fill="#000000" opacity={0.2} />
          {/* Stalks */}
          <line x1={cx - 3} y1={cy + 3} x2={cx - 4} y2={cy - 12} stroke="#7CB342" strokeWidth={1.8} strokeLinecap="round" />
          <line x1={cx} y1={cy + 4} x2={cx + 1} y2={cy - 15} stroke="#8BC34A" strokeWidth={2} strokeLinecap="round" />
          <line x1={cx + 3} y1={cy + 3} x2={cx + 4} y2={cy - 11} stroke="#689F38" strokeWidth={1.8} strokeLinecap="round" />
          {/* Leaves */}
          <path d={`M ${cx - 4} ${cy - 12} Q ${cx - 10} ${cy - 14} ${cx - 7} ${cy - 9} Z`} fill="#4CAF50" />
          <path d={`M ${cx + 1} ${cy - 15} Q ${cx + 7} ${cy - 18} ${cx + 6} ${cy - 12} Z`} fill="#8BC34A" />
          <path d={`M ${cx + 4} ${cy - 11} Q ${cx + 9} ${cy - 10} ${cx + 6} ${cy - 8} Z`} fill="#4CAF50" />
        </g>
      );
    }

    if (key.includes("lotus") || key.includes("sen")) {
      return (
        <g pointerEvents="none">
          {/* Pond water puddle */}
          <ellipse cx={cx} cy={cy + 1} rx={12} ry={6} fill="#00838F" opacity={0.65} />
          {/* Lilypads */}
          <ellipse cx={cx - 4} cy={cy} rx={4.5} ry={2.5} fill="#388E3C" />
          <ellipse cx={cx + 4} cy={cy + 2} rx={4} ry={2.2} fill="#4CAF50" />
          {/* Pink lotus flower */}
          <circle cx={cx} cy={cy - 1} r={2.8} fill="#E91E63" />
          <circle cx={cx} cy={cy - 1} r={1.2} fill="#FFF59D" />
        </g>
      );
    }

    if (key.includes("lantern") || key.includes("lamp") || key.includes("den")) {
      return (
        <g pointerEvents="none">
          <ellipse cx={cx} cy={cy + 4} rx={6} ry={2.5} fill="#000000" opacity={0.25} />
          {/* Stone post */}
          <rect x={cx - 1.5} y={cy - 3} width={3} height={6} fill="#78909C" />
          {/* Lantern chamber */}
          <rect x={cx - 3} y={cy - 7} width={6} height={4} fill="#F5CD6A" rx={0.5} />
          {/* Stone roof */}
          <polygon points={`${cx - 5},${cy - 7} ${cx},${cy - 11} ${cx + 5},${cy - 7}`} fill="#546E7A" />
        </g>
      );
    }

    if (key.includes("well") || key.includes("gieng")) {
      return (
        <g pointerEvents="none">
          <ellipse cx={cx} cy={cy + 3} rx={9} ry={4.5} fill="#000000" opacity={0.22} />
          {/* Stone well rim */}
          <ellipse cx={cx} cy={cy} rx={8} ry={4.5} fill="#546E7A" stroke="#78909C" strokeWidth={1} />
          <ellipse cx={cx} cy={cy} rx={5} ry={2.8} fill="#00838F" />
          {/* Wooden post & crossbar */}
          <line x1={cx - 5} y1={cy} x2={cx - 5} y2={cy - 8} stroke="#5D4037" strokeWidth={1.4} />
          <line x1={cx + 5} y1={cy} x2={cx + 5} y2={cy - 8} stroke="#5D4037" strokeWidth={1.4} />
          <line x1={cx - 6} y1={cy - 8} x2={cx + 6} y2={cy - 8} stroke="#5D4037" strokeWidth={1.4} />
        </g>
      );
    }

    if (key.includes("rice") || key.includes("lua")) {
      return (
        <g pointerEvents="none">
          <ellipse cx={cx} cy={cy + 2} rx={9} ry={4.5} fill="#6D4C41" opacity={0.3} />
          <line x1={cx - 4} y1={cy + 2} x2={cx - 6} y2={cy - 6} stroke="#7CB342" strokeWidth={1.5} />
          <line x1={cx} y1={cy + 3} x2={cx} y2={cy - 8} stroke="#7CB342" strokeWidth={1.5} />
          <line x1={cx + 4} y1={cy + 2} x2={cx + 6} y2={cy - 6} stroke="#7CB342" strokeWidth={1.5} />
          <circle cx={cx - 6} cy={cy - 6} r={1.5} fill="#F5CD6A" />
          <circle cx={cx} cy={cy - 8} r={1.8} fill="#F5CD6A" />
          <circle cx={cx + 6} cy={cy - 6} r={1.5} fill="#F5CD6A" />
        </g>
      );
    }

    if (key.includes("rock") || key.includes("stone") || key.includes("da")) {
      return (
        <g pointerEvents="none">
          <ellipse cx={cx} cy={cy + 3} rx={8} ry={3.5} fill="#000000" opacity={0.25} />
          <polygon points={`${cx - 7},${cy + 2} ${cx - 5},${cy - 5} ${cx + 1},${cy - 8} ${cx + 7},${cy - 3} ${cx + 6},${cy + 2}`} fill="#607D8B" />
          <polygon points={`${cx - 5},${cy - 5} ${cx + 1},${cy - 8} ${cx + 4},${cy - 4} ${cx - 1},${cy - 3}`} fill="#90A4AE" />
          <ellipse cx={cx} cy={cy - 1} rx={3} ry={1.5} fill="#689F38" />
        </g>
      );
    }

    if (key.includes("tree") || key.includes("cay") || key.includes("banyan") || key.includes("shrub")) {
      return (
        <g pointerEvents="none">
          <ellipse cx={cx} cy={cy + 4} rx={10} ry={4} fill="#000000" opacity={0.25} />
          <line x1={cx} y1={cy + 3} x2={cx} y2={cy - 4} stroke="#4E342E" strokeWidth={2.5} strokeLinecap="round" />
          <circle cx={cx - 4} cy={cy - 6} r={5} fill="#2E7D32" />
          <circle cx={cx + 4} cy={cy - 6} r={4.5} fill="#388E3C" />
          <circle cx={cx} cy={cy - 10} r={5.5} fill="#4CAF50" />
        </g>
      );
    }

    // Default: Khóm hoa rực rỡ
    return (
      <g pointerEvents="none">
        <ellipse cx={cx} cy={cy + 3} rx={8} ry={3.5} fill="#000000" opacity={0.2} />
        <circle cx={cx - 3} cy={cy - 1} r={4} fill="#388E3C" />
        <circle cx={cx + 3} cy={cy - 1} r={3.8} fill="#4CAF50" />
        <circle cx={cx} cy={cy - 4} r={4.2} fill="#66BB6A" />
        <circle cx={cx - 2} cy={cy - 4} r={1.6} fill="#FFD54F" />
        <circle cx={cx + 2} cy={cy - 2} r={1.6} fill="#FF7043" />
      </g>
    );
  };

  return (
    <div
      className="relative w-full h-full select-none overflow-hidden cursor-crosshair"
      style={{
        background: "radial-gradient(ellipse 90% 70% at 50% 45%, #76CAD5 0%, #5CAFB9 45%, #3D8C9F 78%, #286877 100%)",
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
            <filter id="soft-shadow" x="-30%" y="-30%" width="160%" height="160%">
              <feGaussianBlur stdDeviation="9" result="blur" />
            </filter>
            <radialGradient id="slot-glow" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#F5CD6A" stopOpacity="0.8" />
              <stop offset="60%" stopColor="#F5CD6A" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#F5CD6A" stopOpacity="0" />
            </radialGradient>
          </defs>

          {/* 1. Organic Island Drop Shadow on Water */}
          <g opacity="0.40">
            {board.tiles.map((t) => {
              const pos = toScreen(t.row, t.col);
              return (
                <ellipse
                  key={`sh_${t.key}`}
                  cx={pos.x}
                  cy={pos.y + tileH * 0.95}
                  rx={tileW * 0.60}
                  ry={tileH * 0.38}
                  fill="#18414B"
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

            // Micro color variation per tile coordinate
            const seed = Math.sin(tile.row * 12.9898 + tile.col * 78.233) * 43758.5453;
            const jitter = (seed - Math.floor(seed)) - 0.5;

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

            // Shore sandy base strip thickness
            const sandH = 4;

            return (
              <g key={tile.key}>
                {/* Southwest Cliff Face (Sunlit Warm Earth + Sand Base) */}
                {!hasSW && (
                  <g>
                    {/* Main Cliff Wall */}
                    <polygon
                      points={`${leftPt} ${bottomPt} ${pos.x},${pos.y + halfH + cliffDepth} ${pos.x - halfW},${pos.y + cliffDepth}`}
                      fill={isLocked ? "#5A6B69" : "#96683E"}
                      opacity={isLocked ? 0.6 : 1}
                    />
                    {/* Bottom Sand Fringe */}
                    <polygon
                      points={`${pos.x - halfW},${pos.y + cliffDepth - sandH} ${pos.x},${pos.y + halfH + cliffDepth - sandH} ${pos.x},${pos.y + halfH + cliffDepth} ${pos.x - halfW},${pos.y + cliffDepth}`}
                      fill={isLocked ? "#4C5B59" : "#D8BF81"}
                      opacity={isLocked ? 0.5 : 0.9}
                    />
                  </g>
                )}

                {/* Southeast Cliff Face (Shaded Deep Earth + Sand Base) */}
                {!hasSE && (
                  <g>
                    {/* Main Cliff Wall */}
                    <polygon
                      points={`${bottomPt} ${rightPt} ${pos.x + halfW},${pos.y + cliffDepth} ${pos.x},${pos.y + halfH + cliffDepth}`}
                      fill={isLocked ? "#4A5B59" : "#7A512D"}
                      opacity={isLocked ? 0.6 : 1}
                    />
                    {/* Bottom Sand Fringe */}
                    <polygon
                      points={`${pos.x},${pos.y + halfH + cliffDepth - sandH} ${pos.x + halfW},${pos.y + cliffDepth - sandH} ${pos.x + halfW},${pos.y + cliffDepth} ${pos.x},${pos.y + halfH + cliffDepth}`}
                      fill={isLocked ? "#3F4E4C" : "#C2AA6B"}
                      opacity={isLocked ? 0.5 : 0.9}
                    />
                  </g>
                )}

                {/* Top Diamond Face */}
                <polygon
                  points={diamondPoints}
                  fill={isHovered ? highlightColor : baseColor}
                  stroke={strokeColor}
                  strokeWidth={isSelected ? 2.5 : isHovered ? 2 : 1}
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

                {/* Subtle Buildable Slot Foundation Plinth (Replaces loud orange +) */}
                {tile.slotId && (
                  <g pointerEvents="none">
                    {/* Glow aura when selected */}
                    {isSelected && (
                      <ellipse
                        cx={pos.x}
                        cy={pos.y}
                        rx={halfW * 0.75}
                        ry={halfH * 0.75}
                        fill="url(#slot-glow)"
                      />
                    )}
                    {/* Carved diamond foundation pad */}
                    <polygon
                      points={`${pos.x},${pos.y - halfH * 0.45} ${pos.x + halfW * 0.45},${pos.y} ${pos.x},${pos.y + halfH * 0.45} ${pos.x - halfW * 0.45},${pos.y}`}
                      fill={isLocked ? "#475569" : isSelected ? "#FAF5EC" : "#A67A53"}
                      stroke={isSelected ? "#F5CD6A" : "#D4AB7B"}
                      strokeWidth={1.2}
                      opacity={0.88}
                    />
                    {/* Minimalist warm plus mark */}
                    <path
                      d={`M ${pos.x} ${pos.y - 4} L ${pos.x} ${pos.y + 4} M ${pos.x - 4} ${pos.y} L ${pos.x + 4} ${pos.y}`}
                      stroke={isSelected ? "#B65E3F" : "#FFF8EC"}
                      strokeWidth={1.6}
                      strokeLinecap="round"
                    />
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

                {/* Decorative Miniature Scenery (Bamboo, Lotus, Well, Lantern, Flowers, etc.) */}
                {(tile.terrainType === "DECORATIVE" || Boolean(tile.decorKey) || Boolean(tile.visualKey)) && !tile.slotId && (
                  renderMiniScenery(tile, pos.x, pos.y)
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
