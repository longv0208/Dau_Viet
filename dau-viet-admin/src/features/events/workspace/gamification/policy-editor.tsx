"use client";

import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import type {
  AdminCompletionPolicy,
  AdminCompletionPolicyUpsert,
  AdminPolicyValidation,
} from "@/lib/dto/gamification";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import type { PageResponse } from "@/lib/dto/common";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

/**
 * Form soạn DRAFT policy: chọn required/optional lessons + threshold.
 * Submit callback do parent xử lý (create hoặc update + refresh).
 */
export function PolicyEditor({
  eventId,
  initial,
  saving,
  validating,
  validation,
  onValidate,
  onSubmit,
  onCancel,
}: {
  eventId: string;
  initial: AdminCompletionPolicy | null;
  saving: boolean;
  validating: boolean;
  validation: AdminPolicyValidation | null;
  onValidate: (req: AdminCompletionPolicyUpsert) => void;
  onSubmit: (req: AdminCompletionPolicyUpsert) => void;
  onCancel: () => void;
}) {
  const [required, setRequired] = useState<string[]>(
    initial?.requiredLessonIds ?? [],
  );
  const [optional, setOptional] = useState<string[]>(
    initial?.optionalLessonIds ?? [],
  );
  const [useThreshold, setUseThreshold] = useState(
    initial?.masteryThreshold != null,
  );
  const [threshold, setThreshold] = useState<number>(
    initial?.masteryThreshold ?? 70,
  );

  const lessons = useQuery({
    queryKey: qk.lessons.list({ eventId, status: "PUBLISHED", size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminLessonSummary>>(
        `/admin/lessons${toQuery({ eventId, status: "PUBLISHED", size: 100 })}`,
      ),
  });

  const allLessons = lessons.data?.content ?? [];
  const requiredSet = useMemo(() => new Set(required), [required]);
  const optionalSet = useMemo(() => new Set(optional), [optional]);

  const buildReq = (): AdminCompletionPolicyUpsert => ({
    requiredLessonIds: required,
    optionalLessonIds: optional,
    masteryThreshold: useThreshold ? threshold : null,
    expectedPolicyVersion: initial?.policyVersion ?? null,
  });

  const toggle = (id: string, list: string[], set: (v: string[]) => void) =>
    set(list.includes(id) ? list.filter((x) => x !== id) : [...list, id]);

  void requiredSet;
  void optionalSet;

  const lessonPicker = (
    title: string,
    list: string[],
    set: (v: string[]) => void,
    excluded: Set<string>,
  ) => (
    <fieldset className="rounded-md border border-border p-3">
      <legend className="px-1 text-sm font-medium text-ink">{title}</legend>
      {allLessons.length === 0 && !lessons.isPending && (
        <p className="text-sm text-ink-muted">
          Sự kiện chưa có bài học PUBLISHED.
        </p>
      )}
      <ul className="mt-1 flex max-h-56 flex-col gap-1 overflow-y-auto">
        {allLessons.map((l) => {
          const disabled = excluded.has(l.id);
          return (
            <li key={l.id}>
              <label
                className={
                  "flex items-center gap-2 rounded px-2 py-1.5 text-sm " +
                  (disabled ? "opacity-40" : "hover:bg-surface-alt")
                }
              >
                <input
                  type="checkbox"
                  disabled={disabled}
                  checked={list.includes(l.id)}
                  onChange={() => toggle(l.id, list, set)}
                />
                <span className="truncate">{l.title}</span>
              </label>
            </li>
          );
        })}
      </ul>
      <p className="mt-1 text-xs text-ink-muted">
        Đã chọn: {list.length}
        {disabledNote(excluded, list)}
      </p>
    </fieldset>
  );

  return (
    <div className="flex flex-col gap-4 rounded-lg border border-border bg-white p-4">
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {lessonPicker("Bài học bắt buộc (required)", required, setRequired, optionalSet)}
        {lessonPicker("Bài học tuỳ chọn (optional)", optional, setOptional, requiredSet)}
      </div>

      <div className="flex items-end gap-3">
        <div className="flex items-center gap-2">
          <input
            id="use-threshold"
            type="checkbox"
            checked={useThreshold}
            onChange={(e) => setUseThreshold(e.target.checked)}
          />
          <Label htmlFor="use-threshold">Đánh giá mastered</Label>
        </div>
        {useThreshold && (
          <div className="w-32">
            <Label htmlFor="threshold">Ngưỡng (0–100)</Label>
            <Input
              id="threshold"
              type="number"
              min={0}
              max={100}
              value={threshold}
              onChange={(e) => setThreshold(Number(e.target.value))}
            />
          </div>
        )}
      </div>

      {validation && (
        <div
          className={
            "rounded-md border p-3 text-sm " +
            (validation.valid
              ? "border-success/40 bg-success/10"
              : "border-error/40 bg-error/10")
          }
        >
          {validation.valid ? (
            <p className="font-medium">Hợp lệ — có thể xuất bản.</p>
          ) : (
            <ul className="flex flex-col gap-1">
              {validation.errors.map((e, i) => (
                <li key={i}>
                  <span className="font-medium">[{e.code}]</span> {e.message}
                  {e.field ? (
                    <span className="text-ink-muted"> — {e.field}</span>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
          {validation.warnings.map((w, i) => (
            <p key={i} className="mt-1 text-ink-muted">
              {w}
            </p>
          ))}
        </div>
      )}

      <div className="flex flex-wrap items-center gap-2">
        <Button
          variant="secondary"
          disabled={validating}
          onClick={() => onValidate(buildReq())}
        >
          {validating ? "Đang kiểm tra…" : "Kiểm tra"}
        </Button>
        <Button disabled={saving} onClick={() => onSubmit(buildReq())}>
          {saving ? "Đang lưu…" : "Lưu bản nháp"}
        </Button>
        <Button variant="secondary" onClick={onCancel}>
          Đóng
        </Button>
      </div>
    </div>
  );
}

function disabledNote(excluded: Set<string>, list: string[]) {
  const n = list.filter((id) => excluded.has(id)).length;
  return n > 0 ? ` (${n} trùng danh sách kia)` : "";
}
