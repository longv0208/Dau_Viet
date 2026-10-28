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

type CameraDirectionIndex = 0 | 1 | 2 | 3;

const CAMERA_DIRECTIONS: Array<{
  index: CameraDirectionIndex;
  label: string;
  shortCode: string;
}> = [
  { index: 0, label: "Đông Bắc", shortCode: "ĐB" },
  { index: 1, label: "Đông Nam", shortCode: "ĐN" },
  { index: 2, label: "Tây Nam", shortCode: "TN" },
  { index: 3, label: "Tây Bắc", shortCode: "TB" },
];

function toViewCoord(
  row: number,
  col: number,
  rows: number,
  cols: number,
  dir: CameraDirectionIndex,
): { vRow: number; vCol: number } {
  const maxR = Math.max(rows - 1, 0);
  const maxC = Math.max(cols - 1, 0);
  switch (dir) {
    case 0:
      return { vRow: row, vCol: col };
    case 1:
      return { vRow: col, vCol: maxR - row };
    case 2:
      return { vRow: maxR - row, vCol: maxC - col };
    case 3:
      return { vRow: maxC - col, vCol: row };
  }
}

function rotateConnections(
  n: boolean,
  e: boolean,
  s: boolean,
  w: boolean,
  dir: CameraDirectionIndex,
) {
  switch (dir) {
    case 0:
      return { ne: n, se: e, sw: s, nw: w };
    case 1:
      return { ne: w, se: n, sw: e, nw: s };
    case 2:
      return { ne: s, se: w, sw: n, nw: e };
    case 3:
      return { ne: e, se: s, sw: w, nw: n };
  }
}

const TERRAIN_STYLES: Record<
  TerrainType,
  { base: string; highlight: string; border: string; label: string }
> = {
  GRASS: {
    base: "#7DB04E",
    highlight: "#94C765",
    border: "#6C9D41",
    label: "Cỏ xanh",
  },
  DIRT: {
    base: "#7DB04E",
    highlight: "#94C765",
    border: "#6C9D41",
    label: "Sân đình",
  },
  STONE: {
    base: "#74857F",
    highlight: "#8FA19B",
    border: "#5E6E69",
    label: "Đá xanh",
  },
  PATH: {
    base: "#7DB04E",
    highlight: "#94C765",
    border: "#6C9446",
    label: "Đường gạch làng",
  },
  DECORATIVE: {
    base: "#79AB4C",
    highlight: "#92C464",
    border: "#66943C",
    label: "Tiểu cảnh",
  },
  WATER: {
    base: "#5CAFB9",
    highlight: "#7AC9D2",
    border: "#3D8C9F",
    label: "Mặt nước",
  },
};

function isPlazaTile(t?: TileDto): boolean {
  return Boolean(t && t.terrainType === "DIRT" && !t.slotId);
}

function isPathNeighbor(t?: TileDto): boolean {
  if (!t) return false;
  return (
    t.terrainType === "PATH" ||
    t.terrainType === "STONE" ||
    isPlazaTile(t)
  );
}

