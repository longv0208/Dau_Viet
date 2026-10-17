import type { Activity } from "../builder/draft-model";
import { ACTIVITY_LABELS } from "../builder/labels";

/**
 * Honest placeholder for activity types with no dedicated preview renderer
 * (EXPLORE_MAP + anything unknown). Shows the type + read-only config JSON —
 * never fabricates a fake interactive widget.
 */
export function UnsupportedActivity({ activity }: { activity: Activity }) {
  return (
    <div className="flex flex-col gap-2 rounded-md border border-dashed border-warning/60 bg-warning/5 p-3">
      <p className="text-sm font-medium text-ink">
        Loại hoạt động <strong>{ACTIVITY_LABELS[activity.type]?.label ?? "này"}</strong> chưa có bản xem trước.
      </p>
      <p className="text-xs text-ink-muted">
        Ứng dụng học viên sẽ tự hiển thị loại này — đây chỉ là dữ liệu đã lưu:
      </p>
      <details className="text-xs text-ink-muted">
        <summary className="cursor-pointer">Dữ liệu kỹ thuật</summary>
        <pre className="max-h-48 overflow-auto rounded bg-white p-2 text-[10px] leading-relaxed text-ink-muted">
          {JSON.stringify(activity.config ?? {}, null, 2)}
        </pre>
      </details>
    </div>
  );
}
