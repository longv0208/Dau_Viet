"use client";

import type { Activity, Draft, Stage } from "./draft-model";
import { STAGE_LABELS } from "./labels";
import { ChapterBadge } from "@/components/atoms/chapter-badge";
import { SectionDivider } from "@/components/atoms/section-divider";

const STEP_LABELS: Record<string, string> = {
  DISCOVERY: "TRUY TÌM DẤU VẾT",
  HYPOTHESIS: "ĐẶT GIẢ THUYẾT",
  VERIFICATION: "KIỂM CHỨNG",
  RECONSTRUCTION: "TÁI HIỆN SỰ KIỆN",
};

const CLUE_LABELS: Record<string, string> = {
  CONTEXT: "Bối cảnh",
  CHARACTERS: "Nhân vật",
  DEVELOPMENT: "Diễn biến",
  SIGNIFICANCE: "Ý nghĩa",
};

const CLUE_ORDER = ["CONTEXT", "CHARACTERS", "DEVELOPMENT", "SIGNIFICANCE"] as const;

interface Props {
  draft: Draft;
  selectedStageId: string | null;
  selectedActivityId: string | null;
  readOnly?: boolean;
  onSelect: (stageId: string, activityId?: string) => void;
}

function activityStatus(act: Activity): "empty" | "partial" | "valid" {
  const hasContent =
    (act.instruction?.trim() ?? "").length > 0 ||
    Object.keys(act.config ?? {}).length > 0;
  if (!hasContent) return "empty";
  return "valid";
}

function clueStatus(
  stage: Stage | undefined,
  clueType: string,
): "empty" | "partial" | "valid" {
  if (!stage) return "empty";
  const act = stage.activities.find((a) => a.clueType === clueType);
  if (!act) return "empty";
  return activityStatus(act);
}

const statusDot: Record<string, string> = {
  empty: "bg-border",
  partial: "bg-warning",
  valid: "bg-success",
};

const statusText: Record<string, string> = {
  empty: "Chưa cấu hình",
  partial: "Đang chỉnh sửa",
  valid: "Hợp lệ",
};

export function FourStepNavigator({
  draft,
  selectedStageId,
  selectedActivityId,
  readOnly,
  onSelect,
}: Props) {
  const discoveryStage = draft.stages.find((s) => s.type === "DISCOVERY");
  const hypothesisStage = draft.stages.find((s) => s.type === "HYPOTHESIS");
  const verificationStage = draft.stages.find((s) => s.type === "VERIFICATION");
  const reconstructionStage = draft.stages.find((s) => s.type === "RECONSTRUCTION");

  function renderStage(
    stage: Stage | undefined,
    stepType: string,
    stepNum: number,
  ) {
    if (!stage) return null;
    const meta = STAGE_LABELS[stepType as keyof typeof STAGE_LABELS];
    const Icon = meta?.icon;
    const selected = stage.id === selectedStageId;

    return (
      <li key={stage.id}>
        <div
          className={
            "rounded-md border p-2 transition-colors " +
            (selected
              ? "border-brand bg-brand/5"
              : "border-border bg-surface hover:bg-surface-alt")
          }
        >
          <button
            type="button"
            onClick={() => onSelect(stage.id)}
            className="flex w-full items-start gap-2 text-left"
          >
            <ChapterBadge
              label={stepNum}
              size={22}
              filled={selected}
              className="mt-0.5 text-[10px]"
            />
            <span className="min-w-0 flex-1">
              <span className="flex items-center gap-1.5 truncate text-sm font-medium text-ink">
                {Icon && <Icon className="size-3.5 shrink-0 text-ink-muted" aria-hidden />}
                <span className="truncate">{STEP_LABELS[stepType] ?? stage.title}</span>
              </span>
              {stepType === "DISCOVERY" && (
                <div className="mt-1.5 flex flex-col gap-1">
                  {CLUE_ORDER.map((ct) => {
                    const act = stage.activities.find((a) => a.clueType === ct);
                    const st = clueStatus(stage, ct);
                    const actSelected =
                      act?.id === selectedActivityId && stage.id === selectedStageId;
                    return (
                      <button
                        key={ct}
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          if (act) onSelect(stage.id, act.id);
                          else onSelect(stage.id);
                        }}
                        className={
                          "flex items-center gap-1.5 rounded px-1.5 py-1 text-left text-xs transition-colors " +
                          (actSelected
                            ? "bg-brand/15 text-ink"
                            : "text-ink-muted hover:bg-surface-alt hover:text-ink")
                        }
                      >
                        <span
                          className={`size-1.5 shrink-0 rounded-full ${statusDot[st]}`}
                          aria-hidden
                        />
                        <span className="flex-1 truncate">
                          {CLUE_LABELS[ct] ?? ct}
                        </span>
                        {act?.type && (
                          <span className="text-[10px] text-ink-muted/70">
                            {act.type.replace(/_/g, " ")}
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>
              )}
              {stepType !== "DISCOVERY" && stage.activities.length > 0 && (
                <div className="mt-1.5 flex flex-col gap-1">
                  {stage.activities.map((a) => {
                    const st = activityStatus(a);
                    const actSelected =
                      a.id === selectedActivityId && stage.id === selectedStageId;
                    return (
                      <button
                        key={a.id}
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          onSelect(stage.id, a.id);
                        }}
                        className={
                          "flex items-center gap-1.5 rounded px-1.5 py-1 text-left text-xs transition-colors " +
                          (actSelected
                            ? "bg-brand/15 text-ink"
                            : "text-ink-muted hover:bg-surface-alt hover:text-ink")
                        }
                      >
                        <span
                          className={`size-1.5 shrink-0 rounded-full ${statusDot[st]}`}
                          aria-hidden
                        />
                        <span className="flex-1 truncate">
                          {a.instruction?.slice(0, 30) || a.id}
                        </span>
                        <span className="text-[10px] text-ink-muted/70">
                          {a.type?.replace(/_/g, " ")}
                        </span>
                      </button>
                    );
                  })}
                </div>
              )}
              {stepType !== "DISCOVERY" && stage.activities.length === 0 && (
                <p className="mt-1 text-[10px] text-ink-muted/60">
                  Chưa có hoạt động — chọn bước này để thêm.
                </p>
              )}
            </span>
          </button>
        </div>
      </li>
    );
  }

  const steps = [
    { stage: discoveryStage, type: "DISCOVERY", num: 1 },
    { stage: hypothesisStage, type: "HYPOTHESIS", num: 2 },
    { stage: verificationStage, type: "VERIFICATION", num: 3 },
    { stage: reconstructionStage, type: "RECONSTRUCTION", num: 4 },
  ];

  return (
    <div className="flex flex-col gap-3">
      <SectionDivider
        eyebrow="CẤU TRÚC BÀI HỌC"
        title="4 bước học tập"
      />
      <ol className="flex flex-col gap-1.5">
        {steps.map(({ stage, type, num }) =>
          renderStage(stage, type, num),
        )}
      </ol>
      {draft.stages.length === 0 && (
        <p className="rounded-md border border-dashed border-border p-3 text-center text-xs text-ink-muted">
          Chưa có giai đoạn nào — dùng nút &quot;Tạo cấu trúc từ khung&quot; để tạo 4 bước.
        </p>
      )}
    </div>
  );
}
