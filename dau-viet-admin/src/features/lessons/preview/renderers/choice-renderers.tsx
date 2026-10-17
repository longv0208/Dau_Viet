"use client";

import { useState } from "react";

import type { PreviewActivityProps } from "./types";

interface ChoiceItem {
  id: string;
  label: string;
}

function readItems(raw: unknown): ChoiceItem[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((o) => o && typeof o === "object")
    .map((o) => {
      const r = o as Record<string, unknown>;
      return { id: String(r.id ?? ""), label: String(r.label ?? r.text ?? "") };
    })
    .filter((o) => o.id);
}

/**
 * MULTIPLE_CHOICE — question + options. Preview must NEVER mark the correct
 * option: the backend projection already strips correctOptionIds/multiCorrect,
 * and this renderer intentionally does not read them.
 */
export function MultipleChoiceActivityView({ activity }: PreviewActivityProps) {
  const config = activity.config ?? {};
  const question = typeof config.question === "string" ? config.question : "";
  const options = readItems(config.options);
  // multiSelect is only a display concern (checkbox vs radio) — hidden keys
  // that encode the correct answers are absent from the projection.
  const multi = config.multiSelect === true;
  const [picked, setPicked] = useState<string[]>([]);

  function toggle(id: string) {
    setPicked((prev) =>
      multi
        ? prev.includes(id)
          ? prev.filter((x) => x !== id)
          : [...prev, id]
        : [id],
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-ink">{question || "Chưa có câu hỏi."}</p>
      <div className="flex flex-col gap-2" role={multi ? "group" : "radiogroup"}>
        {options.map((o) => (
          <label
            key={o.id}
            className={
              "flex items-center gap-2.5 rounded-md border px-3 py-2 text-sm " +
              (picked.includes(o.id)
                ? "border-brand bg-brand/5 text-ink"
                : "border-border text-ink")
            }
          >
            <input
              type={multi ? "checkbox" : "radio"}
              name={`mc-${activity.id}`}
              checked={picked.includes(o.id)}
              onChange={() => toggle(o.id)}
              className="size-4 accent-brand"
            />
            {o.label || "(đáp án trống)"}
          </label>
        ))}
        {options.length === 0 && (
          <p className="text-sm italic text-ink-muted">Chưa có đáp án nào.</p>
        )}
      </div>
      <p className="text-[11px] text-ink-muted">Xem trước — không chấm điểm lựa chọn này.</p>
    </div>
  );
}

/** HYPOTHESIS_CHOICE — hypotheses[{id,label}] single-pick radio group. */
export function HypothesisChoiceActivityView({ activity }: PreviewActivityProps) {
  const hypotheses = readItems(activity.config?.hypotheses);
  const [picked, setPicked] = useState<string | null>(null);
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-ink">Chọn một giả thuyết để kiểm chứng:</p>
      <div className="flex flex-col gap-2" role="radiogroup">
        {hypotheses.map((h) => (
          <label
            key={h.id}
            className={
              "flex items-center gap-2.5 rounded-md border px-3 py-2 text-sm " +
              (picked === h.id ? "border-brand bg-brand/5" : "border-border")
            }
          >
            <input
              type="radio"
              name={`hyp-${activity.id}`}
              checked={picked === h.id}
              onChange={() => setPicked(h.id)}
              className="size-4 accent-brand"
            />
            {h.label || "(giả thuyết trống)"}
          </label>
        ))}
        {hypotheses.length === 0 && (
          <p className="text-sm italic text-ink-muted">Chưa có giả thuyết nào.</p>
        )}
      </div>
    </div>
  );
}
