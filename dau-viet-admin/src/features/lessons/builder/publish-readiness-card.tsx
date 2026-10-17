"use client";

import { useMutation } from "@tanstack/react-query";
import { CheckCircle2, ChevronDown, ChevronUp, RefreshCw, XCircle } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { PublishIssue, PublishReadiness } from "@/lib/dto/publish";
import { Button } from "@/components/ui/button";

import type { Draft } from "./draft-model";
import { resolveErrorPath } from "./validation-panel";

const SUMMARY_LABELS: Record<string, string> = {
  stageCount: "Số giai đoạn",
  activityCount: "Số hoạt động",
  evidenceRefs: "Bằng chứng tham chiếu",
  schemaVersion: "Phiên bản schema",
  errorCount: "Số lỗi",
  warningCount: "Số cảnh báo",
};

interface Props {
  lessonId: string;
  /** Draft hiện tại — dùng để resolve error path → jump. Bỏ qua trên màn publish. */
  draft?: Draft | null;
  /**
   * Draft revision — bất kỳ thay đổi nào của bản nháp đều vô hiệu kết quả
   * kiểm tra trước đó (stale readiness). Bỏ qua trên màn publish (không có
   * draft session đang sửa).
   */
  revision?: number;
  onJump?: (stageId: string | null, activityId: string | null) => void;
}

function IssueList({
  items,
  tone,
  draft,
  onJump,
}: {
  items: PublishIssue[];
  tone: "error" | "warning";
  draft?: Draft | null;
  onJump?: Props["onJump"];
}) {
  const clickable = Boolean(draft && onJump);
  return (
    <ul className="flex flex-col gap-1">
      {items.map((e, i) => {
        const target = draft ? resolveErrorPath(draft, e.path ?? "") : null;
        const body = (
          <>
            <span className="block font-mono text-[10px] text-ink-muted">{e.path ?? ""}</span>
            <span className={tone === "error" ? "text-error" : "text-ink"}>
              {e.code ? `[${e.code}] ` : ""}
              {e.message}
            </span>
          </>
        );
        return (
          <li key={`${e.path ?? ""}-${i}`}>
            {clickable ? (
              <button
                type="button"
                onClick={() => onJump?.(target?.stageId ?? null, target?.activityId ?? null)}
                className="w-full rounded px-2 py-1 text-left hover:bg-surface-alt"
              >
                {body}
              </button>
            ) : (
              <div className="px-2 py-1">{body}</div>
            )}
          </li>
        );
      })}
    </ul>
  );
}

/** Kiểm tra sẵn sàng xuất bản — POST /admin/lessons/{id}/validate (read-only). */
export function PublishReadinessCard({ lessonId, draft, revision, onJump }: Props) {
  const [open, setOpen] = useState(true);
  const [checkedAt, setCheckedAt] = useState<Date | null>(null);
  const mutation = useMutation({
    mutationFn: () =>
      apiFetch<PublishReadiness>(`/admin/lessons/${lessonId}/validate`, { method: "POST" }),
    onSuccess: () => setCheckedAt(new Date()),
  });

  // Stale readiness: kết quả validate chỉ đúng với đúng revision bản nháp
  // đã kiểm tra — mọi chỉnh sửa draft sau đó phải xoá trạng thái cũ.
  useEffect(() => {
    if (revision === undefined) return;
    mutation.reset();
    setCheckedAt(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [revision]);

  const data = mutation.data;
  const summaryEntries = data?.summary ? Object.entries(data.summary) : [];

  return (
    <section className="flex flex-col gap-2 rounded-md border border-border bg-white p-3">
      <div className="flex items-center justify-between">
        <h4 className="text-sm font-semibold text-ink">Sẵn sàng xuất bản</h4>
        {data && (
          <Button
            variant="secondary"
            className="h-7 px-2 text-xs"
            onClick={() => setOpen((o) => !o)}
            aria-expanded={open}
          >
            {open ? <ChevronUp className="size-3.5" /> : <ChevronDown className="size-3.5" />}
          </Button>
        )}
      </div>

      {data && (
        <p
          role="status"
          className={
            "flex items-center gap-1.5 rounded px-2 py-1.5 text-xs font-medium " +
            (data.ready ? "bg-success/10 text-success" : "bg-warning/15 text-ink")
          }
        >
          {data.ready ? (
            <CheckCircle2 className="size-4" aria-hidden />
          ) : (
            <XCircle className="size-4" aria-hidden />
          )}
          {data.ready ? "Bài học đủ điều kiện xuất bản." : "Chưa sẵn sàng xuất bản — xem chi tiết bên dưới."}
          {checkedAt && (
            <span className="ml-auto text-[10px] font-normal text-ink-muted">
              Kiểm tra lúc {checkedAt.toLocaleTimeString("vi-VN")}
            </span>
          )}
        </p>
      )}

      {data && open && (
        <div className="flex flex-col gap-2 text-xs">
          {summaryEntries.length > 0 && (
            <dl className="grid grid-cols-2 gap-x-3 gap-y-1 rounded bg-surface px-2 py-1.5">
              {summaryEntries.map(([k, v]) => (
                <div key={k} className="flex items-baseline justify-between gap-1">
                  <dt className="text-ink-muted">{SUMMARY_LABELS[k] ?? k}</dt>
                  <dd className="font-medium text-ink">{String(v ?? "—")}</dd>
                </div>
              ))}
            </dl>
          )}
          {data.errors.length > 0 && (
            <div>
              <p className="mb-1 font-semibold text-error">Lỗi chặn xuất bản ({data.errors.length})</p>
              <IssueList items={data.errors} tone="error" draft={draft} onJump={onJump} />
              {draft && onJump && (
                <p className="mt-1 text-[11px] text-ink-muted">
                  Bấm vào lỗi để đi tới chỉnh sửa.
                </p>
              )}
            </div>
          )}
          {data.warnings.length > 0 && (
            <div>
              <p className="mb-1 font-semibold text-ink">Cảnh báo ({data.warnings.length})</p>
              <IssueList items={data.warnings} tone="warning" draft={draft} onJump={onJump} />
            </div>
          )}
        </div>
      )}

      {mutation.isError && (
        <p role="alert" className="text-xs text-error">
          {toUserMessage(mutation.error)}
        </p>
      )}

      <div className="flex items-center gap-2">
        <Button
          variant="secondary"
          size="sm"
          className="self-start"
          disabled={mutation.isPending}
          onClick={() => mutation.mutate()}
        >
          <RefreshCw className={"size-3.5 " + (mutation.isPending ? "animate-spin" : "")} />
          {mutation.isPending ? "Đang kiểm tra..." : "Kiểm tra xuất bản"}
        </Button>
        {data?.ready && (
          <Button asChild size="sm" className="self-start">
            <Link href={`/lessons/${lessonId}/publish`}>Đi tới xuất bản</Link>
          </Button>
        )}
      </div>
    </section>
  );
}
