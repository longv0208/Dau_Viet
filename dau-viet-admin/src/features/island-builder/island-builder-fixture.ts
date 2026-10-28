import type { BoardDto, TileDto, VersionDetailDto } from "./island-builder-api";

export function createDefaultIsometricBoard(
  rows: number = 12,
  cols: number = 12,
  tileWidth: number = 72,
  tileHeight: number = 36,
): BoardDto {
  const tiles: TileDto[] = [];
  const centerR = (rows - 1) / 2;
  const centerC = (cols - 1) / 2;
  const maxDist = (centerR * 0.88) * (centerR * 0.88);

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const dr = r - centerR;
      const dc = c - centerC;
      const dist = dr * dr * 1.05 + dc * dc * 0.95;

      if (dist <= maxDist) {
        const normDist = dist / maxDist;
        let unlockTier = 1;
        let regionCode = "TIER_1";

        if (normDist > 0.65) {
          unlockTier = 3;
          regionCode = "TIER_3";
        } else if (normDist > 0.35) {
          unlockTier = 2;
          regionCode = "TIER_2";
        }

        let terrain: TileDto["terrainType"] = "GRASS";
        let decorKey: string | null = null;
        let slotId: string | null = null;

        if (r === 5 && c === 5) {
          terrain = "DIRT";
          slotId = "SLOT_DINH_LANG";
        } else if (r === 4 && c === 4) {
          terrain = "DIRT";
          slotId = "SLOT_NHA_TRANH";
        } else if (r === 6 && c === 7) {
          terrain = "DIRT";
          slotId = "SLOT_CAU_KIEU";
        } else if (r === 7 && c === 6) {
          terrain = "WATER";
          slotId = "SLOT_HO_SEN";
        } else if (r === 7 && c === 3) {
          terrain = "DIRT";
          slotId = "SLOT_CAY_DA";
        } else if (r === 3 && c === 3) {
          terrain = "STONE";
          slotId = "SLOT_CONG_LANG";
        } else if (
          (r === 5 && c >= 3 && c <= 7) ||
          (c === 5 && r >= 3 && r <= 7)
        ) {
          terrain = "PATH";
        } else if ((r + c) % 5 === 0 && normDist < 0.6) {
          terrain = "DECORATIVE";
          decorKey = r % 2 === 0 ? "bamboo" : "lotus";
        } else if ((r * 3 + c * 7) % 7 === 0 && normDist >= 0.6) {
          terrain = "STONE";
        }

        tiles.push({
          key: `tile_${r}_${c}`,
          row: r,
          col: c,
          terrainType: terrain,
          regionCode,
          unlockTier,
          elevation: 0,
          decorKey,
          slotId,
        });
      }
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
