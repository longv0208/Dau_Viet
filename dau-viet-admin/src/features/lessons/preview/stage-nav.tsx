"use client";

import type { Stage } from "../builder/draft-model";

const STAGE_LABELS: Record<string, string> = {
  CONTEXT: "Bối cảnh",
  DISCOVERY: "Khám phá",
  EVIDENCE: "Bằng chứng",
  REASONING: "Suy luận",
  HYPOTHESIS: "Giả thuyết",
  RECONSTRUCTION: "Tái dựng",
  VERIFICATION: "Kiểm chứng",
  CONCLUSION: "Kết luận",
  REFLECTION: "Suy ngẫm",
};

export function stageLabel(type: string): string {
  return STAGE_LABELS[type] ?? type;
}

/** Stage chips row — preview lets the admin jump to ANY stage (no gating). */
export function StageNav({
  stages,
  selectedId,
  onSelect,
}: {
  stages: Stage[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  return (
    <div className="flex flex-wrap gap-1.5" role="tablist" aria-label="Giai đoạn">
      {stages.map((s, i) => (
        <button
          key={s.id}
          type="button"
          role="tab"
          aria-selected={s.id === selectedId}
          onClick={() => onSelect(s.id)}
          className={
            "rounded-full border px-2.5 py-1 text-xs font-medium " +
            (s.id === selectedId
              ? "border-brand bg-brand text-white"
              : "border-border bg-white text-ink hover:border-brand/60")
          }
        >
          {i + 1}. {s.title || stageLabel(s.type)}
        </button>
      ))}
    </div>
  );
}
