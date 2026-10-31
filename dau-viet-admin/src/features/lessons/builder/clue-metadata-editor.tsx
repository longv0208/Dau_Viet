"use client";

import { useState } from "react";

import type { Activity, ClueType, Draft } from "./draft-model";
import { CLUE_LABELS } from "./draft-model";
import { ACTIVITY_LABELS } from "./labels";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

interface Props {
  activity: Activity;
  draft: Draft;
  readOnly?: boolean;
  onChange: (patch: Partial<Activity>) => void;
}

/**
 * Clue metadata editor for a DISCOVERY-stage activity in the 4-step flow.
 * Manages clueType selection, title, description and optional cover image.
 */
export function ClueMetadataEditor({ activity, readOnly, onChange }: Props) {
  const [pickingCover, setPickingCover] = useState(false);
  const clue = activity.clueType as ClueType | undefined;
  const clueMeta = clue ? CLUE_LABELS[clue] : null;
  const actLabel = ACTIVITY_LABELS[activity.type]?.label ?? activity.type;

  return (
    <div className="flex flex-col gap-4 rounded-md border border-brand/30 bg-brand/5 p-4">
      <div className="flex items-center gap-2">
        <span className="text-xs font-semibold uppercase tracking-wider text-brand">
          Dấu vết: {clueMeta?.label ?? "—"}
        </span>
        <span className="text-xs text-ink-muted">·</span>
        <span className="text-xs text-ink-muted">{actLabel}</span>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label className="font-medium text-ink-secondary">Loại dấu vết</Label>
          <select
            className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm text-ink disabled:opacity-50"
            value={activity.clueType ?? ""}
            disabled={readOnly}
            onChange={(e) =>
              onChange({ clueType: (e.target.value as ClueType) || undefined })
            }
          >
            <option value="">— Chọn loại —</option>
            {(Object.keys(CLUE_LABELS) as ClueType[]).map((ct) => (
              <option key={ct} value={ct}>
                {CLUE_LABELS[ct].label}
              </option>
            ))}
          </select>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label className="font-medium text-ink-secondary">Tên hiển thị</Label>
          <Input
            value={activity.title ?? clueMeta?.label ?? ""}
            disabled={readOnly}
            placeholder={clueMeta?.label ?? "Tên dấu vết"}
            onChange={(e) => onChange({ title: e.target.value || undefined })}
          />
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label className="font-medium text-ink-secondary">Mô tả ngắn</Label>
        <Textarea
          value={activity.description ?? ""}
          disabled={readOnly}
          placeholder={clueMeta?.hint ?? "Mô tả ngắn về dấu vết này"}
          rows={2}
          onChange={(e) => onChange({ description: e.target.value || undefined })}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label className="font-medium text-ink-secondary">Ảnh đại diện (tùy chọn)</Label>
        <div className="flex items-center gap-2">
          {activity.coverAssetId ? (
            <>
              <span className="rounded-md border border-border bg-surface px-2 py-1 text-xs text-ink-muted">
                {activity.coverAssetId.slice(0, 8)}…
              </span>
              {!readOnly && (
                <Button
                  variant="secondary"
                  className="h-7 px-2 text-xs"
                  onClick={() => onChange({ coverAssetId: undefined })}
                >
                  Bỏ ảnh
                </Button>
              )}
            </>
          ) : (
            <span className="text-xs text-ink-muted">
              Chưa có ảnh — sẽ dùng giao diện mặc định
            </span>
          )}
          {!readOnly && (
            <Button
              variant="secondary"
              className="h-7 px-2 text-xs"
              onClick={() => setPickingCover(true)}
            >
              {activity.coverAssetId ? "Đổi ảnh" : "Chọn ảnh"}
            </Button>
          )}
        </div>
      </div>

      {pickingCover && (
        <AssetPickerDialog
          open={pickingCover}
          onOpenChange={(open) => setPickingCover(open)}
          onSelect={(asset) => {
            onChange({ coverAssetId: asset.id });
            setPickingCover(false);
          }}
        />
      )}
    </div>
  );
}
