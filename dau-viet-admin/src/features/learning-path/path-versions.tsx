"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Copy, Eye, Plus, RefreshCw, Route } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { ClueTag } from "@/components/atoms/clue-tag";
import { EmptyStateCard } from "@/components/atoms/empty-state-card";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { StampSeal } from "@/components/atoms/stamp-seal";
import { PageHeader } from "@/components/page-header";
import { StatusChip } from "@/components/status-chip";
import type { PathVersion } from "@/lib/dto/learning-path";
import { DEFAULT_PATH_CODE, pathApi, pathKeys } from "./path-api";
import { pathError, usePathVersion, usePathVersions } from "./use-learning-path";

function VersionCard({ version, disabled, onClone }: {
  version: PathVersion; disabled: boolean; onClone: (id: string) => void;
}) {
  const detail = usePathVersion(version.id);
  const events = detail.data?.chapters.flatMap(c => c.events) ?? [];
  const lessonsCount = events.reduce((sum, e) => sum + e.lessons.length, 0);
  return (
    <PaperCard className="p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <ClueTag label={version.pathCode} color="jade" className="font-mono" />
            <p className="text-xs font-medium uppercase tracking-wider text-ink-muted">
              Phiên bản {version.versionNo}
            </p>
          </div>
          <h3 className="mt-1 font-display text-lg font-semibold text-ink">{version.title}</h3>
          {version.description && <p className="mt-1 text-sm text-ink-muted">{version.description}</p>}
        </div>
        <div className="flex items-center gap-2">
          {version.status === "PUBLISHED" && (
            <StampSeal variant="success" label="ẤN HÀNH" className="scale-90" />
          )}
          <StatusChip status={version.status} />
        </div>
      </div>
      {detail.isPending ? <p className="my-5 text-sm text-ink-muted" role="status">Đang tải cấu trúc...</p> : detail.isError ? (
        <div className="my-3 text-sm text-error" role="alert">Chưa tải được số liệu: {pathError(detail.error)} <button className="underline" onClick={() => void detail.refetch()}>Thử lại</button></div>
      ) : (
        <dl className="my-5 grid grid-cols-3 gap-3 text-sm">
          {[["Chương", detail.data?.chapters.length ?? 0], ["Sự kiện", events.length], ["Bài học", lessonsCount]].map(([label, value]) => (
            <div key={label} className="rounded-md border border-border bg-surface p-3"><dt className="text-xs text-ink-muted">{label}</dt><dd className="mt-1 font-display text-2xl font-bold text-chapter tabular-nums">{value}</dd></div>
          ))}
        </dl>
      )}
      <p className="text-xs text-ink-muted">{version.publishedAt ? `Xuất bản: ${new Date(version.publishedAt).toLocaleString("vi-VN")}` : `Cập nhật: ${new Date(version.updatedAt).toLocaleString("vi-VN")} · Chưa xuất bản`}</p>
      <div className="mt-4 flex flex-wrap gap-2">
        <Button asChild variant={version.status === "DRAFT" ? "default" : "secondary"} size="sm">
          <Link href={`/learning-path/${version.id}/edit`}>{version.status === "DRAFT" ? "Thiết kế / xuất bản" : "Xem lộ trình"}</Link>
        </Button>
        <Button asChild variant="secondary" size="sm"><Link href={`/learning-path/${version.id}/preview`}><Eye aria-hidden />Xem trước</Link></Button>
        {version.status === "PUBLISHED" && <Button size="sm" variant="secondary" disabled={disabled} onClick={() => onClone(version.id)}><Copy aria-hidden />Tạo bản nháp từ phiên bản này</Button>}
      </div>
    </PaperCard>
  );
}

