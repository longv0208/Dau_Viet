import type { BoardDto, TileDto } from "./island-builder-api";

export function createDefaultIsometricBoard(
  rows: number = 8,
  cols: number = 8,
  tileWidth: number = 84,
  tileHeight: number = 42,
): BoardDto {
  const tiles: TileDto[] = [];

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      let unlockTier = 3;
      let regionCode = "TIER_3";

      if (r >= 2 && r <= 5 && c >= 2 && c <= 5) {
        unlockTier = 1;
        regionCode = "TIER_1";
      } else if (r >= 1 && r <= 6 && c >= 1 && c <= 6) {
        unlockTier = 2;
        regionCode = "TIER_2";
      }

      let terrain: TileDto["terrainType"] = "GRASS";
      const decorKey: string | null = null;
      let slotId: string | null = null;
      let elevation = 0;

      if (r >= 2 && r <= 3 && c >= 2 && c <= 3) {
        terrain = "DIRT";
        elevation = 1;
      } else if (
        (r === 4 && c >= 1 && c <= 6) ||
        (c === 4 && r >= 1 && r <= 6)
      ) {
        terrain = "PATH";
      } else if ((r === 0 || r === rows - 1) && (c === 0 || c === cols - 1)) {
        terrain = "STONE";
      }

      if (r === 2 && c === 2) {
        slotId = "SLOT_DINH_LANG";
      } else if (r === 3 && c === 2) {
        slotId = "SLOT_NHA_TRANH";
      } else if (r === 2 && c === 4) {
        slotId = "SLOT_CAU_KIEU";
      } else if (r === 4 && c === 5) {
        slotId = "SLOT_HO_SEN";
      } else if (r === 6 && c === 2) {
        slotId = "SLOT_CAY_DA";
      } else if (r === 1 && c === 3) {
        slotId = "SLOT_CONG_LANG";
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
