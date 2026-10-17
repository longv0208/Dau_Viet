"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Eye, Save, UploadCloud } from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { AdminLessonDetail } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { ErrorState } from "@/components/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";
import { useUnsavedChangesGuard } from "@/components/unsaved-changes-guard";

import { CompletionEditor } from "./completion-editor";
import { parseDraft, serializeDraft, allIds } from "./draft-model";
import { PublishReadinessCard } from "./publish-readiness-card";
import { StageEditor } from "./stage-editor";
import { StageNavigator } from "./stage-navigator";
import { TemplateSeedButton } from "./template-seed-button";
import { makeStage, useBuilder, type FieldError } from "./use-builder";
import { ValidationPanel } from "./validation-panel";

interface ServerErrorItem {
  path?: string;
  code?: string;
  message?: string;
}

function readServerErrors(err: ApiClientError): FieldError[] {
  const raw = err.details?.errors;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((x) => x && typeof x === "object")
    .map((x) => {
      const r = x as ServerErrorItem;
      return {
        path: String(r.path ?? ""),
        code: String(r.code ?? ""),
        message: String(r.message ?? ""),
      };
    });
}

export function BuilderPage({ lessonId }: { lessonId: string }) {
  const qc = useQueryClient();
  const [conflict, setConflict] = useState(false);
  const [seedKey, setSeedKey] = useState(0);

  const lessonQuery = useQuery({
    queryKey: qk.lessons.detail(lessonId),
    queryFn: () => apiFetch<AdminLessonDetail>(`/admin/lessons/${lessonId}`),
  });
  const lesson = lessonQuery.data;

  const { initialDraft, parseError } = useMemo(() => {
    if (!lesson) return { initialDraft: null, parseError: null };
    try {
      return { initialDraft: parseDraft(lesson.draftJson), parseError: null };
    } catch (e) {
      return {
        initialDraft: null,
        parseError: e instanceof Error ? e.message : "Bản nháp không hợp lệ",
      };
    }
  }, [lesson]);

  // remount-on-seed: initialDraft chỉ tính một lần; key buộc useBuilder init lại sau reload.
  if (lessonQuery.isPending) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-8 w-80" />
        <Skeleton className="h-[28rem] w-full" />
      </div>
    );
  }
  if (lessonQuery.isError) {
    return <ErrorState error={lessonQuery.error} onRetry={() => lessonQuery.refetch()} />;
  }
  if (!lesson) return null;
  if (parseError) {
    return (
      <div className="rounded-md bg-error/10 px-4 py-3 text-sm text-error">
        Không đọc được bản nháp hiện có: {parseError}. Vui lòng sửa draftJson qua API trước khi
        dùng Builder.
      </div>
    );
  }
  if (!initialDraft) return null;

  return (
    <BuilderInner
      // key KHÔNG gồm rowVersion: tự lưu sẽ invalidate cache nhưng không remount,
      // giữ lại chip "Đã lưu" + selection. Chỉ seedKey (sau conflict-reload) remount.
      key={`${lesson.id}:${seedKey}`}
      lesson={lesson}
      initialDraft={initialDraft}
      onConflict={() => setConflict(true)}
      conflict={conflict}
      onReload={async () => {
        setConflict(false);
        await qc.invalidateQueries({ queryKey: qk.lessons.detail(lessonId) });
        setSeedKey((k) => k + 1);
      }}
    />
  );
}

