"use client";

import { useMutation } from "@tanstack/react-query";
import { CheckCircle2, ChevronDown, ChevronUp, RefreshCw, XCircle } from "lucide-react";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { PublishReadiness } from "@/lib/dto/publish";
import { Button } from "@/components/ui/button";

/** Kiểm tra sẵn sàng xuất bản — POST /admin/lessons/{id}/validate (read-only). */
export function PublishReadinessCard({ lessonId }: { lessonId: string }) {
  const [open, setOpen] = useState(true);
  const mutation = useMutation({
    mutationFn: () =>
      apiFetch<PublishReadiness>(`/admin/lessons/${lessonId}/validate`, { method: "POST" }),
  });
  const data = mutation.data;

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
        </p>
      )}

      {data && open && (
        <div className="flex flex-col gap-2 text-xs">
          {data.summary && <p className="text-ink-muted">{data.summary}</p>}
          {data.errors.length > 0 && (
            <ul className="flex flex-col gap-1">
              {data.errors.map((e, i) => (
                <li key={i} className="text-error">
                  <span className="font-mono text-[10px] text-ink-muted">{e.path ?? ""}</span>{" "}
                  {e.code ? `[${e.code}] ` : ""}
                  {e.message}
                </li>
              ))}
            </ul>
          )}
          {data.warnings.length > 0 && (
            <ul className="flex flex-col gap-1">
              {data.warnings.map((w, i) => (
                <li key={i} className="text-ink">
                  <span className="font-mono text-[10px] text-ink-muted">{w.path ?? ""}</span>{" "}
                  {w.message}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {mutation.isError && (
        <p role="alert" className="text-xs text-error">
          {toUserMessage(mutation.error)}
        </p>
      )}

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
    </section>
  );
}
