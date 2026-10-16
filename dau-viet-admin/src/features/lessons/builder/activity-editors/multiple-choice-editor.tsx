"use client";

import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { genItemId } from "../draft-id";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

interface Option {
  id: string;
  label: string;
}

interface Option extends Record<string, unknown> {
  id: string;
  label: string;
}

/** Reads options preserving unknown item-level keys (image, hint…). */
function readOptions(config: Record<string, unknown> | undefined): Option[] {
  const raw = config?.options;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((o) => o && typeof o === "object")
    .map((o) => {
      const r = o as Record<string, unknown>;
      return { ...r, id: String(r.id ?? ""), label: String(r.label ?? r.text ?? "") } as Option;
    })
    .filter((o) => o.id);
}

/**
 * MULTIPLE_CHOICE — question + options[≥2 unique ids] + exactly ONE of
 * correctOptionIds[] (single-answer) or multiCorrect[] (multi-answer).
 * Emits the active mode only; clears the other so both never coexist.
 */
export function MultipleChoiceEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const config = activity.config ?? {};
  const question = (config.question as string) ?? "";
  const options = readOptions(activity.config);
  const singleIds = (config.correctOptionIds as string[] | undefined) ?? null;
  const multiIds = (config.multiCorrect as string[] | undefined) ?? null;
  const mode: "single" | "multi" = multiIds ? "multi" : "single";
  const correctSet = new Set(mode === "single" ? (singleIds ?? []) : (multiIds ?? []));

  function write(next: { options?: Option[]; correct?: string[]; nextMode?: "single" | "multi" }) {
    const opts = next.options ?? options;
    const m = next.nextMode ?? mode;
    const correct = (next.correct ?? Array.from(correctSet)).filter((id) =>
      opts.some((o) => o.id === id),
    );
    const cfg: Record<string, unknown> = {
      ...config,
      question,
      options: opts.map((o) => ({ ...o, id: o.id, label: o.label })),
    };
    delete cfg.correctOptionIds;
    delete cfg.multiCorrect;
    if (m === "single") cfg.correctOptionIds = correct.slice(0, 1);
    else cfg.multiCorrect = correct;
    onChange({ config: cfg });
  }

  const optionIds = options.map((o) => o.id);

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`q-${activity.id}`}>Câu hỏi *</Label>
        <Textarea
          id={`q-${activity.id}`}
          rows={2}
          value={question}
          disabled={readOnly}
          onChange={(e) => {
            onChange({ config: { ...config, question: e.target.value } });
          }}
        />
        {!question.trim() && <p role="alert" className="text-xs text-error">Nhập câu hỏi.</p>}
      </div>

      <div className="flex items-center gap-4 text-sm">
        <span className="text-xs font-medium text-ink-muted">Kiểu chọn:</span>
        <label className="flex items-center gap-1.5">
          <input
            type="radio"
            name={`mode-${activity.id}`}
            checked={mode === "single"}
            disabled={readOnly}
            onChange={() => write({ nextMode: "single" })}
            className="accent-brand"
          />
          Một đáp án
        </label>
        <label className="flex items-center gap-1.5">
          <input
            type="radio"
            name={`mode-${activity.id}`}
            checked={mode === "multi"}
            disabled={readOnly}
            onChange={() => write({ nextMode: "multi" })}
            className="accent-brand"
          />
          Nhiều đáp án
        </label>
      </div>

      <div className="flex flex-col gap-2">
        <Label>Đáp án (đánh dấu đáp án đúng — không hiển thị cho học viên)</Label>
        {options.map((o, i) => (
          <div key={o.id} className="flex items-center gap-2">
            <input
              type={mode === "single" ? "radio" : "checkbox"}
              name={`correct-${activity.id}`}
              checked={correctSet.has(o.id)}
              disabled={readOnly}
              className="size-4 shrink-0 accent-brand"
              aria-label={`Đáp án đúng ${i + 1}`}
              onChange={() => {
                if (mode === "single") write({ correct: [o.id] });
                else {
                  const s = new Set(correctSet);
                  if (s.has(o.id)) s.delete(o.id);
                  else s.add(o.id);
                  write({ correct: Array.from(s) });
                }
              }}
            />
            <Input
              value={o.label}
              disabled={readOnly}
              placeholder={`Đáp án ${i + 1}`}
              onChange={(e) =>
                write({
                  options: options.map((x) =>
                    x.id === o.id ? { ...x, label: e.target.value } : x,
                  ),
                })
              }
            />
            {!readOnly && (
              <Button
                variant="secondary"
                className="h-9 px-2"
                disabled={options.length <= 2}
                aria-label={`Xoá đáp án ${i + 1}`}
                onClick={() => write({ options: options.filter((x) => x.id !== o.id) })}
              >
                <Trash2 className="size-3.5" />
              </Button>
            )}
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="secondary"
            className="self-start"
            size="sm"
            onClick={() =>
              write({ options: [...options, { id: genItemId(optionIds), label: "" }] })
            }
          >
            <Plus className="size-4" /> Thêm đáp án
          </Button>
        )}
        {options.length < 2 && (
          <p role="alert" className="text-xs text-error">Cần ít nhất 2 đáp án.</p>
        )}
        {options.length >= 2 && correctSet.size === 0 && (
          <p role="alert" className="text-xs text-error">Chọn ít nhất 1 đáp án đúng.</p>
        )}
      </div>
    </div>
  );
}
