"use client";

import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { ActivityCommonFields, type EditorProps } from "./shared-fields";

const MAX_PROMPT = 2000;

/** REFLECTION_PROMPT — config.prompt (optional, ≤2000 ký tự). */
export function ReflectionPromptEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const prompt = (activity.config?.prompt as string) ?? "";
  const tooLong = prompt.length > MAX_PROMPT;

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`rp-${activity.id}`}>Câu hỏi gợi mở suy ngẫm</Label>
        <Textarea
          id={`rp-${activity.id}`}
          rows={4}
          value={prompt}
          disabled={readOnly}
          aria-invalid={tooLong}
          placeholder="Ví dụ: Nếu em là Ngô Quyền, em sẽ…"
          onChange={(e) =>
            onChange({ config: { ...activity.config, prompt: e.target.value } })
          }
        />
        <p className={"text-xs " + (tooLong ? "text-error" : "text-ink-muted")}>
          {prompt.length}/{MAX_PROMPT.toLocaleString("vi-VN")} ký tự
        </p>
      </div>
    </div>
  );
}
