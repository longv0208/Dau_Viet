"use client";

import { useQuery } from "@tanstack/react-query";
import { LayoutTemplate } from "lucide-react";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import type { LessonTemplate } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";

import { genSlugId } from "./draft-id";
import { allIds, parseDraft, type Draft, type Stage } from "./draft-model";

interface Props {
  templateId: string;
  draft: Draft;
  readOnly?: boolean;
  onMerge: (stages: Stage[]) => void;
  /** FOUR_STEP: replace toàn bộ stages (không append) khi seed từ template. */
  onReplace?: (stages: Stage[]) => void;
}

/**
 * "Tạo cấu trúc từ khung bài học" — phân tích presetJson của template,
 * sinh id mới cho mọi stage/activity (map nextStageIds theo id mới),
 * rồi APPEND vào draft hiện tại. Luôn hỏi xác nhận — không bao giờ
 * thay thế âm thầm công việc đang có.
 */
export function TemplateSeedButton({ templateId, draft, readOnly, onMerge, onReplace }: Props) {
  const [error, setError] = useState<string | null>(null);
  const templatesQuery = useQuery({
    queryKey: qk.templates.list(),
    queryFn: () => apiFetch<LessonTemplate[]>("/admin/lesson-templates"),
  });
  const template = templatesQuery.data?.find((t) => t.id === templateId);

  // presetJson phải parse thành draft có ≥1 stage thì nút mới có ý nghĩa.
  let seedStages: Stage[] | null = null;
  if (template?.presetJson) {
    try {
      const parsed = parseDraft(template.presetJson);
      if (parsed.stages.length > 0) seedStages = parsed.stages;
    } catch {
      seedStages = null;
    }
  }

  const isFourStep = draft.flowModel === "FOUR_STEP";

  function handleSeed() {
    if (!seedStages) return;
    const hasExisting = draft.stages.length > 0;
    const ok = window.confirm(
      isFourStep
        ? `Tạo lại cấu trúc 4 bước từ khung "${template?.name ?? ""}"?` +
          (hasExisting ? "\n\nCác giai đoạn hiện có sẽ bị THAY THẾ." : "")
        : hasExisting
          ? `Thêm ${seedStages.length} giai đoạn từ khung "${template?.name ?? ""}" vào CUỐI bản nháp? Các giai đoạn hiện có được giữ nguyên.`
          : `Tạo ${seedStages.length} giai đoạn từ khung "${template?.name ?? ""}"?`,
    );
    if (!ok) return;
    try {
      const taken = allIds(draft);
      const idMap = new Map<string, string>();
      const remapped = seedStages.map((s) => {
        const newStageId = genSlugId("stage", taken);
        taken.push(newStageId);
        idMap.set(s.id, newStageId);
        const activities = s.activities.map((a) => {
          const id = genSlugId("act", taken);
          taken.push(id);
          return { ...a, id };
        });
        return { ...s, id: newStageId, activities };
      });
      for (const s of remapped) {
        if (Array.isArray(s.nextStageIds)) {
          s.nextStageIds = s.nextStageIds
            .map((n) => idMap.get(n))
            .filter((n): n is string => Boolean(n));
        }
      }
      if (isFourStep && onReplace) {
        onReplace(remapped);
      } else {
        onMerge(remapped);
      }
      setError(null);
    } catch {
      setError("Không thể tạo cấu trúc từ khung bài học — preset không hợp lệ.");
    }
  }

  if (templatesQuery.isPending || !template) return null;
  if (!seedStages) {
    return (
      <p className="text-xs text-ink-muted">
        Khung bài học &quot;{template.name}&quot; không có cấu trúc mẫu để tạo nhanh.
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-1.5">
      <Button
        variant="secondary"
        size="sm"
        className="self-start"
        disabled={readOnly}
        onClick={handleSeed}
      >
        <LayoutTemplate className="size-4" /> Tạo cấu trúc từ khung bài học
      </Button>
      <p className="text-xs text-ink-muted">
        Thêm {seedStages.length} giai đoạn mẫu của &quot;{template.name}&quot; vào cuối bản nháp.
      </p>
      {error && (
        <p role="alert" className="text-xs text-error">
          {error}
        </p>
      )}
    </div>
  );
}
