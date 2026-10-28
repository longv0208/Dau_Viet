"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { cn } from "@/lib/utils";

export interface LatLng {
  lat: number;
  lng: number;
}

interface LatLngMapPickerProps {
  /**
   * Giá trị hiện tại dạng phần trăm ảnh: lng = x% (0–100 trái→phải),
   * lat = y% (0–100 trên→dưới). null = chưa chọn.
   * Mobile không render theo lat/lng thật mà theo index — picker này
   * chỉ để admin xem trước & lưu vị trí tương đối trên ảnh map.
   */
  value: LatLng | null;
  onChange: (v: LatLng) => void;
  /** Đường dẫn ảnh map của sự kiện (trong /public). */
  imageSrc: string;
  /** Tên bản đồ hiển thị phụ. */
  imageLabel?: string;
  /** Chiều cao khung preview px. Mặc định 320. */
  height?: number;
}

/**
 * Picker click-trên-ảnh — đúng tinh thần map mobile (ảnh lịch sử
 * + node theo %). Click → thả chấm node; click chỗ khác → dời chấm.
 * Kéo-thả chấm cũng được.
 */
export function LatLngMapPicker({
  value,
  onChange,
  imageSrc,
  imageLabel,
  height = 320,
}: LatLngMapPickerProps) {
  const frameRef = useRef<HTMLDivElement>(null);
  const [imgError, setImgError] = useState(false);

  useEffect(() => {
    setImgError(false);
  }, [imageSrc]);

  const displayPos = useMemo(() => {
    if (!value) return null;
    const { lat, lng } = value;
    // Nếu là tọa độ địa lý thực tại Việt Nam (kinh độ > 100°E, vĩ độ 8..24°N),
    // quy đổi sang vị trí tương đối % trên khung bản đồ để không bị dồn sát mép phải (100%).
    if (lng > 100 && lat >= 5 && lat <= 26) {
      const normY = ((23.5 - lat) / (23.5 - 8.5)) * 80 + 10;
      const normX = ((lng - 102) / (109.5 - 102)) * 72 + 14;
      return {
        topPct: Math.min(95, Math.max(5, round2(normY))),
        leftPct: Math.min(95, Math.max(5, round2(normX))),
      };
    }
    return {
      topPct: Math.min(100, Math.max(0, lat)),
      leftPct: Math.min(100, Math.max(0, lng)),
    };
  }, [value]);

  const toPct = (clientX: number, clientY: number): LatLng | null => {
    const el = frameRef.current;
    if (!el) return null;
    const r = el.getBoundingClientRect();
    if (r.width <= 0 || r.height <= 0) return null;
    const x = ((clientX - r.left) / r.width) * 100;
    const y = ((clientY - r.top) / r.height) * 100;
    return {
      lng: Math.min(100, Math.max(0, round2(x))),
      lat: Math.min(90, Math.max(0, round2(y))),
    };
  };
  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const v = toPct(e.clientX, e.clientY);
    if (v) onChange(v);
  };

  const handleMarkerPointerDown = (e: React.PointerEvent<HTMLButtonElement>) => {
    e.preventDefault();
    e.stopPropagation();
    const el = frameRef.current;
    if (!el) return;
    const move = (ev: PointerEvent) => {
      const v = toPct(ev.clientX, ev.clientY);
      if (v) onChange(v);
    };
    const up = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
  };

  return (
    <div className="flex flex-col gap-2">
      <div
        ref={frameRef}
        role="button"
        tabIndex={0}
        aria-label="Chọn vị trí địa điểm trên bản đồ"
        onClick={handleClick}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") e.preventDefault();
        }}
        style={{ height }}
        className={cn(
          "relative w-full cursor-crosshair select-none overflow-hidden rounded-md border border-border",
          "bg-muted/30",
        )}
      >
        {imgError ? (
          <div className="flex h-full items-center justify-center text-xs text-ink-muted">
            Không tải được ảnh bản đồ — vẫn nhập % thủ công bên dưới.
          </div>
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={imageSrc}
            alt={imageLabel ?? "Bản đồ sự kiện"}
            draggable={false}
            onError={() => setImgError(true)}
            className="h-full w-full object-cover"
          />
        )}

        {displayPos && !imgError && (
          <button
            type="button"
            aria-label="Vị trí đã chọn — kéo để chỉnh"
            onPointerDown={handleMarkerPointerDown}
            onClick={(e) => e.stopPropagation()}
            style={{
              left: `${displayPos.leftPct}%`,
              top: `${displayPos.topPct}%`,
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
      <p className="text-xs text-ink-muted">
        {imageLabel ? `${imageLabel} · ` : ""}
        Click lên ảnh để chọn vị trí — kéo chấm đỏ để tinh chỉnh. Giá trị lưu
        là % theo ảnh (X→kinh độ, Y→vĩ độ).
      </p>
    </div>
  );
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}