function resolveAutotiledTerrainSprite(
  tile: TileDto,
  tileMap: Map<string, TileDto>,
  dir: CameraDirectionIndex,
): string | null {
  const r = tile.row;
  const c = tile.col;
  const grassVariant = () => {
    const hash = Math.abs(r * 7 + c * 13) % 3;
    if (hash === 1) return "/assets/island/terrain/tile_grass_02.png";
    if (hash === 2) return "/assets/island/terrain/tile_grass_03.png";
    return "/assets/island/terrain/tile_grass_01.png";
  };

  switch (tile.terrainType) {
    case "WATER":
      return null;
    case "STONE":
      return "/assets/island/terrain/tile_stone_terrace.png";
    case "DIRT": {
      const nP = isPlazaTile(tileMap.get(`${r - 1}_${c}`));
      const eP = isPlazaTile(tileMap.get(`${r}_${c + 1}`));
      const sP = isPlazaTile(tileMap.get(`${r + 1}_${c}`));
      const wP = isPlazaTile(tileMap.get(`${r}_${c - 1}`));
      if (tile.slotId && !nP && !eP && !sP && !wP) {
        return grassVariant();
      }
      const rotP = rotateConnections(nP, eP, sP, wP, dir);
      const isOddRot = dir === 1 || dir === 3;
      if (rotP.se && rotP.sw) {
        return isOddRot
          ? "/assets/island/terrain/path_plaza_quad_nw_alt.png"
          : "/assets/island/terrain/path_plaza_quad_nw.png";
      }
      if (rotP.sw && rotP.nw) {
        return isOddRot
          ? "/assets/island/terrain/path_plaza_quad_ne_alt.png"
          : "/assets/island/terrain/path_plaza_quad_ne.png";
      }
      if (rotP.nw && rotP.ne) {
        return isOddRot
          ? "/assets/island/terrain/path_plaza_quad_se_alt.png"
          : "/assets/island/terrain/path_plaza_quad_se.png";
      }
      if (rotP.ne && rotP.se) {
        return isOddRot
          ? "/assets/island/terrain/path_plaza_quad_sw_alt.png"
          : "/assets/island/terrain/path_plaza_quad_sw.png";
      }
      return (r + c) % 2 === 0
        ? "/assets/island/terrain/path_plaza_center_01.png"
        : "/assets/island/terrain/path_plaza_center_02.png";
    }
    case "PATH": {
      let n = isPathNeighbor(tileMap.get(`${r - 1}_${c}`));
      let e = isPathNeighbor(tileMap.get(`${r}_${c + 1}`));
      let s = isPathNeighbor(tileMap.get(`${r + 1}_${c}`));
      let w = isPathNeighbor(tileMap.get(`${r}_${c - 1}`));
      const count = Number(n) + Number(e) + Number(s) + Number(w);
      if (count < 2) {
        if (!n && tileMap.get(`${r - 1}_${c}`)?.slotId) n = true;
        if (!e && tileMap.get(`${r}_${c + 1}`)?.slotId) e = true;
        if (!s && tileMap.get(`${r + 1}_${c}`)?.slotId) s = true;
        if (!w && tileMap.get(`${r}_${c - 1}`)?.slotId) w = true;
      }
      const vc = rotateConnections(n, e, s, w, dir);
      const vcCount = Number(vc.ne) + Number(vc.se) + Number(vc.sw) + Number(vc.nw);
      const alt = Math.abs(r * 3 + c * 5) % 2 === 1;

      if (vcCount === 4) {
        return alt
          ? "/assets/island/terrain/path_crossroad_02.png"
          : "/assets/island/terrain/path_crossroad_01.png";
      }
      if (vcCount === 3) {
        if (!vc.nw) return "/assets/island/terrain/path_tjunction_no_nw.png";
        if (!vc.ne) return "/assets/island/terrain/path_tjunction_no_ne.png";
        if (!vc.se) return "/assets/island/terrain/path_tjunction_no_se.png";
        return "/assets/island/terrain/path_tjunction_no_sw.png";
      }
      if (vcCount === 2) {
        if (vc.ne && vc.sw) {
          return alt
            ? "/assets/island/terrain/path_straight_ne_sw_02.png"
            : "/assets/island/terrain/path_straight_ne_sw_01.png";
        }
        if (vc.nw && vc.se) {
          return alt
            ? "/assets/island/terrain/path_straight_nw_se_02.png"
            : "/assets/island/terrain/path_straight_nw_se_01.png";
        }
        if (vc.ne && vc.se) return "/assets/island/terrain/path_corner_ne_se.png";
        if (vc.se && vc.sw) return "/assets/island/terrain/path_corner_se_sw.png";
        if (vc.sw && vc.nw) return "/assets/island/terrain/path_corner_sw_nw.png";
        return "/assets/island/terrain/path_corner_nw_ne.png";
      }
      if (vcCount === 1) {
        if (vc.ne) return "/assets/island/terrain/path_endcap_ne.png";
        if (vc.se) return "/assets/island/terrain/path_endcap_se.png";
        if (vc.sw) return "/assets/island/terrain/path_endcap_sw.png";
        return "/assets/island/terrain/path_endcap_nw.png";
      }
      return alt
        ? "/assets/island/terrain/path_straight_ne_sw_02.png"
        : "/assets/island/terrain/path_straight_ne_sw_01.png";
    }
    case "GRASS":
    case "DECORATIVE":
    default:
      return grassVariant();
  }
}

