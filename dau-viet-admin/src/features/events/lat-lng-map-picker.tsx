"use client";

import { useMemo, useRef, useState } from "react";
import {
  geoToWorld,
  isReliableGeographic,
  VIETNAM_WORLD_MAP,
  worldToGeo,
} from "@/lib/geo/vietnam-world-map-projection";
import { cn } from "@/lib/utils";

export interface LatLng {
  lat: number;
  lng: number;
}

interface KnownPlace {
  id: string;
  title: string;
  lat: number;
  lng: number;
}

interface LatLngMapPickerProps {
  /** WGS84 latitude / longitude. null = chưa chọn. */
  value: LatLng | null;
  onChange: (v: LatLng) => void;
  /** Giữ prop cũ — World Map không dùng ảnh sự kiện để lưu tọa độ. */
  imageSrc?: string;
  imageLabel?: string;
  height?: number;
  knownPlaces?: KnownPlace[];
}

const DISPLAY_WIDTH = 420;

export function LatLngMapPicker({
  value,
  onChange,
  imageLabel,
  height = 460,
  knownPlaces = [],
}: LatLngMapPickerProps) {
  const mapRef = useRef<HTMLDivElement>(null);
  const [search, setSearch] = useState("");
  const displayScale = DISPLAY_WIDTH / VIETNAM_WORLD_MAP.designWidth;
  const displayHeight = VIETNAM_WORLD_MAP.designHeight * displayScale;

  const hasGeo = value != null && isReliableGeographic(value.lat, value.lng);
  const marker = useMemo(() => {
    if (!hasGeo || !value) return null;
    return geoToWorld(value.lat, value.lng);
  }, [hasGeo, value]);

  const toLatLng = (clientX: number, clientY: number): LatLng | null => {
    const el = mapRef.current;
    if (!el) return null;
    const r = el.getBoundingClientRect();
    if (r.width <= 0 || r.height <= 0) return null;
    const world = {
      x: ((clientX - r.left) / r.width) * VIETNAM_WORLD_MAP.designWidth,
      y: ((clientY - r.top) / r.height) * VIETNAM_WORLD_MAP.designHeight,
    };
    const geo = worldToGeo(world.x, world.y);
    return { lat: round4(geo.lat), lng: round4(geo.lng) };
  };

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const next = toLatLng(e.clientX, e.clientY);
    if (next) onChange(next);
  };

  const handleMarkerDown = (e: React.PointerEvent<HTMLButtonElement>) => {
    e.preventDefault();
    e.stopPropagation();
    const move = (ev: PointerEvent) => {
      const next = toLatLng(ev.clientX, ev.clientY);
      if (next) onChange(next);
    };
    const up = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
  };

  const filteredPlaces = knownPlaces.filter((p) =>
    p.title.toLowerCase().includes(search.trim().toLowerCase()),
  );

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Tìm địa điểm đã có trên bản đồ…"
          className="h-9 min-w-[12rem] flex-1 rounded-md border border-border bg-white px-2 text-sm"
        />
      </div>
      {search.trim() && filteredPlaces.length > 0 && (
        <ul className="max-h-28 overflow-auto rounded-md border border-border bg-white text-sm">
          {filteredPlaces.slice(0, 8).map((p) => (
            <li key={p.id}>
              <button
                type="button"
                className="w-full px-2 py-1 text-left hover:bg-muted"
                onClick={() => onChange({ lat: p.lat, lng: p.lng })}
              >
                {p.title}
              </button>
            </li>
          ))}
        </ul>
      )}
      <div
        className="overflow-auto rounded-md border border-border bg-[#d7e4ec]"
        style={{ height }}
      >
        <div
          ref={mapRef}
          role="application"
          aria-label="Chọn vị trí địa điểm trên bản đồ Việt Nam"
          onClick={handleClick}
          className="relative cursor-crosshair"
          style={{ width: DISPLAY_WIDTH, height: displayHeight }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={VIETNAM_WORLD_MAP.rasterSrc}
            alt={imageLabel ?? "Bản đồ địa hình Việt Nam"}
            draggable={false}
            className="absolute inset-0 h-full w-full select-none"
          />
          {marker && (
            <button
              type="button"
              aria-label="Vị trí đã chọn — kéo để chỉnh"
              onPointerDown={handleMarkerDown}
              onClick={(e) => e.stopPropagation()}
              style={{
                left: marker.x * displayScale,
                top: marker.y * displayScale,
                transform: "translate(-50%, -50%)",
              }}
              className={cn(
                "absolute h-5 w-5 cursor-grab rounded-full border-2 border-white",
                "bg-red-700 shadow-[0_1px_4px_rgba(0,0,0,0.45)]",
                "ring-2 ring-red-700/40 active:cursor-grabbing",
              )}
            />
          )}
        </div>
      </div>
      <p className="text-xs text-ink-muted">
        {hasGeo && value
          ? `${value.lat.toFixed(4)}°N, ${value.lng.toFixed(4)}°E`
          : "Chưa xác định vị trí — bấm lên bản đồ Việt Nam để chọn tọa độ địa lý."}{" "}
        {VIETNAM_WORLD_MAP.attribution}
      </p>
    </div>
  );
}

function round4(n: number): number {
  return Math.round(n * 10000) / 10000;
}
