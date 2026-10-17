"use client";

import { useState } from "react";

import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { evidenceLabel, findEvidence } from "./resolve-evidence";
import type { PreviewActivityProps } from "./types";

const VERDICTS = [
  { id: "SUPPORTED", label: "Củng cố" },
  { id: "PARTIAL", label: "Củng cố một phần" },
  { id: "CONTRADICTED", label: "Bác bỏ" },
] as const;

/**
 * VERIFICATION — visibleSourceIds chips + verdict pick. requiredEvidenceIds
 * is a hidden key (already stripped by the projection) and is NOT rendered.
 */
export function VerificationActivityView({ activity, evidence }: PreviewActivityProps) {
  const sources = Array.isArray(activity.config?.visibleSourceIds)
    ? (activity.config.visibleSourceIds as unknown[]).map((x) => String(x ?? "")).filter(Boolean)
    : [];
  const [verdict, setVerdict] = useState<string | null>(null);
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-ink">Đối chiếu giả thuyết với các nguồn:</p>
      <div className="flex flex-col gap-1.5">
        {sources.map((id, i) => {
          const doc = findEvidence(evidence, id);
          const sourceTitle = doc?.source?.title?.trim();
          const attribution = [doc?.source?.author, doc?.source?.publishedAt]
            .filter(Boolean)
            .join(" · ");
          return (
            <div
              key={id}
              className="rounded-md border border-border bg-surface px-3 py-2"
            >
              <p className="text-xs font-medium text-ink">
                {evidenceLabel(evidence, id, `Nguồn ${i + 1}`)}
              </p>
              {sourceTitle && (
                <p className="text-[11px] italic text-ink-muted">
                  {sourceTitle}{attribution ? ` — ${attribution}` : ""}
                </p>
              )}
            </div>
          );
        })}
        {sources.length === 0 && (
          <p className="text-sm italic text-ink-muted">Chưa khai báo nguồn nào.</p>
        )}
      </div>
      <div className="flex flex-col gap-2" role="radiogroup" aria-label="Kết luận kiểm chứng">
        {VERDICTS.map((v) => (
          <label
            key={v.id}
            className={
              "flex items-center gap-2.5 rounded-md border px-3 py-2 text-sm " +
              (verdict === v.id ? "border-brand bg-brand/5" : "border-border")
            }
          >
            <input
              type="radio"
              name={`verdict-${activity.id}`}
              checked={verdict === v.id}
              onChange={() => setVerdict(v.id)}
              className="size-4 accent-brand"
            />
            {v.label}
          </label>
        ))}
      </div>
      <p className="text-[11px] text-ink-muted">Xem trước — lựa chọn không được ghi nhận.</p>
    </div>
  );
}

/**
 * CER — claim/evidence/reasoning free-text + rubric criteria display.
 * Backend/hand-grading decides scoring; preview only shows the structure.
 */
export function CerActivityView({ activity }: PreviewActivityProps) {
  const rubric =
    activity.config?.rubric && typeof activity.config.rubric === "object"
      ? (activity.config.rubric as Record<string, unknown>)
      : null;
  const criteria = Array.isArray(rubric?.criteria)
    ? rubric.criteria.map((c) => String(c ?? "")).filter(Boolean)
    : [];
  const [claim, setClaim] = useState("");
  const [evidence, setEvidence] = useState("");
  const [reasoning, setReasoning] = useState("");

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`claim-${activity.id}`}>Luận điểm</Label>
        <Textarea
          id={`claim-${activity.id}`}
          rows={2}
          value={claim}
          onChange={(e) => setClaim(e.target.value)}
          placeholder="Học viên nêu luận điểm…"
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`ev-${activity.id}`}>Bằng chứng</Label>
        <Textarea
          id={`ev-${activity.id}`}
          rows={3}
          value={evidence}
          onChange={(e) => setEvidence(e.target.value)}
          placeholder="Trích dẫn bằng chứng hỗ trợ…"
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`re-${activity.id}`}>Lập luận</Label>
        <Textarea
          id={`re-${activity.id}`}
          rows={3}
          value={reasoning}
          onChange={(e) => setReasoning(e.target.value)}
          placeholder="Giải thích bằng chứng → luận điểm…"
        />
      </div>
      {criteria.length > 0 && (
        <div className="rounded-md bg-surface px-3 py-2">
          <p className="mb-1 text-xs font-semibold text-ink">Tiêu chí đánh giá:</p>
          <ul className="flex flex-col gap-1">
            {criteria.map((c, i) => (
              <li key={i} className="text-xs text-ink-muted">
                {i + 1}. {c}
              </li>
            ))}
          </ul>
        </div>
      )}
      <p className="text-[11px] text-ink-muted">Xem trước — bài viết không được lưu/chấm.</p>
    </div>
  );
}
