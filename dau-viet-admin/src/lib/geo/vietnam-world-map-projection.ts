/** Shared Vietnam World Map projection — keep in sync with Flutter. */

export const VIETNAM_WORLD_MAP = {
  designWidth: 1458.101,
  designHeight: 2838.058,
  northLat: 23.393,
  southLat: 8.179,
  westLng: 102.144,
  eastLng: 109.464,
  rasterSrc: "/maps/vietnam_relief_location_map.png",
  attribution:
    "Bản đồ địa hình Việt Nam — Wikimedia Commons, Uwe Dedering (CC BY-SA 3.0)",
} as const;

export function isReliableGeographic(lat: number, lng: number): boolean {
  return lat >= 6 && lat <= 24.5 && lng > 100 && lng <= 112;
}

export function geoToWorld(lat: number, lng: number): { x: number; y: number } {
  const x =
    ((lng - VIETNAM_WORLD_MAP.westLng) /
      (VIETNAM_WORLD_MAP.eastLng - VIETNAM_WORLD_MAP.westLng)) *
    VIETNAM_WORLD_MAP.designWidth;
  const y =
    ((VIETNAM_WORLD_MAP.northLat - lat) /
      (VIETNAM_WORLD_MAP.northLat - VIETNAM_WORLD_MAP.southLat)) *
    VIETNAM_WORLD_MAP.designHeight;
  return { x, y };
}

export function worldToGeo(x: number, y: number): { lat: number; lng: number } {
  const lng =
    VIETNAM_WORLD_MAP.westLng +
    (x / VIETNAM_WORLD_MAP.designWidth) *
      (VIETNAM_WORLD_MAP.eastLng - VIETNAM_WORLD_MAP.westLng);
  const lat =
    VIETNAM_WORLD_MAP.northLat -
    (y / VIETNAM_WORLD_MAP.designHeight) *
      (VIETNAM_WORLD_MAP.northLat - VIETNAM_WORLD_MAP.southLat);
  return { lat, lng };
}

export function screenToWorld(
  screenX: number,
  screenY: number,
  scale: number,
  translateX: number,
  translateY: number,
): { x: number; y: number } {
  return {
    x: (screenX - translateX) / scale,
    y: (screenY - translateY) / scale,
  };
}