export function PathVersions() {
  const [code, setCode] = useState("ALL");
  const [filter, setFilter] = useState("");
  const [open, setOpen] = useState(false);
  const query = usePathVersions(code);
  const cache = useQueryClient();
  const router = useRouter();
  const mutation = useMutation({
    mutationFn: (action: { cloneId: string } | { pathCode: string; title: string; description: string }) =>
      "cloneId" in action ? pathApi.clone(action.cloneId) : pathApi.create(action),
    onSuccess: detail => {
      cache.setQueryData(pathKeys.detail(detail.version.id), detail);
      void cache.invalidateQueries({ queryKey: pathKeys.lists });
      setOpen(false);
      router.push(`/learning-path/${detail.version.id}/edit`);
    },
  });
  const groups = [
    { status: "PUBLISHED", label: "Lộ trình đang xuất bản" },
    { status: "DRAFT", label: "Bản nháp đang thiết kế" },
    { status: "ARCHIVED", label: "Lịch sử phiên bản" },
  ] as const;

  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader eyebrow="QUẢN TRỊ · LỘ TRÌNH" title="Bản đồ Dấu Ấn" description="Thiết kế hành trình học từ chương lịch sử, sự kiện và bài học có sẵn." actions={
        <Button onClick={() => { mutation.reset(); setOpen(true); }} disabled={mutation.isPending}><Plus aria-hidden />Tạo lộ trình mới</Button>
      } />
      <PaperCard className="mb-6 flex flex-wrap items-center justify-between gap-3 p-4">
        <form className="flex flex-wrap items-center gap-2" onSubmit={e => { e.preventDefault(); setCode(filter.trim() || "ALL"); }}>
          <Label htmlFor="path-code-filter" className="font-medium text-ink-secondary">Mã lộ trình</Label>
          <Input id="path-code-filter" value={filter} onChange={e => setFilter(e.target.value)} placeholder="Tất cả (ví dụ: HISTORY_MAIN)" maxLength={64} className="w-60" />
          <Button type="submit" variant="secondary">Lọc</Button>
          {code !== "ALL" && (
            <Button type="button" variant="ghost" size="sm" onClick={() => { setFilter(""); setCode("ALL"); }}>
              Xem tất cả
            </Button>
          )}
        </form>
        <Button variant="ghost" disabled={query.isFetching} onClick={() => void query.refetch()}><RefreshCw aria-hidden />Làm mới</Button>
      </PaperCard>
      {mutation.isError && !open && <p role="alert" className="mb-4 rounded-md border border-error/30 bg-error/5 p-3 text-sm text-error">{pathError(mutation.error)}</p>}
      {query.isPending ? <p role="status">Đang tải các phiên bản...</p> : query.isError ? (
        <div role="alert" className="rounded-lg border border-error/30 p-5"><p>{pathError(query.error)}</p><Button variant="secondary" onClick={() => void query.refetch()}>Thử lại</Button></div>
      ) : groups.map(group => {
        const versions = query.data.filter(v => v.status === group.status);
        return <section key={group.status} className="mb-8" aria-label={group.label}>
          <SectionDivider
            eyebrow={group.status}
            eyebrowColor={group.status === "PUBLISHED" ? "jade" : group.status === "DRAFT" ? "gold" : "chapter"}
            title={
              <span className="flex items-center gap-2">
                <Route className="size-5 text-brand" aria-hidden />
                {group.label}
                <span className="text-sm font-normal text-ink-muted">({versions.length})</span>
              </span>
            }
            className="mb-3"
          />
          {versions.length ? <div className="grid gap-4 xl:grid-cols-2">{versions.map(version => <VersionCard key={version.id} version={version} disabled={mutation.isPending} onClone={cloneId => mutation.mutate({ cloneId })} />)}</div>
            : <EmptyStateCard title="Chưa có phiên bản trong nhóm này." className="py-6" />}
        </section>;
      })}
      <Dialog open={open} onOpenChange={value => { if (!mutation.isPending) setOpen(value); }} title="Tạo lộ trình mới" description="Bản nháp bắt đầu trống. Thêm chương và nội dung có sẵn trước khi kiểm tra xuất bản.">
        <form className="space-y-4" onSubmit={e => {
          e.preventDefault();
          if (mutation.isPending) return;
          const form = new FormData(e.currentTarget);
          mutation.mutate({ pathCode: String(form.get("pathCode")).trim(), title: String(form.get("title")).trim(), description: String(form.get("description") ?? "") });
        }}>
          <div><Label htmlFor="new-path-code">Mã lộ trình</Label><Input id="new-path-code" name="pathCode" defaultValue={code === "ALL" ? DEFAULT_PATH_CODE : code} maxLength={64} required /></div>
          <div><Label htmlFor="new-path-title">Tên lộ trình</Label><Input id="new-path-title" name="title" maxLength={255} required /></div>
          <div><Label htmlFor="new-path-description">Mô tả</Label><Textarea id="new-path-description" name="description" rows={3} /></div>
          {mutation.isError && <p role="alert" className="text-sm text-error">{pathError(mutation.error)}</p>}
          <div className="flex justify-end gap-2"><Button type="button" variant="secondary" disabled={mutation.isPending} onClick={() => setOpen(false)}>Hủy</Button><Button type="submit" disabled={mutation.isPending}>{mutation.isPending ? "Đang tạo..." : "Tạo bản nháp"}</Button></div>
        </form>
      </Dialog>
    </div>
  );
}
