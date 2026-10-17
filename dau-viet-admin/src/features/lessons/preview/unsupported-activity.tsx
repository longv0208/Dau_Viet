import type { Activity } from "../builder/draft-model";

/**
 * Honest placeholder for activity types with no dedicated preview renderer
 * (EXPLORE_MAP + anything unknown). Shows the type + read-only config JSON —
 * never fabricates a fake interactive widget.
 */
export function UnsupportedActivity({ activity }: { activity: Activity }) {
  return (
    <div className="flex flex-col gap-2 rounded-md border border-dashed border-warning/60 bg-warning/5 p-3">
      <p className="text-sm font-medium text-ink">
        Loại hoạt động <span className="font-mono">{activity.type}</span> chưa có bản xem trước.
      </p>
      <p className="text-xs text-ink-muted">
        Màn hình học viên cho loại này sẽ do ứng dụng Flutter quyết định — đây chỉ là cấu hình
        đã lưu:
      </p>
      <pre className="max-h-48 overflow-auto rounded bg-white p-2 text-[10px] leading-relaxed text-ink-muted">
        {JSON.stringify(activity.config ?? {}, null, 2)}
      </pre>
    </div>
  );
}