function resolveScenerySprite(tile: TileDto): {
  href: string;
  wScale: number;
  hScale: number;
  yOffsetRatio: number;
} | null {
  const key = ((tile.decorKey || tile.visualKey || "") as string)
    .toLowerCase()
    .trim();

  if (!key && tile.terrainType !== "DECORATIVE") return null;

  if (key.includes("bamboo") || key.includes("tre")) {
    const isLarge = (tile.row + tile.col) % 2 === 0;
    return {
      href: isLarge
        ? "/assets/island/scenery/bamboo_grove_large.png"
        : "/assets/island/scenery/bamboo_grove_small.png",
      wScale: isLarge ? 1.05 : 0.92,
      hScale: isLarge ? 2.1 : 1.85,
      yOffsetRatio: 0.14,
    };
  }
  if (key.includes("lotus") || key.includes("sen")) {
    return {
      href: "/assets/island/scenery/lotus_pond_cluster.png",
      wScale: 0.96,
      hScale: 1.18,
      yOffsetRatio: 0.18,
    };
  }
  if (key.includes("rice") || key.includes("lua")) {
    return {
      href: "/assets/island/scenery/rice_paddy_patch.png",
      wScale: 0.96,
      hScale: 1.08,
      yOffsetRatio: 0.22,
    };
  }
  if (key.includes("banyan") || key.includes("da_co") || key.includes("sapling")) {
    return {
      href: "/assets/island/scenery/banyan_sapling.png",
      wScale: 1.15,
      hScale: 2.15,
      yOffsetRatio: 0.14,
    };
  }
  if (key.includes("shrub") || key.includes("bush")) {
    return {
      href: "/assets/island/scenery/flowering_shrub.png",
      wScale: 0.88,
      hScale: 1.38,
      yOffsetRatio: 0.14,
    };
  }
  if (key.includes("flower") || key.includes("hoa")) {
    return {
      href: "/assets/island/scenery/wildflowers_patch.png",
      wScale: 0.92,
      hScale: 1.05,
      yOffsetRatio: 0.2,
    };
  }
  if (key.includes("lamp") || key.includes("lantern") || key.includes("den")) {
    return {
      href: "/assets/island/scenery/stone_lantern.png",
      wScale: 0.72,
      hScale: 1.55,
      yOffsetRatio: 0.12,
    };
  }
  if (key.includes("well") || key.includes("gieng")) {
    return {
      href: "/assets/island/scenery/ancient_stone_well.png",
      wScale: 0.86,
      hScale: 1.45,
      yOffsetRatio: 0.15,
    };
  }
  if (key.includes("brick") || key.includes("jar") || key.includes("chum")) {
    const useWell = (tile.row + tile.col) % 2 === 1;
    return {
      href: useWell
        ? "/assets/island/scenery/ancient_stone_well.png"
        : "/assets/island/scenery/terracotta_jars_fence.png",
      wScale: 0.86,
      hScale: 1.42,
      yOffsetRatio: 0.15,
    };
  }
  if (key.includes("stone") || key.includes("rock")) {
    return {
      href: "/assets/island/scenery/mossy_rock_cluster.png",
      wScale: 0.88,
      hScale: 1.28,
      yOffsetRatio: 0.16,
    };
  }

  return {
    href: "/assets/island/scenery/flowering_shrub.png",
    wScale: 0.86,
    hScale: 1.35,
    yOffsetRatio: 0.14,
  };
}

