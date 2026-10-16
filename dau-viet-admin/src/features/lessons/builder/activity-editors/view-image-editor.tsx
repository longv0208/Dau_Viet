"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/** VIEW_IMAGE — config.imageAssetId (required at SAVE) + caption. */
export function ViewImageEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const assetId = (activity.config?.imageAssetId as string) ?? "";
  const caption = (activity.config?.caption as string) ?? "";
  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`asset-${activity.id}`}>Asset ID hình ảnh *</Label>
        <Input
          id={`asset-${activity.id}`}
          value={assetId}
          disabled={readOnly}
          placeholder="UUID của asset đã upload"
          aria-invalid={!assetId}
          onChange={(e) =>
            onChange({ config: { ...activity.config, imageAssetId: e.target.value.trim() } })
          }
        />
        <p className="text-xs text-ink-muted">
          Nhập UUID của asset trong thư viện media. Trình chọn trực quan sẽ có ở TASK-0016.
        </p>
        {!assetId && (
          <p role="alert" className="text-xs text-error">Bắt buộc để lưu hợp lệ.</p>
        )}
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`cap-${activity.id}`}>Chú thích hình</Label>
        <Input
          id={`cap-${activity.id}`}
          value={caption}
          disabled={readOnly}
          placeholder="Mô tả ngắn hiển thị dưới hình"
          onChange={(e) =>
            onChange({ config: { ...activity.config, caption: e.target.value } })
          }
        />
      </div>
    </div>
  );
}
