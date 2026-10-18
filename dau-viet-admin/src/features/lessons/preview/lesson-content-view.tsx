"use client";

import { useMemo, useState } from "react";

import { parseDraft, type Draft } from "../builder/draft-model";
import { MobileFrame } from "./mobile-frame";
import type { EmbeddedAsset, EmbeddedEvidence } from "./renderers/types";
import { StageNav } from "./stage-nav";
import { StageView } from "./stage-view";

/**
 * Learner-view renderer for a content payload (preview projection or a
 * published snapshot — both carry `stages` + denormalized `evidence`/`assets`).
 * Shared by the draft preview page and the version detail view.
 */
export function LessonContentView({ content }: { content: unknown }) {
  const [selectedStageId, setSelectedStageId] = useState<string | null>(null);
  const [activityIndex, setActivityIndex] = useState(0);

  const draft: Draft | null = useMemo(() => {
    if (!content) return null;
    try {
      return parseDraft(JSON.stringify(content));
    } catch {
      return null;
    }
  }, [content]);

  const embedded = useMemo(() => {
    const c = content as Record<string, unknown> | undefined;
    return {
      evidence: Array.isArray(c?.evidence) ? (c.evidence as EmbeddedEvidence[]) : [],
      assets: Array.isArray(c?.assets) ? (c.assets as EmbeddedAsset[]) : [],
    };
  }, [content]);

  const stages = draft?.stages ?? [];
  const currentStageId = selectedStageId ?? stages[0]?.id ?? null;
  const stage = stages.find((s) => s.id === currentStageId) ?? stages[0] ?? null;

  if (stages.length === 0) {
    return (
      <div className="rounded-md border border-dashed border-border px-6 py-12 text-center">
        <p className="text-sm text-ink-muted">Nội dung chưa có giai đoạn nào.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center gap-4">
      <StageNav
        stages={stages}
        selectedId={stage?.id ?? null}
        onSelect={(id) => {
          setSelectedStageId(id);
          setActivityIndex(0);
        }}
      />
      <MobileFrame>
        {stage && (
          <StageView
            stage={stage}
            activityIndex={activityIndex}
            onActivityChange={setActivityIndex}
            evidence={embedded.evidence}
            assets={embedded.assets}
          />
        )}
      </MobileFrame>
    </div>
  );
}
