"use client";

import type { ItemScope } from "@/lib/dto/item";

/**
 * Banner trạng thái scope của item (GAME-06) — đọc từ
 * `AdminItemResponse.scope`. UNRESOLVED/EVENT_SCOPED cảnh báo vì backend
 * chỉ chấp nhận rule mới có ít nhất một leaf gắn sự kiện.
 */
export function ScopeBanner({ scope }: { scope?: string | null }) {
  if (!scope) return null;

  if (scope === "GLOBAL") {
    return (
      <p className="rounded-md bg-success/15 px-3 py-2 text-sm text-ink">
        Vật phẩm phạm vi toàn hệ thống — chấp nhận mọi điều kiện hợp lệ.
      </p>
    );
  }

  const text =
    scope === "UNRESOLVED"
      ? "Vật phẩm chưa minh định sự kiện — chỉ được kích hoạt điều kiện có ít nhất một nhánh gắn sự kiện."
      : "Vật phẩm đã gắn phạm vi sự kiện — điều kiện mới phải chứa ít nhất một nhánh gắn sự kiện.";

  return (
    <p className="rounded-md bg-warning/25 px-3 py-2 text-sm text-ink">
      {text}
    </p>
  );
}

export type { ItemScope };
