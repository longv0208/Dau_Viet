"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";

import { DataTable, type Column } from "@/components/data-table";
import { ErrorState } from "@/components/error-state";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { qk } from "@/lib/query-keys";

import { animationApi } from "./animation-api";
import { HtmlImportDropzone } from "./html-import-dropzone";
import type { AnimationSceneSummary } from "./animation-types";

const STATUS_LABELS: Record<string, string> = {
  "": "Tất cả trạng thái",
  DRAFT: "Bản nháp",
  PUBLISHED: "Đã xuất bản",
  ARCHIVED: "Đã lưu trữ",
};

/**
 * Thư viện hoạt họa — HTML ONLY. Dropzone luôn hiện ngay khi mở trang;
 * danh sách chỉ liệt kê scene HTML_WEBVIEW (lọc phía server qua
 * templateId của template HTML — KHÔNG lọc client sau khi phân trang,
 * tránh trang rỗng/pagination sai).
 */
/** Code template chuẩn cho cảnh HTML — khớp AnimationHtmlService.TEMPLATE_CODE + V19. */
const HTML_TEMPLATE_CODE = "html-webview";

export function AnimationLibrary() {
  const router = useRouter();
  const qc = useQueryClient();
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(0);
  const importBusy = useRef(false);

  // FIX-01: xác định template chuẩn bằng code 'html-webview', KHÔNG lấy
  // content[0] — backend cho phép nhiều template HTML_WEBVIEW và template
  // đầu trang chưa chắc là template chuẩn mà HTML import sử dụng.
  const htmlTemplate = useQuery({
    queryKey: qk.animationTemplates.list({ rendererCode: "HTML_WEBVIEW" }),
    queryFn: () =>
      animationApi.listTemplates({ rendererCode: "HTML_WEBVIEW", size: 100 }),
    staleTime: 60_000,
    retry: false,
  });
  const htmlTemplateId: string | undefined =
    htmlTemplate.data?.content?.find((t) => t.code === HTML_TEMPLATE_CODE)?.id;
  // Template API chạy xong nhưng không có code chuẩn → lỗi rõ ràng thay
  // vì skeleton mãi; scene query vẫn disabled — KHÔNG fallback gọi toàn
  // bộ scene (legacy lẫn HTML) lọc phía client.
  const templateMissing =
    htmlTemplate.isSuccess && htmlTemplateId === undefined;

  const query = useQuery({
    queryKey: qk.animationScenes.list({
      page,
      size: 20,
      status,
      q,
      templateId: htmlTemplateId,
    }),
    // Chờ có templateId — list chỉ tập HTML, không rơi scene legacy.
    queryFn: () =>
      animationApi.listScenes({
        page,
        size: 20,
        status,
        q,
        templateId: htmlTemplateId,
      }),
    enabled: htmlTemplateId != null,
  });

  const invalidate = () =>
    qc.invalidateQueries({ queryKey: ["animation-scenes"] });

  const duplicate = useMutation({
    mutationFn: (id: string) => animationApi.duplicateScene(id),
    onSuccess: (scene) => {
      invalidate();
      router.push(`/animations/${scene.id}/edit`);
    },
  });
  const archive = useMutation({
    mutationFn: (id: string) => animationApi.archiveScene(id),
    onSuccess: invalidate,
  });
  const htmlImport = useMutation({
    mutationFn: (file: File) => animationApi.importHtmlScene(file),
    onSuccess: (scene) => {
      invalidate();
      router.push(`/animations/${scene.id}/edit`);
    },
  });
  const actionError = duplicate.error ?? archive.error ?? htmlImport.error;

  const rows = query.data?.content ?? [];

  // FIX-02: lỗi template (API lỗi hoặc thiếu code chuẩn) → ErrorState riêng
  // với Retry chạy lại ĐÚNG template query — ErrorState nuốt message của
  // Error thuần nên cần render trực tiếp thay vì qua DataTable.
  if (templateMissing || htmlTemplate.error) {
    return (
      <div className="flex flex-col gap-4">
        <div className="max-w-2xl">
          <HtmlImportDropzone
            disabled
            onFile={() => undefined}
          />
        </div>
        <ErrorState
          error={htmlTemplate.error ?? new Error(
            `Thiếu template '${HTML_TEMPLATE_CODE}' — chạy lại migration V19 trên backend.`,
          )}
          onRetry={() => void htmlTemplate.refetch()}
        />
      </div>
    );
  }

  const handleRetry = () => void query.refetch();

  const columns: Column<AnimationSceneSummary>[] = [
    {
      key: "title",
      header: "Tên cảnh",
      cell: (r) => (
        <Link
          href={`/animations/${r.id}/edit`}
          className="font-medium text-primary hover:underline"
        >
          {r.title}
        </Link>
      ),
    },
    {
      key: "status",
      header: "Trạng thái",
      cell: (r) => <StatusChip status={r.status} />,
    },
    {
      key: "version",
      header: "Phiên bản",
      cell: (r) =>
        r.currentVersionNo != null ? (
          <Link
            href={`/animations/${r.id}/versions`}
            className="text-primary hover:underline"
          >
            v{r.currentVersionNo}
          </Link>
        ) : (
          <span className="text-ink-muted">—</span>
        ),
    },
    {
      key: "actions",
      header: "Thao tác",
      cell: (r) => (
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="outline" size="sm">
            <Link href={`/animations/${r.id}/edit`}>Soạn</Link>
          </Button>
          <Button
            variant="outline"
            size="sm"
            disabled={duplicate.isPending}
            onClick={() => duplicate.mutate(r.id)}
          >
            Nhân bản
          </Button>
          {r.status !== "ARCHIVED" && (
            <Button
              variant="outline"
              size="sm"
              disabled={archive.isPending}
              onClick={() => {
                if (window.confirm(`Lưu trữ cảnh "${r.title}"?`)) {
                  archive.mutate(r.id);
                }
              }}
            >
              Lưu trữ
            </Button>
          )}
        </div>
      ),
    },
  ];

  const totalPages = query.data?.totalPages ?? 0;

  return (
    <div className="flex flex-col gap-4">
      {/* Vùng tải lên — luôn hiện, không cần bấm mở trước. */}
      <div className="max-w-2xl">
        <HtmlImportDropzone
          disabled={htmlImport.isPending}
          onFile={(file) => {
            if (importBusy.current) return;
            importBusy.current = true;
            htmlImport.mutate(file, {
              onSettled: () => {
                importBusy.current = false;
              },
            });
          }}
        />
        {htmlImport.isPending && (
          <p className="mt-2 text-xs text-ink-muted">
            Đang tải lên và kiểm tra tệp…
          </p>
        )}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <Input
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setPage(0);
          }}
          placeholder="Tìm theo tên cảnh…"
          className="max-w-xs"
          aria-label="Tìm theo tên cảnh"
        />
        <Select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(0);
          }}
          className="w-48"
          aria-label="Lọc theo trạng thái"
        >
          {Object.entries(STATUS_LABELS).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </Select>
      </div>

      {actionError && (
        <p role="alert" className="rounded-md border border-error/40 bg-error/5 px-3 py-2 text-xs text-error">
          Thao tác thất bại: {actionError.message}
        </p>
      )}

      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(r) => r.id}
        loading={query.isPending}
        error={query.error ?? undefined}
        onRetry={handleRetry}
        emptyTitle="Chưa có hoạt họa nào"
        emptyDescription="Kéo thả một tệp .html vào vùng tải lên ở trên để tạo hoạt họa đầu tiên."
      />

      {totalPages > 1 && (
        <div className="flex items-center gap-3 text-sm text-ink-muted">
          <Button
            variant="outline"
            size="sm"
            disabled={page === 0}
            onClick={() => setPage((p) => p - 1)}
          >
            ← Trước
          </Button>
          <span>
            Trang {page + 1}/{totalPages}
          </span>
          <Button
            variant="outline"
            size="sm"
            disabled={page + 1 >= totalPages}
            onClick={() => setPage((p) => p + 1)}
          >
            Sau →
          </Button>
        </div>
      )}
    </div>
  );
}
