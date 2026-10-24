"use client";

/**
 * Two-panel template designer.
 *
 * LEFT  (library)  — all 9 stage types with their allowed activities
 *                    always expanded; independent scroll.
 * RIGHT (canvas)   — the skeleton being built; independent scroll.
 *
 * Adding an activity from the library targets the selected stage of the
 * same type, creates a new stage when none exists, or asks which stage
 * to use when several stages share the type. After every add the canvas
 * scrolls to the target stage and the new activity is highlighted.
 */
import { ArrowDown, ArrowUp, ArrowUpToLine, Eye, Plus, Search, Trash2, X } from "lucide-react";
import { useMemo, useRef, useState } from "react";

import { cn } from "@/lib/utils";
import { useMediaQuery } from "@/lib/use-media-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  STAGE_LABELS,
  ACTIVITY_LABELS,
} from "@/features/lessons/builder/labels";

import {
  ALL_ACTIVITIES_COVERED,
  OPEN_ENDED_ACTIVITIES,
  STAGE_ALLOWED_ACTIVITIES,
  STAGE_TYPES,
  allWorkingIds,
  isNonLinearDraft,
  linearize,
  makeTemplateActivity,
  makeTemplateStage,
  stageMatches,
  type Activity,
  type ActivityType,
  type Draft,
  type Stage,
  type StageType,
} from "./template-catalog";

/* ---------- helpers ---------- */

function stageDisplayTitle(s: Stage, index: number): string {
  const label = STAGE_LABELS[s.type]?.label ?? s.type;
  return s.title?.trim() || `${label} ${index + 1}`;
}

/* ---------- left panel: library ---------- */

