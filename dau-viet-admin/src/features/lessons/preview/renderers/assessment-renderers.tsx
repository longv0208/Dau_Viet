"use client";

import { useState } from "react";

import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { evidenceLabel, findEvidence } from "./resolve-evidence";
import type { PreviewActivityProps } from "./types";

/**
 * VERIFICATION — Learning Flow 2.0 (TASK-0020 §P7): preview hiển thị lại
 * giả thuyết đã chọn + bằng chứng đã thu thập (đọc từ config.priorOutputs,
 * cùng contract VerificationHandler/server dùng để chấm) cộng với
 * visibleSourceIds để đối chiếu. Học viên chỉ thực hiện một hành động
 * kiểm chứng có chủ đích ({action:"verify"}) — verdict do server quyết
 * định, không có radio chọn verdict ở client. requiredEvidenceIds là
 * hidden key (đã bị projection strip) nên không render.
 */
export function VerificationActivityView({ activity, evidence }: PreviewActivityProps) {
  const config = activity.config ?? {};
  const sources = Array.isArray(config.visibleSourceIds)
    ? (config.visibleSourceIds as unknown[]).map((x) => String(x ?? "")).filter(Boolean)
    : [];

  // Giả thuyết đã chọn — output HYPOTHESIS_CHOICE mang `hypothesisId`.
  const priorHypothesisId = (() => {
    const prior = config.priorOutputs;
    if (!prior || typeof prior !== "object") return null;
    for (const out of Object.values(prior as Record<string, unknown>)) {
      if (out && typeof out === "object") {
        const id = (out as Record<string, unknown>).hypothesisId;
        if (typeof id === "string" && id) return id;
      }
    }
    return null;
  })();

  // Bằng chứng đã thu thập — config.evidenceSource trỏ tới output
  // EVIDENCE_SELECT; snapshot cũ fallback về hypothesis.evidenceIds.
  const givenEvidenceIds = (() => {
    const prior = config.priorOutputs;
    if (!prior || typeof prior !== "object") return [] as string[];
    const source = config.evidenceSource;
    if (typeof source === "string" && source) {
      const out = (prior as Record<string, unknown>)[source];
      const ids = out && typeof out === "object"
        ? (out as Record<string, unknown>).selectedEvidenceIds
        : undefined;
      return Array.isArray(ids) ? ids.map((x) => String(x ?? "")) : [];
    }
    for (const out of Object.values(prior as Record<string, unknown>)) {
      if (out && typeof out === "object") {
        const o = out as Record<string, unknown>;
        if (typeof o.hypothesisId === "string" && Array.isArray(o.evidenceIds)) {
          return o.evidenceIds.map((x) => String(x ?? ""));
        }
      }
    }
    return [] as string[];
  })();

  return (
    <div className="flex flex-col gap-3">
      {priorHypothesisId && (
        <div className="flex flex-col gap-1.5">
          <p className="text-xs font-semibold uppercase tracking-wide text-ink-muted">
            Giả thuyết đã chọn
          </p>
          <div className="rounded-md border border-brand bg-brand/5 px-3 py-2">
            <p className="text-sm font-medium text-ink">{priorHypothesisId}</p>
          </div>
        </div>
      )}
      {givenEvidenceIds.length > 0 && (
        <div className="flex flex-col gap-1.5">
          <p className="text-xs font-semibold uppercase tracking-wide text-ink-muted">
            Bằng chứng đã thu thập
          </p>
          <div className="flex flex-col gap-1.5">
            {givenEvidenceIds.map((id, i) => (
              <div
                key={id}
                className="rounded-md border border-brand bg-brand/5 px-3 py-2"
              >
                <p className="text-xs font-medium text-ink">
                  {evidenceLabel(evidence, id, `Bằng chứng ${i + 1}`)}
                </p>
              </div>
            ))}
          </div>
        </div>
      )}
      <p className="text-sm font-medium text-ink">Đối chiếu với các nguồn:</p>
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
      <button
        type="button"
        disabled
        className="mt-1 h-11 cursor-not-allowed rounded-md bg-brand/60 px-4 text-sm font-semibold text-white"
      >
        Kiểm chứng
      </button>
      <p className="text-[11px] text-ink-muted">
        Xem trước — nút kiểm chứng bị vô hiệu; server chấm SUPPORTED/PARTIAL/CONTRADICTED
        từ bằng chứng đã thu thập, không tin lựa chọn của client.
      </p>
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

/**
 * CER_CHOICE — 3 pick cards: claim radio, evidence checkboxes (resolved to
 * evidence titles via the embedded docs), reasoning radio. Answer keys are
 * stripped server-side; preview is non-graded.
 */
export function CerChoiceActivityView({ activity, evidence }: PreviewActivityProps) {
  const config = activity.config ?? {};
  const claims = Array.isArray(config.claims)
    ? (config.claims as Record<string, unknown>[]).map((o) => ({
        id: String(o.id ?? ""),
        text: String(o.text ?? o.label ?? ""),
      }))
    : [];
  const reasoningOptions = Array.isArray(config.reasoningOptions)
    ? (config.reasoningOptions as Record<string, unknown>[]).map((o) => ({
        id: String(o.id ?? ""),
        text: String(o.text ?? o.label ?? ""),
      }))
    : [];
  const evidenceOptionIds = Array.isArray(config.evidenceOptions)
    ? (config.evidenceOptions as Record<string, unknown>[]).map((o) => String(o.id ?? ""))
    : [];
  const priorEvidenceIds = (() => {
    const prior = config.priorOutputs;
    const source = config.priorEvidenceSource;
    if (!prior || typeof prior !== "object" || !source || typeof source !== "string") return [];
    const out = (prior as Record<string, unknown>)[source];
    const ids = out && typeof out === "object"
      ? (out as Record<string, unknown>).selectedEvidenceIds
      : undefined;
    return Array.isArray(ids) ? ids.map((x) => String(x ?? "")) : [];
  })();

  const [claim, setClaim] = useState<string>("");
  const [reasoning, setReasoning] = useState<string>("");
  const [picked, setPicked] = useState<Set<string>>(new Set(priorEvidenceIds));

  function toggleEvidence(id: string) {
    setPicked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        <p className="text-sm font-medium text-ink">1. Chọn kết luận</p>
        {claims.map((c) => (
          <label
            key={c.id}
            className={
              "flex items-start gap-2.5 rounded-md border px-3 py-2 text-sm " +
              (claim === c.id ? "border-brand bg-brand/5" : "border-border")
            }
          >
            <input
              type="radio"
              name={`claim-${activity.id}`}
              checked={claim === c.id}
              onChange={() => setClaim(c.id)}
              className="mt-0.5 size-4 accent-brand"
            />
            {c.text}
          </label>
        ))}
      </div>
      <div className="flex flex-col gap-2">
        <p className="text-sm font-medium text-ink">2. Chọn bằng chứng hỗ trợ</p>
        {priorEvidenceIds.length > 0 && (
          <p className="text-xs text-ink-muted">
            Đã điền sẵn {priorEvidenceIds.length} bằng chứng đã chọn trước đó.
          </p>
        )}
        {evidenceOptionIds.map((id, i) => (
          <label
            key={id}
            className={
              "flex items-start gap-2.5 rounded-md border px-3 py-2 text-sm " +
              (picked.has(id) ? "border-brand bg-brand/5" : "border-border")
            }
          >
            <input
              type="checkbox"
              checked={picked.has(id)}
              onChange={() => toggleEvidence(id)}
              className="mt-0.5 size-4 accent-brand"
            />
            {evidenceLabel(evidence, id, `Bằng chứng ${i + 1}`)}
          </label>
        ))}
        {evidenceOptionIds.length === 0 && (
          <p className="text-sm italic text-ink-muted">Chưa khai báo bằng chứng nào.</p>
        )}
      </div>
      <div className="flex flex-col gap-2">
        <p className="text-sm font-medium text-ink">3. Chọn lập luận</p>
        {reasoningOptions.map((r) => (
          <label
            key={r.id}
            className={
              "flex items-start gap-2.5 rounded-md border px-3 py-2 text-sm " +
              (reasoning === r.id ? "border-brand bg-brand/5" : "border-border")
            }
          >
            <input
              type="radio"
              name={`reasoning-${activity.id}`}
              checked={reasoning === r.id}
              onChange={() => setReasoning(r.id)}
              className="mt-0.5 size-4 accent-brand"
            />
            {r.text}
          </label>
        ))}
      </div>
      <p className="text-[11px] text-ink-muted">Xem trước — lựa chọn không được ghi nhận.</p>
    </div>
  );
}
