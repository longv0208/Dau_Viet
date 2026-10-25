"use client";

import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { apiFetch } from "@/lib/api-client";
import type { AdminEventDetail } from "@/lib/dto/event";
import type {
  AdminCompletionPolicy,
  AdminCompletionPolicyUpsert,
  AdminDossierSummary,
  AdminEventDossierLink,
  AdminEventDossierLinkRequest,
  AdminPolicyValidation,
} from "@/lib/dto/gamification";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ErrorState } from "@/components/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { ConfirmDialog } from "@/components/confirm-dialog";

import { PolicyList } from "./gamification/policy-list";
import { PolicyEditor } from "./gamification/policy-editor";
import { PolicyPublishDialog } from "./gamification/policy-publish-dialog";
import { DossierLinkTable } from "./gamification/dossier-link-table";
import { DossierPickerDialog } from "./gamification/dossier-picker-dialog";

/**
 * Tab Gamification trong event workspace (GAME-06):
 * Section 1 = completion policy versions + editor + publish;
 * Section 2 = dossier links + reorder/remove/picker.
 */
export function EventGamificationTab({ event }: { event: AdminEventDetail }) {
  const qc = useQueryClient();
  const eventId = event.id;

  /* ---------- policy state ---------- */
  const policies = useQuery({
    queryKey: qk.policies.list(eventId),
    queryFn: () =>
      apiFetch<AdminCompletionPolicy[]>(
        `/admin/events/${eventId}/completion-policies`,
      ),
  });

  const [editing, setEditing] = useState<AdminCompletionPolicy | null | "new">(
    null,
  );
  const [validation, setValidation] =
    useState<AdminPolicyValidation | null>(null);
  const [publishTarget, setPublishTarget] =
    useState<AdminCompletionPolicy | null>(null);

  const invalidatePolicies = () =>
    qc.invalidateQueries({ queryKey: qk.policies.list(eventId) });

  const createDraft = useMutation({
    mutationFn: (req: AdminCompletionPolicyUpsert) =>
      apiFetch<AdminCompletionPolicy>(
        `/admin/events/${eventId}/completion-policies`,
        { method: "POST", body: JSON.stringify(req) },
      ),
    onSuccess: () => {
      setEditing(null);
      setValidation(null);
      invalidatePolicies();
    },
  });

  const updateDraft = useMutation({
    mutationFn: ({
      id,
      req,
    }: {
      id: string;
      req: AdminCompletionPolicyUpsert;
    }) =>
      apiFetch<AdminCompletionPolicy>(
        `/admin/events/${eventId}/completion-policies/${id}`,
        { method: "PUT", body: JSON.stringify(req) },
      ),
    onSuccess: () => {
      setEditing(null);
      setValidation(null);
      invalidatePolicies();
    },
  });

  const validate = useMutation({
    mutationFn: ({
      id,
      req,
    }: {
      id: string;
      req: AdminCompletionPolicyUpsert;
    }) =>
      apiFetch<AdminPolicyValidation>(
        `/admin/events/${eventId}/completion-policies/${id}/validate`,
        { method: "POST", body: JSON.stringify(req) },
      ),
    onSuccess: setValidation,
  });

  const publish = useMutation({
    mutationFn: (p: AdminCompletionPolicy) =>
      apiFetch<AdminCompletionPolicy>(
        `/admin/events/${eventId}/completion-policies/${p.id}/publish`,
        {
          method: "POST",
          body: JSON.stringify({ expectedPolicyVersion: p.policyVersion }),
        },
      ),
    onSuccess: () => {
      setPublishTarget(null);
      invalidatePolicies();
    },
  });

  const draft = useMemo(
    () => policies.data?.find((p) => p.status === "DRAFT") ?? null,
    [policies.data],
  );
  const published = useMemo(
    () => policies.data?.find((p) => p.status === "PUBLISHED") ?? null,
    [policies.data],
  );

  const submitUpsert = (req: AdminCompletionPolicyUpsert) => {
    if (editing === "new") createDraft.mutate(req);
    else if (editing) updateDraft.mutate({ id: editing.id, req });
  };

  const submitValidate = (req: AdminCompletionPolicyUpsert) => {
    if (editing === "new" && !draft) return; // chưa có draft id — cần lưu trước
    const id = editing === "new" ? draft?.id : editing?.id;
    if (id) validate.mutate({ id, req });
  };

  /* ---------- dossier link state ---------- */
  const links = useQuery({
    queryKey: qk.eventDossiers(eventId),
    queryFn: () =>
      apiFetch<AdminEventDossierLink[]>(`/admin/events/${eventId}/dossiers`),
  });

  const [localLinks, setLocalLinks] = useState<AdminEventDossierLink[] | null>(
    null,
  );
  const [pickerOpen, setPickerOpen] = useState(false);
  const [removeTarget, setRemoveTarget] = useState<string | null>(null);

  const effectiveLinks = useMemo(() => {
    const src = localLinks ?? links.data ?? [];
    return src.map((l, i) => ({ ...l, displayOrder: i + 1 }));
  }, [localLinks, links.data]);

  const dirty = localLinks != null;

  const saveLinks = useMutation({
    mutationFn: (rows: AdminEventDossierLinkRequest[]) =>
      apiFetch<AdminEventDossierLink[]>(`/admin/events/${eventId}/dossiers`, {
        method: "PUT",
        body: JSON.stringify(rows),
      }),
    onSuccess: () => {
      setLocalLinks(null);
      qc.invalidateQueries({ queryKey: qk.eventDossiers(eventId) });
    },
  });

  const mutateLinks = (next: AdminEventDossierLink[]) =>
    setLocalLinks(next.map((l, i) => ({ ...l, displayOrder: i + 1 })));

  const moveLink = (index: number, dir: -1 | 1) => {
    const next = [...effectiveLinks];
    const j = index + dir;
    if (j < 0 || j >= next.length) return;
    const a = next[index];
    const b = next[j];
    if (!a || !b) return;
    next[index] = b;
    next[j] = a;
    mutateLinks(next);
  };

  const pickDossier = (d: AdminDossierSummary) => {
    mutateLinks([
      ...effectiveLinks,
      {
        dossierId: d.id,
        canonicalCode: d.canonicalCode,
        title: d.title,
        dossierType: d.dossierType,
        status: d.status,
        displayOrder: effectiveLinks.length + 1,
      },
    ]);
    setPickerOpen(false);
  };

  /* ---------- render ---------- */
  if (policies.isPending || links.isPending) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-40 w-full" />
      </div>
    );
  }
  if (policies.isError) {
    return (
      <ErrorState error={policies.error} onRetry={() => policies.refetch()} />
    );
  }

  const saving = createDraft.isPending || updateDraft.isPending;
  const topError =
    createDraft.error ?? updateDraft.error ?? publish.error ?? saveLinks.error;

  return (
    <div className="flex flex-col gap-8">
      {topError ? (
        <ErrorState error={topError} onRetry={() => qc.invalidateQueries()} />
      ) : null}

      {/* ---------- Section 1: completion policy ---------- */}
      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="font-display text-lg font-semibold text-ink">
              Chính sách hoàn thành sự kiện
            </h2>
            <p className="text-sm text-ink-muted">
              {published
                ? `Đang áp dụng v${published.policyVersion} — ngưỡng mastered ${
                    published.masteryThreshold ?? "—"
                  }`
                : "Chưa cấu hình — sự kiện chưa đánh giá hoàn thành."}
            </p>
          </div>
          {draft == null && editing == null && (
            <Button onClick={() => setEditing("new")}>Tạo bản nháp</Button>
          )}
        </div>

        {editing != null && (
          <Card className="p-4">
            <h3 className="mb-3 text-sm font-semibold text-ink">
              {editing === "new"
                ? `Bản nháp v${(policies.data?.[0]?.policyVersion ?? 0) + 1}`
                : `Sửa bản nháp v${editing.policyVersion}`}
            </h3>
            <PolicyEditor
              eventId={eventId}
              initial={editing === "new" ? draft : editing}
              saving={saving}
              validating={validate.isPending}
              validation={validation}
              onValidate={submitValidate}
              onSubmit={submitUpsert}
              onCancel={() => {
                setEditing(null);
                setValidation(null);
              }}
            />
            {editing === "new" && (
              <p className="mt-2 text-xs text-ink-muted">
                Lưu bản nháp trước để chạy kiểm tra và xuất bản.
              </p>
            )}
          </Card>
        )}

        <PolicyList
          rows={policies.data ?? []}
          loading={policies.isPending}
          onRetry={() => policies.refetch()}
          onEdit={(p) => {
            setEditing(p);
            setValidation(null);
          }}
          onPublish={async (p) => {
            setPublishTarget(p);
            validate.mutate({
              id: p.id,
              req: {
                requiredLessonIds: p.requiredLessonIds,
                optionalLessonIds: p.optionalLessonIds,
                masteryThreshold: p.masteryThreshold,
              },
            });
          }}
          publishingId={publish.isPending ? (publishTarget?.id ?? null) : null}
        />
      </section>

      {/* ---------- Section 2: dossier links ---------- */}
      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="font-display text-lg font-semibold text-ink">
              Hồ sơ liên kết
            </h2>
            <p className="text-sm text-ink-muted">
              Learner mở khoá khi hoàn thành sự kiện — chỉ hồ sơ PUBLISHED.
            </p>
          </div>
          <div className="flex gap-2">
            {dirty && (
              <>
                <Button
                  disabled={saveLinks.isPending}
                  onClick={() =>
                    saveLinks.mutate(
                      effectiveLinks.map((l) => ({
                        dossierId: l.dossierId,
                        displayOrder: l.displayOrder,
                      })),
                    )
                  }
                >
                  {saveLinks.isPending ? "Đang lưu…" : "Lưu thay đổi"}
                </Button>
                <Button variant="secondary" onClick={() => setLocalLinks(null)}>
                  Huỷ
                </Button>
              </>
            )}
            <Button variant="secondary" onClick={() => setPickerOpen(true)}>
              Liên kết hồ sơ
            </Button>
          </div>
        </div>
        <DossierLinkTable
          rows={effectiveLinks}
          onMove={moveLink}
          onRemove={(id) => setRemoveTarget(id)}
        />
      </section>

      {/* ---------- dialogs ---------- */}
      <PolicyPublishDialog
        open={publishTarget != null}
        onOpenChange={(o) => !o && setPublishTarget(null)}
        validation={validation}
        onConfirm={() => publishTarget && publish.mutate(publishTarget)}
      />

      <DossierPickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        excludeIds={new Set(effectiveLinks.map((l) => l.dossierId))}
        onPick={pickDossier}
      />

      <ConfirmDialog
        open={removeTarget != null}
        onOpenChange={(o) => !o && setRemoveTarget(null)}
        title="Gỡ hồ sơ khỏi sự kiện?"
        description="Learner đã mở khoá vẫn giữ quyền truy cập — chỉ ngừng mở khoá mới."
        confirmLabel="Gỡ liên kết"
        destructive
        onConfirm={() => {
          if (removeTarget) {
            mutateLinks(
              effectiveLinks.filter((l) => l.dossierId !== removeTarget),
            );
          }
        }}
      />
    </div>
  );
}