function StageLibraryCard({
  type,
  onAddStage,
  onAddActivity,
}: {
  type: StageType;
  onAddStage: (t: StageType) => void;
  onAddActivity: (t: StageType, a: ActivityType) => void;
}) {
  const meta = STAGE_LABELS[type];
  const StageIcon = meta.icon;
  const allowed = STAGE_ALLOWED_ACTIVITIES[type] ?? [];
  return (
    <section
      id={`lib-stage-${type}`}
      aria-label={`Giai đoạn ${meta.label}`}
      className="rounded-lg border border-border bg-white"
    >
      <header className="flex items-start justify-between gap-2 border-b border-border px-3 py-2.5">
        <div className="flex items-start gap-2.5">
          <StageIcon className="mt-0.5 size-5 shrink-0 text-brand" aria-hidden />
          <div>
            <h3 className="text-sm font-semibold text-ink">{meta.label}</h3>
            <p className="text-xs text-ink-muted">{meta.description}</p>
          </div>
        </div>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => onAddStage(type)}
          aria-label={`Thêm giai đoạn ${meta.label} vào khung`}
        >
          <Plus className="size-3.5" aria-hidden />
          Thêm giai đoạn
        </Button>
      </header>
      <ul className="flex flex-col gap-1.5 p-2.5">
        {allowed.map((t) => {
          const a = ACTIVITY_LABELS[t];
          const Icon = a.icon;
          const openEnded = OPEN_ENDED_ACTIVITIES.has(t);
          return (
            <li
              key={t}
              className="flex items-start gap-2.5 rounded-md border border-border/70 bg-surface px-2.5 py-2"
            >
              <Icon className="mt-0.5 size-4 shrink-0 text-ink-muted" aria-hidden />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium text-ink">{a.label}</p>
                <p className="text-xs text-ink-muted">{a.description}</p>
                {openEnded && (
                  <p className="mt-0.5 text-xs text-warning">
                    Câu trả lời tự do — cần giáo viên chấm, hệ thống chưa tự đánh giá tin cậy.
                  </p>
                )}
              </div>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={() => onAddActivity(type, t)}
                aria-label={`Thêm hoạt động ${a.label} vào giai đoạn ${meta.label}`}
              >
                <Plus className="size-3.5" aria-hidden />
                Thêm
              </Button>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

/* ---------- right panel: canvas ---------- */

function CanvasStageCard({
  stage,
  index,
  total,
  selected,
  highlightId,
  onSelect,
  onMove,
  onRemove,
  onRetitle,
  onActivityMove,
  onActivityRemove,
  registerRef,
}: {
  stage: Stage;
  index: number;
  total: number;
  selected: boolean;
  highlightId: string | null;
  onSelect: () => void;
  onMove: (from: number, to: number) => void;
  onRemove: () => void;
  onRetitle: (title: string) => void;
  onActivityMove: (stageId: string, from: number, to: number) => void;
  onActivityRemove: (stageId: string, activityId: string) => void;
  registerRef: (el: HTMLElement | null) => void;
}) {
  const meta = STAGE_LABELS[stage.type];
  const Icon = meta.icon;
  return (
    <section
      ref={registerRef}
      data-stage-id={stage.id}
      aria-label={`Giai đoạn ${index + 1}: ${stageDisplayTitle(stage, index)}`}
      className={cn(
        "rounded-lg border bg-white transition-colors",
        selected ? "border-brand ring-1 ring-brand/30" : "border-border",
      )}
    >
      <header
        className="flex items-center gap-2 border-b border-border px-3 py-2"
        onClick={onSelect}
      >
        <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-brand/10 text-xs font-semibold text-brand">
          {index + 1}
        </span>
        <Icon className="size-4 shrink-0 text-ink-muted" aria-hidden />
        <div className="min-w-0 flex-1">
          <Input
            value={stage.title ?? ""}
            onChange={(e) => onRetitle(e.target.value)}
            onFocus={onSelect}
            placeholder={`Tiêu đề — ${meta.label}`}
            aria-label={`Tiêu đề giai đoạn ${index + 1}`}
            className="h-7 border-transparent bg-transparent px-1 text-sm font-medium focus:border-border"
          />
          <p className="px-1 text-xs text-ink-muted">
            {meta.label} · {stage.activities.length} hoạt động
          </p>
        </div>
        <div className="flex shrink-0 items-center gap-1">
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={(e) => {
              e.stopPropagation();
              onMove(index, index - 1);
            }}
            disabled={index === 0}
            aria-label={`Đưa giai đoạn ${index + 1} lên`}
          >
            <ArrowUp className="size-3.5" aria-hidden />
          </Button>
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={(e) => {
              e.stopPropagation();
              onMove(index, index + 1);
            }}
            disabled={index === total - 1}
            aria-label={`Đưa giai đoạn ${index + 1} xuống`}
          >
            <ArrowDown className="size-3.5" aria-hidden />
          </Button>
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={(e) => {
              e.stopPropagation();
              onRemove();
            }}
            aria-label={`Xoá giai đoạn ${index + 1}`}
          >
            <Trash2 className="size-3.5" aria-hidden />
          </Button>
        </div>
      </header>
      {stage.activities.length === 0 ? (
        <p className="px-3 py-3 text-xs text-ink-muted">
          Chưa có hoạt động — chọn từ thư viện bên trái.
        </p>
      ) : (
        <ul className="flex flex-col gap-1 p-2">
          {stage.activities.map((a, ai) => {
            const aMeta = ACTIVITY_LABELS[a.type as ActivityType] ?? {
              label: a.type,
              description: "",
              icon: Plus,
            };
            return (
              <li
                key={a.id}
                data-activity-id={a.id}
                className={cn(
                  "flex items-center gap-2 rounded-md border border-border/60 bg-surface px-2 py-1.5",
                  highlightId === a.id && "border-brand bg-brand/10",
                )}
              >
                <span className="min-w-0 flex-1 text-sm text-ink">{aMeta.label}</span>
                {a.required && (
                  <span className="rounded bg-brand/10 px-1.5 py-0.5 text-[10px] font-medium text-brand">
                    Bắt buộc
                  </span>
                )}
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  onClick={() => onActivityMove(stage.id, ai, ai - 1)}
                  disabled={ai === 0}
                  aria-label={`Đưa hoạt động ${aMeta.label} lên`}
                >
                  <ArrowUp className="size-3" aria-hidden />
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  onClick={() => onActivityMove(stage.id, ai, ai + 1)}
                  disabled={ai === stage.activities.length - 1}
                  aria-label={`Đưa hoạt động ${aMeta.label} xuống`}
                >
                  <ArrowDown className="size-3" aria-hidden />
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  onClick={() => onActivityRemove(stage.id, a.id)}
                  aria-label={`Xoá hoạt động ${aMeta.label}`}
                >
                  <X className="size-3" aria-hidden />
                </Button>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

/* ---------- main designer ---------- */

export interface TemplateDesignerProps {
  /** Working stage list (already rehydrated from presetJson). */
  stages: Stage[];
  onChange: (stages: Stage[]) => void;
  /** Source draft the stages were rehydrated from — non-linear graphs
   * lock the canvas into read-only so a branchy preset is never
   * silently flattened. */
  sourceDraft?: Draft | null;
  /** Opens the structure preview dialog. */
  onPreview?: () => void;
}

export function TemplateDesigner({ stages, onChange, sourceDraft, onPreview }: TemplateDesignerProps) {
  const [query, setQuery] = useState("");
  /** Chip-filtered stage type — the library shows only this card while set. */
  const [focusType, setFocusType] = useState<StageType | null>(null);
  const [selectedStageId, setSelectedStageId] = useState<string | null>(null);
  const [pendingPick, setPendingPick] = useState<{
    stageType: StageType;
    activityType: ActivityType;
    candidates: Stage[];
  } | null>(null);
  const [highlightId, setHighlightId] = useState<string | null>(null);
  const [mobileTab, setMobileTab] = useState<"library" | "canvas">("library");
  // Narrow screens swap the two panels for tabs — rendered once, so the
  // a11y tree never contains a duplicate library/canvas.
  const isNarrow = useMediaQuery("(max-width: 767px)");

  const canvasRef = useRef<HTMLDivElement>(null);
  const libraryRef = useRef<HTMLDivElement>(null);
  const stageEls = useRef(new Map<string, HTMLElement>());
  const highlightTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const locked = sourceDraft ? isNonLinearDraft(sourceDraft) : false;

  const totalStages = stages.length;
  const totalActivities = useMemo(
    () => stages.reduce((n, s) => n + s.activities.length, 0),
    [stages],
  );

  const visibleStageTypes = useMemo(
    () =>
      STAGE_TYPES.filter(
        (t) =>
          (!focusType || t === focusType) &&
          stageMatches(t, query.trim(), STAGE_LABELS[t], (a) => ACTIVITY_LABELS[a]),
      ),
    [query, focusType],
  );

  const scrollToStage = (stageId: string) => {
    const el = stageEls.current.get(stageId);
    // jsdom lacks scrollIntoView — guard so tests and old engines don't crash.
    el?.scrollIntoView?.({ behavior: "smooth", block: "nearest" });
  };

  const flash = (activityId: string) => {
    if (highlightTimer.current) clearTimeout(highlightTimer.current);
    setHighlightId(activityId);
    highlightTimer.current = setTimeout(() => setHighlightId(null), 1600);
  };

  const mutate = (next: Stage[]) => onChange(linearize(next));

  const addStage = (type: StageType) => {
    const st = makeTemplateStage(type, allWorkingIds(stages));
    const next = [...stages, st];
    mutate(next);
    setSelectedStageId(st.id);
    requestAnimationFrame(() => scrollToStage(st.id));
  };

  const insertActivity = (stageId: string, type: ActivityType) => {
    const act = makeTemplateActivity(type, allWorkingIds(stages));
    const next = stages.map((s) =>
      s.id === stageId ? { ...s, activities: [...s.activities, act] } : s,
    );
    mutate(next);
    setSelectedStageId(stageId);
    requestAnimationFrame(() => {
      scrollToStage(stageId);
      flash(act.id);
    });
  };

  /** "+ Thêm" on a library activity — resolve the target stage per spec. */
  const addActivity = (stageType: StageType, activityType: ActivityType) => {
    if (locked) return;
    const sameType = stages.filter((s) => s.type === stageType);
    if (sameType.length === 0) {
      // No stage of this type — create it, then add the activity.
      const st = makeTemplateStage(stageType, allWorkingIds(stages));
      const act = makeTemplateActivity(activityType, [...allWorkingIds(stages), st.id]);
      mutate([...stages, { ...st, activities: [act] }]);
      setSelectedStageId(st.id);
      requestAnimationFrame(() => {
        scrollToStage(st.id);
        flash(act.id);
      });
      return;
    }
    const selected = sameType.find((s) => s.id === selectedStageId);
    if (selected) {
      insertActivity(selected.id, activityType);
      return;
    }
    if (sameType.length === 1) {
      insertActivity(sameType[0]!.id, activityType);
      return;
    }
    // Several stages share the type and none is selected — ask.
    setPendingPick({ stageType, activityType, candidates: sameType });
  };

  const removeStage = (index: number) => {
    const s = stages[index]!;
    const label = stageDisplayTitle(s, index);
    const msg =
      s.activities.length > 0
        ? `Xoá "${label}" cùng ${s.activities.length} hoạt động bên trong?`
        : `Xoá "${label}"?`;
    if (!window.confirm(msg)) return;
    mutate(stages.filter((_, i) => i !== index));
    if (selectedStageId === s.id) setSelectedStageId(null);
  };

  const moveStage = (from: number, to: number) => {
    if (to < 0 || to >= stages.length) return;
    const next = [...stages];
    const [s] = next.splice(from, 1);
    next.splice(to, 0, s!);
    mutate(next);
  };

  const retitle = (stageId: string, title: string) => {
    onChange(stages.map((s) => (s.id === stageId ? { ...s, title } : s)));
  };

  const moveActivity = (stageId: string, from: number, to: number) => {
    const next = stages.map((s) => {
      if (s.id !== stageId) return s;
      if (to < 0 || to >= s.activities.length) return s;
      const acts = [...s.activities];
      const [a] = acts.splice(from, 1);
      acts.splice(to, 0, a!);
      return { ...s, activities: acts };
    });
    onChange(next);
  };

  const removeActivity = (stageId: string, activityId: string) => {
    onChange(
      stages.map((s) =>
        s.id === stageId
          ? { ...s, activities: s.activities.filter((a) => a.id !== activityId) }
          : s,
      ),
    );
  };

  const libraryPanel = (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="sticky top-0 z-10 flex flex-col gap-2 border-b border-border bg-surface px-3 py-2">
        <div className="relative">
          <Search className="pointer-events-none absolute left-2.5 top-2.5 size-4 text-ink-muted" aria-hidden />
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Tìm giai đoạn hoặc hoạt động…"
            aria-label="Tìm giai đoạn hoặc hoạt động"
            className="pl-8"
          />
        </div>
        <nav aria-label="Điều hướng nhanh giai đoạn" className="flex flex-wrap gap-1">
          {STAGE_TYPES.map((t) => {
            const active = focusType === t;
            return (
              <button
                key={t}
                type="button"
                aria-pressed={active}
                onClick={() => {
                  // Toggle: bấm chip đang chọn để hiện lại toàn bộ thư viện.
                  setFocusType(active ? null : t);
                  if (!active) {
                    libraryRef.current?.scrollTo?.({ top: 0, behavior: "smooth" });
                  }
                }}
                className={`rounded-full border px-2 py-0.5 text-xs ${
                  active
                    ? "border-brand bg-brand text-white"
                    : "border-border bg-white text-ink hover:border-brand hover:text-brand"
                }`}
              >
                {STAGE_LABELS[t].label}
              </button>
            );
          })}
          <button
            type="button"
            onClick={() => libraryRef.current?.scrollTo({ top: 0, behavior: "smooth" })}
            aria-label="Lên đầu danh sách"
            className="ml-auto rounded-full border border-border bg-white px-2 py-0.5 text-xs text-ink-muted hover:text-brand"
          >
            <ArrowUpToLine className="size-3.5" aria-hidden />
          </button>
        </nav>
      </div>
      <div ref={libraryRef} className="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto p-3">
        {visibleStageTypes.length === 0 && (
          <p className="py-8 text-center text-sm text-ink-muted">
            Không có giai đoạn hoặc hoạt động nào khớp “{query}”.
          </p>
        )}
        {visibleStageTypes.map((t) => (
          <StageLibraryCard
            key={t}
            type={t}
            onAddStage={addStage}
            onAddActivity={addActivity}
          />
        ))}
      </div>
    </div>
  );

  const canvasPanel = (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="sticky top-0 z-10 flex items-center gap-2 border-b border-border bg-surface px-3 py-2">
        <h2 className="text-sm font-semibold text-ink">Khung đang thiết kế</h2>
        <span className="text-xs text-ink-muted">
          {totalStages} giai đoạn · {totalActivities} hoạt động
        </span>
        <div className="ml-auto flex items-center gap-1">
          {onPreview && (
            <Button type="button" variant="secondary" size="sm" onClick={onPreview}>
              <Eye className="size-3.5" aria-hidden />
              Xem cấu trúc
            </Button>
          )}
          <button
            type="button"
            onClick={() => canvasRef.current?.scrollTo({ top: 0, behavior: "smooth" })}
            aria-label="Lên đầu khung"
            className="rounded-full border border-border bg-white p-1.5 text-ink-muted hover:text-brand"
          >
            <ArrowUpToLine className="size-3.5" aria-hidden />
          </button>
        </div>
      </div>
      {locked && (
        <p className="border-b border-warning/40 bg-warning/15 px-3 py-2 text-xs text-ink">
          Khung này chứa luồng rẽ nhánh (nextStageIds không tuyến tính) — trình thiết kế
          đang ở chế độ chỉ đọc để không làm mất cấu trúc. Chỉnh sửa bằng JSON nếu cần.
        </p>
      )}
      <div ref={canvasRef} className="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto p-3">
        {stages.length === 0 && (
          <div className="rounded-md border border-dashed border-border px-6 py-12 text-center">
            <p className="text-sm font-medium text-ink">Khung đang trống</p>
            <p className="mt-1 text-xs text-ink-muted">
              Chọn “Thêm giai đoạn” hoặc “+ Thêm” một hoạt động từ thư viện bên trái.
            </p>
          </div>
        )}
        {stages.map((s, i) => (
          <CanvasStageCard
            key={s.id}
            stage={s}
            index={i}
            total={stages.length}
            selected={selectedStageId === s.id}
            highlightId={highlightId}
            onSelect={() => setSelectedStageId(s.id)}
            onMove={locked ? () => {} : moveStage}
            onRemove={locked ? () => {} : () => removeStage(i)}
            onRetitle={(t) => retitle(s.id, t)}
            onActivityMove={locked ? () => {} : moveActivity}
            onActivityRemove={locked ? () => {} : removeActivity}
            registerRef={(el) => {
              if (el) stageEls.current.set(s.id, el);
              else stageEls.current.delete(s.id);
            }}
          />
        ))}
      </div>
    </div>
  );

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      {/* Mobile tab switch — two panels never squeeze below usable width. */}
      {isNarrow && (
      <div className="flex gap-1 border-b border-border pb-2" role="tablist">
        <button
          type="button"
          role="tab"
          aria-selected={mobileTab === "library"}
          onClick={() => setMobileTab("library")}
          className={cn(
            "flex-1 rounded-md px-3 py-2 text-sm font-medium",
            mobileTab === "library" ? "bg-brand text-white" : "bg-surface text-ink",
          )}
        >
          Thư viện giai đoạn
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={mobileTab === "canvas"}
          onClick={() => setMobileTab("canvas")}
          className={cn(
            "flex-1 rounded-md px-3 py-2 text-sm font-medium",
            mobileTab === "canvas" ? "bg-brand text-white" : "bg-surface text-ink",
          )}
        >
          Khung đang thiết kế
        </button>
      </div>
      )}

      {/* Desktop: two columns with independent scroll; narrow: active tab. */}
      {isNarrow ? (
        <div className="flex min-h-0 flex-1">
          {mobileTab === "library" ? libraryPanel : canvasPanel}
        </div>
      ) : (
        <div className="grid min-h-0 flex-1 gap-4 md:grid-cols-[55fr_45fr]">
          {libraryPanel}
          {canvasPanel}
        </div>
      )}

      {/* Multi-target picker: several stages share the type — ask which one. */}
      {pendingPick && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Chọn giai đoạn nhận hoạt động"
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
        >
          <div className="w-full max-w-sm rounded-lg bg-white p-4 shadow-lg">
            <h3 className="text-sm font-semibold text-ink">Thêm vào giai đoạn nào?</h3>
            <p className="mt-1 text-xs text-ink-muted">
              Khung đang có {pendingPick.candidates.length} giai đoạn “
              {STAGE_LABELS[pendingPick.stageType].label}” — chọn đích nhận “
              {ACTIVITY_LABELS[pendingPick.activityType].label}”.
            </p>
            <ul className="mt-3 flex flex-col gap-1.5">
              {pendingPick.candidates.map((s) => {
                const idx = stages.findIndex((x) => x.id === s.id);
                return (
                  <li key={s.id}>
                    <button
                      type="button"
                      onClick={() => {
                        insertActivity(s.id, pendingPick.activityType);
                        setPendingPick(null);
                      }}
                      className="w-full rounded-md border border-border px-3 py-2 text-left text-sm hover:border-brand hover:bg-brand/5"
                    >
                      Giai đoạn {idx + 1} — {stageDisplayTitle(s, idx)}
                      <span className="block text-xs text-ink-muted">
                        {s.activities.length} hoạt động
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
            <Button
              type="button"
              variant="secondary"
              className="mt-3 w-full"
              onClick={() => setPendingPick(null)}
            >
              Huỷ
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