function BuilderInner({
  lesson,
  initialDraft,
  conflict,
  onConflict,
  onReload,
}: {
  lesson: AdminLessonDetail;
  initialDraft: ReturnType<typeof parseDraft>;
  conflict: boolean;
  onConflict: () => void;
  onReload: () => void;
}) {
  const qc = useQueryClient();
  const { state, actions, selectedStage } = useBuilder(initialDraft, lesson.rowVersion);
  const readOnly = lesson.status === "ARCHIVED";
  const [saveError, setSaveError] = useState<string | null>(null);

  useUnsavedChangesGuard(state.dirty && !readOnly);

  const saveMutation = useMutation({
    // Capture revision + draft tại thời điểm bấm Lưu — nếu người dùng sửa tiếp
    // trong lúc PUT đang chạy, markSaved sẽ giữ dirty (không mất thay đổi mới).
    mutationFn: () => {
      const revision = state.revision;
      const body = serializeDraft(state.draft);
      return apiFetch<AdminLessonDetail>(`/admin/lessons/${lesson.id}/draft`, {
        method: "PUT",
        body: JSON.stringify({
          draftJson: body,
          expectedRowVersion: state.rowVersion,
        }),
      }).then((res) => ({ res, revision }));
    },
    onSuccess: ({ res, revision }) => {
      actions.markSaved(res.rowVersion, revision);
      setSaveError(null);
      qc.invalidateQueries({ queryKey: qk.lessons.detail(lesson.id) });
    },
    onError: (err) => {
      if (err instanceof ApiClientError) {
        if (err.status === 409) {
          onConflict();
          return;
        }
        const fields = readServerErrors(err);
        if (fields.length > 0) {
          actions.setErrors(fields);
          setSaveError("Bản nháp chưa hợp lệ — xem danh sách lỗi bên phải.");
          return;
        }
      }
      setSaveError(toUserMessage(err));
    },
  });

  // Khi đổi loại giai đoạn, các hoạt động không còn hợp lệ vẫn giữ nguyên —
  // backend sẽ báo STAGE_ACTIVITY_MISMATCH ở panel lỗi (SAVE tolerant).

  return (
    <div className="flex flex-col gap-4">
      {/* Thanh trạng thái + lưu */}
      <div className="flex flex-wrap items-center gap-3">
        <StatusChip status={lesson.status} />
        <span className="text-xs text-ink-muted">{lesson.title}</span>
        {state.dirty ? (
          <span className="rounded bg-warning/15 px-2 py-0.5 text-xs font-medium text-ink">
            Chưa lưu
          </span>
        ) : state.lastSavedAt ? (
          <span className="rounded bg-success/10 px-2 py-0.5 text-xs font-medium text-success">
            Đã lưu {new Date(state.lastSavedAt).toLocaleTimeString("vi-VN")}
          </span>
        ) : null}
        {!readOnly && (
          <Button
            className="ml-auto"
            disabled={!state.dirty || saveMutation.isPending}
            onClick={() => saveMutation.mutate()}
          >
            <Save className="size-4" />
            {saveMutation.isPending ? "Đang lưu..." : "Lưu nháp"}
          </Button>
        )}
        <Button
          asChild
          variant="secondary"
          title={state.dirty ? "Có thay đổi chưa lưu — preview sẽ dùng bản đã lưu gần nhất" : undefined}
        >
          <Link href={`/lessons/${lesson.id}/preview`}>
            <Eye className="size-4" />
            {state.dirty ? "Xem trước (bản đã lưu)" : "Xem trước"}
          </Link>
        </Button>
        <Button asChild variant="secondary">
          <Link href={`/lessons/${lesson.id}/publish`}>
            <UploadCloud className="size-4" />
            Xuất bản
          </Link>
        </Button>
      </div>

      {state.dirty && (
        <p className="rounded-md bg-warning/10 px-3 py-1.5 text-xs text-ink-muted">
          Có thay đổi chưa lưu — Xem trước và Kiểm tra xuất bản dùng bản đã lưu gần nhất. Lưu
          nháp trước để xem bản mới nhất.
        </p>
      )}

      {lesson.status === "PUBLISHED" && (
        <p className="rounded-md bg-warning/15 px-3 py-2 text-sm text-ink">
          Bài học đang ở trạng thái ĐÃ XUẤT BẢN. Thay đổi lưu vào bản nháp mới — phiên bản đã
          xuất bản cho học viên không bị ảnh hưởng cho tới khi xuất bản lại.
        </p>
      )}
      {readOnly && (
        <p className="rounded-md bg-warning/15 px-3 py-2 text-sm text-ink">
          Bài học đã lưu trữ — Builder chỉ để xem.
        </p>
      )}
      {conflict && (
        <div className="flex flex-wrap items-center gap-3 rounded-md bg-error/10 px-3 py-2 text-sm text-error">
          <p>Bản nháp đã bị người khác sửa đồng thời — thay đổi của bạn chưa được lưu.</p>
          <Button variant="secondary" size="sm" onClick={onReload}>
            Tải lại bản mới nhất
          </Button>
        </div>
      )}
      {saveError && !conflict && (
        <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
          {saveError}
        </p>
      )}

      {/* 3-pane */}
      <div className="grid gap-4 lg:grid-cols-[260px_1fr_300px]">
        <aside className="rounded-md border border-border bg-surface p-3">
          <StageNavigator
            draft={state.draft}
            selectedStageId={state.selectedStageId}
            readOnly={readOnly}
            onSelect={(id) => actions.selectStage(id)}
            onAdd={(type) =>
              actions.addStage(makeStage(type, allIds(state.draft)))
            }
            onMove={(id, dir) => actions.moveStage(id, dir)}
            onDuplicate={(id) => actions.duplicateStage(id)}
            onRemove={(id) => actions.removeStage(id)}
          />
        </aside>

        <main className="min-w-0 rounded-md border border-border bg-surface p-4">
          {selectedStage ? (
            <StageEditor
              draft={state.draft}
              stage={selectedStage}
              eventId={lesson.eventId}
              readOnly={readOnly}
              selectedActivityId={state.selectedActivityId}
              onUpdate={(patch) => actions.updateStage(selectedStage.id, patch)}
              onAddActivity={(a) => actions.addActivity(selectedStage.id, a)}
              onSelectActivity={(id) => actions.selectActivity(id)}
              onUpdateActivity={(aid, patch) =>
                actions.updateActivity(selectedStage.id, aid, patch)
              }
              onRemoveActivity={(aid) => actions.removeActivity(selectedStage.id, aid)}
              onMoveActivity={(aid, dir) => actions.moveActivity(selectedStage.id, aid, dir)}
            />
          ) : (
            <p className="py-16 text-center text-sm text-ink-muted">
              Chọn một giai đoạn ở cột trái — hoặc thêm giai đoạn mới để bắt đầu.
            </p>
          )}
        </main>

        <aside className="flex flex-col gap-3 rounded-md border border-border bg-surface p-3">
          <TemplateSeedButton
            templateId={lesson.templateId}
            draft={state.draft}
            readOnly={readOnly}
            onMerge={(stages) => actions.mergeStages(stages)}
          />
          <CompletionEditor
            draft={state.draft}
            readOnly={readOnly}
            onChange={(c) => actions.setCompletion(c)}
          />
          <ValidationPanel
            draft={state.draft}
            errors={state.serverErrors}
            onJump={(sid, aid) => {
              actions.selectStage(sid);
              if (aid) actions.selectActivity(aid);
            }}
          />
          <PublishReadinessCard
            lessonId={lesson.id}
            draft={state.dirty ? null : state.draft}
            onJump={(sid, aid) => {
              actions.selectStage(sid);
              if (aid) actions.selectActivity(aid);
            }}
          />
        </aside>
      </div>
    </div>
  );
}
