"use client";

import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { apiFetch } from "@/lib/api-client";
import type {
  AdminDossierDetail,
  AdminDossierUpdate,
  DossierSource,
  DossierType,
} from "@/lib/dto/gamification";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";
import { StatusChip } from "@/components/status-chip";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { useUnsavedChangesGuard } from "@/components/unsaved-changes-guard";

import { DossierSourceFields } from "./dossier-source-fields";

const TYPE_LABELS: Record<DossierType, string> = {
  PERSON: "Nhân vật",
  LOCATION: "Địa điểm",
  ARTIFACT: "Hiện vật",
  CONTEXT: "Bối cảnh",
};

const EMPTY_SOURCE: DossierSource = { title: "" };

/**
 * Editor dossier (GAME-06): form update + publish/archive + linked events
 * + version history. PUBLISHED cho phep sua — tao pendingChanges cho toi
 * khi bam publish (backend tang dossier_version + snapshot).
 */
export function DossierDetail({ id }: { id: string }) {
  const qc = useQueryClient();
  const detail = useQuery({
    queryKey: qk.dossiers.detail(id),
    queryFn: () => apiFetch<AdminDossierDetail>(`/admin/dossiers/${id}`),
  });

  const [dossierType, setDossierType] = useState<DossierType>("PERSON");
  const [title, setTitle] = useState("");
  const [summary, setSummary] = useState("");
  const [description, setDescription] = useState("");
  const [source, setSource] = useState<DossierSource>(EMPTY_SOURCE);
  const [archiveOpen, setArchiveOpen] = useState(false);
  const [dirty, setDirty] = useState(false);
  useUnsavedChangesGuard(dirty);

  useEffect(() => {
    const d = detail.data;
    if (!d) return;
    setDossierType(d.dossierType);
    setTitle(d.title);
    setSummary(d.summary ?? "");
    setDescription(d.description ?? "");
    setSource(d.source ?? EMPTY_SOURCE);
    setDirty(false);
  }, [detail.data]);

  const invalidate = () =>
    qc.invalidateQueries({ queryKey: qk.dossiers.detail(id) });

  const update = useMutation({
    mutationFn: (req: AdminDossierUpdate) =>
      apiFetch<AdminDossierDetail>(`/admin/dossiers/${id}`, {
        method: "PUT",
        body: JSON.stringify(req),
      }),
    onSuccess: () => {
      setDirty(false);
      invalidate();
    },
  });

  const publish = useMutation({
    mutationFn: () =>
      apiFetch<AdminDossierDetail>(`/admin/dossiers/${id}/publish`, {
        method: "POST",
      }),
    onSuccess: invalidate,
  });

  const archive = useMutation({
    mutationFn: () =>
      apiFetch<AdminDossierDetail>(`/admin/dossiers/${id}/archive`, {
        method: "POST",
      }),
    onSuccess: invalidate,
  });

  if (detail.isPending) {
    return <Skeleton className="h-96 w-full" />;
  }
  if (detail.isError) {
    return <ErrorState error={detail.error} onRetry={() => detail.refetch()} />;
  }
  const d = detail.data;

  const submitUpdate = () => {
    update.mutate({
      dossierType,
      title,
      summary: summary || null,
      description: description || null,
      source:
        source.title.trim() === ""
          ? null
          : {
              title: source.title,
              author: source.author || null,
              citation: source.citation || null,
              url: source.url || null,
              reliability: source.reliability || null,
            },
      expectedRowVersion: d.rowVersion,
    });
  };

  const topError = update.error ?? publish.error ?? archive.error;

  return (
    <div className="flex max-w-4xl flex-col gap-6">
      {topError ? <ErrorState error={topError} /> : null}

      <div className="flex flex-wrap items-center gap-3">
        <StatusChip status={d.status} />
        <span className="text-sm text-ink-muted">v{d.dossierVersion}</span>
        {d.pendingChanges && (
          <span className="rounded-full bg-warning/25 px-2.5 py-0.5 text-xs font-medium text-ink">
            Có thay đổi chưa xuất bản
          </span>
        )}
        <div className="ml-auto flex gap-2">
          <Button
            variant="secondary"
            disabled={update.isPending || !dirty}
            onClick={submitUpdate}
          >
            {update.isPending ? "Đang lưu…" : "Lưu"}
          </Button>
          {d.status !== "ARCHIVED" && (
            <Button
              disabled={publish.isPending}
              onClick={() => publish.mutate()}
            >
              {publish.isPending ? "Đang xuất bản…" : "Xuất bản"}
            </Button>
          )}
          {d.status !== "ARCHIVED" && (
            <Button
              variant="secondary"
              onClick={() => setArchiveOpen(true)}
            >
              Lưu trữ
            </Button>
          )}
        </div>
      </div>

      <Card className="flex flex-col gap-4 p-4">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div>
            <Label>Mã canonical</Label>
            <Input value={d.canonicalCode} disabled />
          </div>
          <div>
            <Label htmlFor="dd-type">Loại</Label>
            <Select
              id="dd-type"
              value={dossierType}
              onChange={(e) => {
                setDossierType(e.target.value as DossierType);
                setDirty(true);
              }}
            >
              {Object.entries(TYPE_LABELS).map(([v, l]) => (
                <option key={v} value={v}>
                  {l}
                </option>
              ))}
            </Select>
          </div>
        </div>
        <div>
          <Label htmlFor="dd-title">Tiêu đề</Label>
          <Input
            id="dd-title"
            value={title}
            onChange={(e) => {
              setTitle(e.target.value);
              setDirty(true);
            }}
          />
        </div>
        <div>
          <Label htmlFor="dd-summary">Tóm tắt</Label>
          <Textarea
            id="dd-summary"
            rows={2}
            value={summary}
            onChange={(e) => {
              setSummary(e.target.value);
              setDirty(true);
            }}
          />
        </div>
        <div>
          <Label htmlFor="dd-desc">Mô tả chi tiết</Label>
          <Textarea
            id="dd-desc"
            rows={5}
            value={description}
            onChange={(e) => {
              setDescription(e.target.value);
              setDirty(true);
            }}
          />
        </div>
      </Card>

      <div onChangeCapture={() => setDirty(true)}>
        <DossierSourceFields value={source} onChange={setSource} />
      </div>

      <Card className="p-4">
        <h3 className="mb-3 text-sm font-semibold text-ink">
          Sự kiện liên kết
        </h3>
        {d.events.length === 0 ? (
          <p className="text-sm text-ink-muted">
            Chưa liên kết sự kiện nào — quản lý tại tab Gamification của sự
            kiện.
          </p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {d.events.map((e) => (
              <li
                key={e.eventId}
                className="flex items-center justify-between py-2 text-sm"
              >
                <span>{e.eventTitle}</span>
                <span className="text-ink-muted">#{e.displayOrder}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Card className="p-4">
        <h3 className="mb-3 text-sm font-semibold text-ink">
          Lịch sử phiên bản
        </h3>
        {d.versions.length === 0 ? (
          <p className="text-sm text-ink-muted">Chưa xuất bản lần nào.</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {d.versions.map((v) => (
              <li
                key={v.version}
                className="flex items-center justify-between py-2 text-sm"
              >
                <span>
                  v{v.version} — {v.status}
                </span>
                <span className="text-ink-muted">
                  {new Date(v.publishedAt).toLocaleString("vi-VN")}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <ConfirmDialog
        open={archiveOpen}
        onOpenChange={setArchiveOpen}
        title="Lưu trữ hồ sơ?"
        description="Learner đã mở khoá vẫn đọc được; hồ sơ chỉ biến mất khỏi danh sách mới."
        confirmLabel="Lưu trữ"
        destructive
        onConfirm={() => archive.mutate()}
      />
    </div>
  );
}
