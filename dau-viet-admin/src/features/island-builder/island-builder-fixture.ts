import type { BoardDto, TileDto } from "./island-builder-api";

export function createDefaultIsometricBoard(
  rows: number = 10,
  cols: number = 10,
  tileWidth: number = 84,
  tileHeight: number = 42,
): BoardDto {
  const tiles: TileDto[] = [];
  let slotCounter = 0;

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      slotCounter++;
      let unlockTier = 3;
      let regionCode = "TIER_3";

      if (r >= 2 && r <= 7 && c >= 2 && c <= 7) {
        unlockTier = 1;
        regionCode = "TIER_1";
      } else if (r >= 1 && r <= 8 && c >= 1 && c <= 8) {
        unlockTier = 2;
        regionCode = "TIER_2";
      }

      let terrain: TileDto["terrainType"] = "GRASS";
      const decorKey: string | null = null;
      const slotId: string | null = `slot_${slotCounter}`;
      let elevation = 0;

      if (r >= 3 && r <= 4 && c >= 3 && c <= 4) {
        terrain = "DIRT";
        elevation = 1;
      } else if (
        (r === 5 && c >= 1 && c <= 8) ||
        (c === 5 && r >= 1 && c <= 8)
      ) {
        terrain = "PATH";
      } else if ((r === 0 || r === rows - 1) && (c === 0 || c === cols - 1)) {
        terrain = "STONE";
      }

      tiles.push({
        key: `tile_${r}_${c}`,
        row: r,
        col: c,
        terrainType: terrain,
        regionCode,
        unlockTier,
        elevation,
        decorKey,
        slotId,
      });
    }
  }

  return {
    rows,
    cols,
    tileWidth,
    tileHeight,
    tiles,
  };
}