export function IslandIsometricCanvas({
  board,
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
  const [cameraDirection, setCameraDirection] = useState<CameraDirectionIndex>(0);

  const tileW = board.tileWidth || 104;
  const tileH = board.tileHeight || 52;
  const halfW = tileW * 0.5;
  const halfH = tileH * 0.5;
  const cliffDepth = Math.max(20, tileH * 0.44);

  const totalRows = board.rows || 10;
  const totalCols = board.cols || 10;

  const sceneW = (totalRows + totalCols) * halfW + tileW * 2.4;
  const sceneH = (totalRows + totalCols) * halfH + tileH * 4.5;
  const originX = sceneW * 0.5;
  const originY = tileH * 2.2;

  const tileMap = useMemo(() => {
    const map = new Map<string, TileDto>();
    for (const t of board.tiles) {
      map.set(`${t.row}_${t.col}`, t);
    }
    return map;
  }, [board.tiles]);

  // Depth-sorted tiles in active camera viewpoint (painter's algorithm)
  const sortedTiles = useMemo(() => {
    return [...board.tiles].sort((a, b) => {
      const va = toViewCoord(a.row, a.col, totalRows, totalCols, cameraDirection);
      const vb = toViewCoord(b.row, b.col, totalRows, totalCols, cameraDirection);
      const depthA = va.vRow + va.vCol;
      const depthB = vb.vRow + vb.vCol;
      if (depthA !== depthB) return depthA - depthB;
      return va.vRow - vb.vRow;
    });
  }, [board.tiles, totalRows, totalCols, cameraDirection]);

  // Set of existing view-space coordinates for cliff edge detection
  const existingViewCoords = useMemo(() => {
    const set = new Set<string>();
    for (const t of board.tiles) {
      const v = toViewCoord(t.row, t.col, totalRows, totalCols, cameraDirection);
      set.add(`${v.vRow}_${v.vCol}`);
    }
    return set;
  }, [board.tiles, totalRows, totalCols, cameraDirection]);

  const toScreen = useCallback(
    (row: number, col: number) => {
      const { vRow, vCol } = toViewCoord(
        row,
        col,
        totalRows,
        totalCols,
        cameraDirection,
      );
      const isoX = (vCol - vRow) * halfW + originX;
      const isoY = (vCol + vRow) * halfH + originY;
      return { x: isoX, y: isoY, vRow, vCol };
    },
    [halfW, halfH, originX, originY, totalRows, totalCols, cameraDirection],
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
        background:
          "radial-gradient(ellipse 88% 72% at 50% 46%, #8CE2EC 0%, #68C6D2 36%, #459EAE 68%, #297384 100%)",
      }}
      onMouseLeave={() => {
        setHoveredCoord(null);
        setIsMouseDown(false);
      }}
      onMouseUp={() => setIsMouseDown(false)}
    >
      {/* Top-Right Isometric Viewpoint Rotation Pod (10A) */}
      <div className="absolute top-4 right-4 z-20 flex items-center gap-1.5 bg-amber-50/95 text-stone-800 px-2.5 py-1.5 rounded-full text-xs border border-amber-300 shadow-md">
        <button
          type="button"
          onClick={() =>
            setCameraDirection(((cameraDirection + 3) % 4) as CameraDirectionIndex)
          }
          className="px-2 py-0.5 rounded-full hover:bg-amber-200/70 font-semibold transition-colors"
          title="Xoay góc nhìn sang trái (-90°)"
        >
          ↺
        </button>
        <button
          type="button"
          onClick={() =>
            setCameraDirection(((cameraDirection + 1) % 4) as CameraDirectionIndex)
          }
          className="px-2 py-0.5 rounded-full bg-amber-100 hover:bg-amber-200 font-bold text-amber-900 transition-colors"
          title="Đổi góc nhìn Isometric"
        >
          🧭 {CAMERA_DIRECTIONS[cameraDirection].label}
        </button>
        <button
          type="button"
          onClick={() =>
            setCameraDirection(((cameraDirection + 1) % 4) as CameraDirectionIndex)
          }
          className="px-2 py-0.5 rounded-full hover:bg-amber-200/70 font-semibold transition-colors"
          title="Xoay góc nhìn sang phải (+90°)"
        >
          ↻
        </button>
        {cameraDirection !== 0 && (
          <button
            type="button"
            onClick={() => setCameraDirection(0)}
            className="ml-1 px-2 py-0.5 rounded-full bg-stone-200 hover:bg-stone-300 text-stone-700 font-medium transition-colors"
            title="Về góc nhìn mặc định (Đông Bắc)"
          >
            Mặc định
          </button>
        )}
      </div>

      {/* Transform Container with Pan & Zoom */}
      <div
        className="absolute left-1/2 top-1/2 transition-transform duration-150 origin-top-left"
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
              <feGaussianBlur stdDeviation="11" result="blur" />
            </filter>
            <filter id="shallow-glow" x="-40%" y="-40%" width="180%" height="180%">
              <feGaussianBlur stdDeviation="16" result="blur" />
            </filter>
            <radialGradient id="slot-glow" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#F5CD6A" stopOpacity="0.85" />
              <stop offset="60%" stopColor="#F5CD6A" stopOpacity="0.28" />
              <stop offset="100%" stopColor="#F5CD6A" stopOpacity="0" />
            </radialGradient>
          </defs>

          {/* 1. Shallow Lagoon Aura & Organic Drop Shadow on Water */}
          <g>
            {board.tiles.map((t) => {
              const pos = toScreen(t.row, t.col);
              return (
                <ellipse
                  key={`lagoon_${t.key}`}
                  cx={pos.x}
                  cy={pos.y + tileH * 0.35}
                  rx={tileW * 0.92}
                  ry={tileH * 0.72}
                  fill="#A6EFF5"
                  opacity="0.32"
                  filter="url(#shallow-glow)"
                />
              );
            })}
            {board.tiles.map((t) => {
              const pos = toScreen(t.row, t.col);
              return (
                <ellipse
                  key={`sh_${t.key}`}
                  cx={pos.x}
                  cy={pos.y + tileH * 0.85}
                  rx={tileW * 0.62}
                  ry={tileH * 0.42}
                  fill="#174450"
                  opacity="0.38"
                  filter="url(#soft-shadow)"
                />
              );
            })}
          </g>

          {/* 2. Render Tiles, Stratified Cliffs, Autotiled Path Sprites & 2.5D Scenery in Depth Order */}
          {sortedTiles.map((tile) => {
            const pos = toScreen(tile.row, tile.col);
            const isLocked =
              previewTier !== null && tile.unlockTier > previewTier;
            const isSelected = selectedTileKey === tile.key;
            const isHovered =
              hoveredCoord?.row === tile.row && hoveredCoord?.col === tile.col;

            const style = TERRAIN_STYLES[tile.terrainType] || TERRAIN_STYLES.GRASS;
            const terrainSprite = resolveAutotiledTerrainSprite(
              tile,
              tileMap,
              cameraDirection,
            );
            const scenerySpec = !tile.slotId ? resolveScenerySprite(tile) : null;

            const baseColor = isLocked ? "#628678" : style.base;
            const highlightColor = isLocked ? "#7A9E90" : style.highlight;

            // 4 points of diamond
            const topPt = `${pos.x},${pos.y - halfH}`;
            const rightPt = `${pos.x + halfW},${pos.y}`;
            const bottomPt = `${pos.x},${pos.y + halfH}`;
            const leftPt = `${pos.x - halfW},${pos.y}`;

            const diamondPoints = `${topPt} ${rightPt} ${bottomPt} ${leftPt}`;

            // Check cliff edges in active viewpoint (South-West and South-East)
            const hasSW = existingViewCoords.has(`${pos.vRow + 1}_${pos.vCol}`);
            const hasSE = existingViewCoords.has(`${pos.vRow}_${pos.vCol + 1}`);

            const sandH = 5;

            return (
              <g
                key={tile.key}
                opacity={isLocked ? 0.72 : 1}
                onMouseEnter={() => {
                  setHoveredCoord({ row: tile.row, col: tile.col });
                  if (isMouseDown) {
                    handleTileInteraction(tile, tile.row, tile.col);
                  }
                }}
                onClick={() => handleTileInteraction(tile, tile.row, tile.col)}
                className="cursor-pointer"
              >
                {/* Southwest Cliff Face (Sunlit Warm Earth + Sand Base) */}
                {!hasSW && (
                  <g>
                    <polygon
                      points={`${leftPt} ${bottomPt} ${pos.x},${pos.y + halfH + cliffDepth} ${pos.x - halfW},${pos.y + cliffDepth}`}
                      fill={isLocked ? "#576E68" : "#9E6D43"}
                    />
                    <polygon
                      points={`${pos.x - halfW},${pos.y + cliffDepth - sandH} ${pos.x},${pos.y + halfH + cliffDepth - sandH} ${pos.x},${pos.y + halfH + cliffDepth} ${pos.x - halfW},${pos.y + cliffDepth}`}
                      fill={isLocked ? "#697E78" : "#DFC689"}
                    />
                  </g>
                )}

                {/* Southeast Cliff Face (Shaded Deep Earth + Sand Base) */}
                {!hasSE && (
                  <g>
                    <polygon
                      points={`${bottomPt} ${rightPt} ${pos.x + halfW},${pos.y + cliffDepth} ${pos.x},${pos.y + halfH + cliffDepth}`}
                      fill={isLocked ? "#455B56" : "#784E2C"}
                    />
                    <polygon
                      points={`${pos.x},${pos.y + halfH + cliffDepth - sandH} ${pos.x + halfW},${pos.y + cliffDepth - sandH} ${pos.x + halfW},${pos.y + cliffDepth} ${pos.x},${pos.y + halfH + cliffDepth}`}
                      fill={isLocked ? "#566B66" : "#C4AC6E"}
                    />
                  </g>
                )}

                {/* Underlay Diamond Face */}
                <polygon
                  points={diamondPoints}
                  fill={isHovered ? highlightColor : baseColor}
                  stroke={
                    isSelected
                      ? "#F5CD6A"
                      : isHovered
                      ? "#FFFFFF"
                      : "rgba(92, 132, 62, 0.25)"
                  }
                  strokeWidth={isSelected ? 2.5 : isHovered ? 1.8 : 0.8}
                />

                {/* 2.5D Handcrafted Autotiled Terrain / Path Diamond Sprite */}
                {terrainSprite && (
                  <image
                    href={terrainSprite}
                    x={pos.x - tileW * 0.53}
                    y={pos.y - tileH * 0.53}
                    width={tileW * 1.06}
                    height={tileH * 1.06}
                    preserveAspectRatio="none"
                    pointerEvents="none"
                  />
                )}

                {/* Selection / Hover Diamond Rim */}
                {(isSelected || isHovered) && (
                  <polygon
                    points={diamondPoints}
                    fill="none"
                    stroke={isSelected ? "#F5CD6A" : "#FFF8EC"}
                    strokeWidth={isSelected ? 2.6 : 1.6}
                    pointerEvents="none"
                  />
                )}

                {/* Buildable Parcel Plinth (2.5D Sprite) */}
                {tile.slotId && (
                  <g pointerEvents="none">
                    {isSelected && (
                      <ellipse
                        cx={pos.x}
                        cy={pos.y}
                        rx={halfW * 0.8}
                        ry={halfH * 0.8}
                        fill="url(#slot-glow)"
                      />
                    )}
                    <image
                      href="/assets/island/scenery/buildable_parcel_plinth.png"
                      x={pos.x - tileW * 0.43}
                      y={pos.y - tileH * 0.43}
                      width={tileW * 0.86}
                      height={tileH * 0.86}
                      preserveAspectRatio="xMidYMid meet"
                    />
                    {isLocked && (
                      <g>
                        <rect
                          x={pos.x - 16}
                          y={pos.y - 9}
                          width={32}
                          height={15}
                          rx={7.5}
                          fill="#2D3B36"
                          stroke="#D9B978"
                          strokeWidth={1}
                        />
                        <text
                          x={pos.x}
                          y={pos.y + 1.5}
                          textAnchor="middle"
                          fill="#FFF3D6"
                          fontSize={8.5}
                          fontWeight="bold"
                        >
                          Cấp {tile.unlockTier}
                        </text>
                      </g>
                    )}
                  </g>
                )}

                {/* 2.5D Handcrafted Scenery Sprite */}
                {scenerySpec && (
                  <g pointerEvents="none">
                    <ellipse
                      cx={pos.x}
                      cy={pos.y + tileH * 0.08}
                      rx={tileW * scenerySpec.wScale * 0.28}
                      ry={tileH * 0.22}
                      fill="#1B2A1A"
                      opacity={0.26}
                    />
                    <image
                      href={scenerySpec.href}
                      x={pos.x - (tileW * scenerySpec.wScale) / 2}
                      y={
                        pos.y +
                        tileH * scenerySpec.yOffsetRatio -
                        tileH * scenerySpec.hScale
                      }
                      width={tileW * scenerySpec.wScale}
                      height={tileH * scenerySpec.hScale}
                      preserveAspectRatio="xMidYBottom meet"
                    />
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
          Góc nhìn: <strong>{CAMERA_DIRECTIONS[cameraDirection].label}</strong>
        </span>
        <span className="text-slate-500">•</span>
        <span>
          Tổng Tile: <strong>{board.tiles.length}</strong>
        </span>
        <span className="text-slate-500">•</span>
        <span>
          Ô Xây Dựng: <strong>{slots.length}</strong>
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
