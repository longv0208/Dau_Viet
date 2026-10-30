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
import { CODE_MESSAGES, describePath, resolveErrorPath } from "./validation-panel";

const SUMMARY_LABELS: Record<string, string> = {
  stageCount: "Số giai đoạn",
  activityCount: "Số hoạt động",
  evidenceRefs: "Bằng chứng tham chiếu",
  schemaVersion: "Định dạng bản nháp",
  errorCount: "Số lỗi",
  warningCount: "Số cảnh báo",
};

interface Props {
  lessonId: string;
  /** Event ID của bài học — dùng tạo liên kết nhanh khi gặp lỗi EVENT_NOT_PUBLISHED. */
  eventId?: string;
  /** Draft hiện tại — dùng để resolve error path → jump. Bỏ qua trên màn publish. */
  draft?: Draft | null;
  /**
   * Draft revision — bất kỳ thay đổi nào của bản nháp đều vô hiệu kết quả
   * kiểm tra trước đó (stale readiness). Bỏ qua trên màn publish (không có
   * draft session đang sửa).
   */
  revision?: number;
  /** Bản nháp đang sửa chưa lưu — khoá kiểm tra để tránh hiểu nhầm kết quả áp dụng cho bản chưa lưu. */
  dirty?: boolean;
  /** Đang lưu nháp — khoá kiểm tra trong lúc PUT đang chạy. */
  saving?: boolean;
  onJump?: (stageId: string | null, activityId: string | null) => void;
}

function IssueList({
  items,
  tone,
  draft,
  eventId,
  onJump,
}: {
  items: PublishIssue[];
  tone: "error" | "warning";
  draft?: Draft | null;
  eventId?: string;
  onJump?: Props["onJump"];
}) {
  const clickable = Boolean(draft && onJump);
  return (
    <ul className="flex flex-col gap-1">
      {items.map((e, i) => {
        const target = draft ? resolveErrorPath(draft, e.path ?? "") : null;
        const where = describePath(draft, e.path ?? "");
        const detail = e.detail;
        const body = (
          <>
            {where && (
              <span className="block text-[10px] font-medium text-ink-muted">{where}</span>
            )}
            <span className={tone === "error" ? "text-error" : "text-ink"}>
              {detail ?? (e.code && CODE_MESSAGES[e.code]) ?? (e.message || "Cần xem lại nội dung đã nhập")}
            </span>
            {e.code === "EVENT_NOT_PUBLISHED" && (
              <span className="mt-1 block text-[11px] text-ink-muted">
                Hãy quay lại Không gian Sự kiện và bấm <strong>&ldquo;Xuất bản sự kiện&rdquo;</strong> trước:{" "}
                <Link
                  href={eventId ? `/events/${eventId}` : "/events"}
                  className="font-semibold text-brand hover:underline"
                >
                  Mở sự kiện để xuất bản →
                </Link>
              </span>
            )}
          </>
        );
        return (
          <li key={`${e.path ?? ""}-${i}`}>
            {clickable && target?.stageId != null ? (
              <button
                type="button"
                onClick={() => onJump?.(target.stageId, target.activityId)}
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
export function PublishReadinessCard({ lessonId, eventId, draft, revision, dirty, saving, onJump }: Props) {
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
          {data.ready
            ? "Bản nháp đã lưu đủ điều kiện xuất bản."
            : "Bản nháp đã lưu chưa sẵn sàng xuất bản — xem chi tiết bên dưới."}
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
              {summaryEntries
                .filter(([k]) => SUMMARY_LABELS[k])
                .map(([k, v]) => (
                  <div key={k} className="flex items-baseline justify-between gap-1">
                    <dt className="text-ink-muted">{SUMMARY_LABELS[k]}</dt>
                    <dd className="font-medium text-ink">{String(v ?? "—")}</dd>
                  </div>
                ))}
            </dl>
          )}
          {data.errors.length > 0 && (
            <div>
              <p className="mb-1 font-semibold text-error">Lỗi chặn xuất bản ({data.errors.length})</p>
              <IssueList items={data.errors} tone="error" draft={draft} eventId={eventId} onJump={onJump} />
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
              <IssueList items={data.warnings} tone="warning" draft={draft} eventId={eventId} onJump={onJump} />
            </div>
          )}
        </div>
      )}

      {mutation.isError && (
        <p role="alert" className="text-xs text-error">
          {toUserMessage(mutation.error)}
        </p>
      )}

      {(dirty || saving) && (
        <p className="rounded bg-warning/10 px-2 py-1.5 text-[11px] text-ink-muted">
          Kiểm tra xuất bản luôn chạy trên bản nháp đã lưu trên máy chủ — lưu
          nháp trước để kiểm tra nội dung mới nhất.
        </p>
      )}
      <div className="flex items-center gap-2">
        <Button
          variant="secondary"
          size="sm"
          className="self-start"
          disabled={mutation.isPending || dirty || saving}
          onClick={() => mutation.mutate()}
        >
          <RefreshCw className={"size-3.5 " + (mutation.isPending ? "animate-spin" : "")} />
          {mutation.isPending
            ? "Đang kiểm tra..."
            : dirty || saving
              ? "Kiểm tra xuất bản (cần lưu trước)"
              : "Kiểm tra xuất bản"}
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
