"use client";

import { Plus } from "lucide-react";

import type { LeafType } from "./rule-ast";

interface LibraryItem {
  type: LeafType;
  label: string;
  hint: string;
  disabled?: boolean;
}

interface LibraryGroup {
  title: string;
  items: LibraryItem[];
}

const GROUPS: LibraryGroup[] = [
  {
    title: "Bài học",
    items: [
      { type: "LESSON_COMPLETED", label: "Hoàn thành bài học", hint: "1 bài cụ thể" },
      { type: "LESSON_MASTERED", label: "Thành thạo bài học", hint: "bài + ngưỡng điểm" },
      { type: "LESSON_COUNT", label: "Đủ N bài học", hint: "đếm toàn hệ thống" },
    ],
  },
  {
    title: "Sự kiện",
    items: [
      { type: "EVENT_COMPLETED", label: "Hoàn thành sự kiện", hint: "gắn 1 sự kiện" },
      { type: "EVENT_MASTERED", label: "Thành thạo sự kiện", hint: "theo mastery policy" },
      { type: "EVENT_EVIDENCE_COUNT", label: "Đủ N bằng chứng của sự kiện", hint: "sự kiện + ngưỡng" },
    ],
  },
  {
    title: "Bằng chứng",
    items: [
      { type: "COLLECTION_COUNT", label: "Sưu tầm đủ N bằng chứng", hint: "đếm toàn hệ thống" },
      { type: "SPECIFIC_EVIDENCE_SET", label: "Bộ bằng chứng chỉ định", hint: "chọn từng bằng chứng" },
    ],
  },
  {
    title: "Thành tựu tổng",
    items: [
      { type: "TOTAL_EVENTS_COMPLETED", label: "Tổng sự kiện hoàn thành", hint: "đếm toàn hệ thống" },
      { type: "TOTAL_EVENTS_MASTERED", label: "Tổng sự kiện thành thạo", hint: "đếm toàn hệ thống" },
    ],
  },
  {
    title: "Chưa hỗ trợ",
    items: [
      {
        type: "LEVEL_AT_LEAST",
        label: "Đạt cấp độ tối thiểu",
        hint: "Chưa hỗ trợ — GAME-07",
        disabled: true,
      },
    ],
  },
];

/**
 * Panel trái của Rule Builder — thư viện điều kiện gom nhóm.
 * Click item → append leaf mới vào builder.
 */
export function ConditionLibrary({
  onAdd,
}: {
  onAdd: (type: LeafType) => void;
}) {
  return (
    <div className="flex flex-col gap-4">
      {GROUPS.map((g) => (
        <div key={g.title}>
          <h4 className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-ink-muted">
            {g.title}
          </h4>
          <ul className="flex flex-col gap-1">
            {g.items.map((it) => (
              <li key={it.type}>
                <button
                  type="button"
                  disabled={it.disabled}
                  onClick={() => onAdd(it.type)}
                  title={it.disabled ? it.hint : `Thêm: ${it.hint}`}
                  className="flex w-full items-center justify-between gap-2 rounded-md border border-border px-3 py-2 text-left text-sm transition-colors enabled:hover:bg-surface-alt disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <span className="min-w-0">
                    <span className="block truncate font-medium text-ink">
                      {it.label}
                    </span>
                    <span className="block truncate text-xs text-ink-muted">
                      {it.hint}
                    </span>
                  </span>
                  <Plus className="size-4 shrink-0 text-ink-muted" aria-hidden />
                </button>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}
