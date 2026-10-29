"use client";

import { useRef } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import { withReturnTo } from "@/lib/return-to";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminAsset } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { EvidenceTable } from "@/features/evidence/evidence-table";
import { animationApi } from "@/features/animations/animation-api";
import { HtmlImportDropzone } from "@/features/animations/html-import-dropzone";
import type { AnimationSceneSummary } from "@/features/animations/animation-types";
import { StatusChip } from "@/components/status-chip";

import type { AdminEventDetail } from "@/lib/dto/event";

const RETURN_TAB = "hoc-lieu";

/** Scenes HTML thuộc event — list nhỏ, upload gắn eventId. */
function EventScenesSection({ eventId, returnTo }: { eventId: string; returnTo: string }) {
  const router = useRouter();
  const qc = useQueryClient();
  const importBusy = useRef(false);

  const query = useQuery({
    queryKey: qk.animationScenes.list({ eventId, size: 50 }),
    queryFn: () => animationApi.listScenes({ eventId, size: 50 }),
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ["animation-scenes"] });

  const htmlImport = useMutation({
    mutationFn: (file: File) => animationApi.importHtmlScene(file, { eventId }),
    onSuccess: (scene) => {
      invalidate();
      router.push(withReturnTo(`/animations/${scene.id}/edit`, returnTo));
    },
  });

  const rows = query.data?.content ?? [];

  return (
    <PaperCard className="p-5">
      <SectionDivider
        eyebrow="HOẠT HỌA"
        eyebrowColor="jade"
        title="Hoạt họa HTML"
        description="Kéo thả file .html hoàn chỉnh. Sau khi xem trước và xuất bản, hoạt họa dùng được trong nhiều bài học."
        className="mb-4"
      />
      <div className="flex flex-col gap-4">
        <div className="max-w-xl">
          <HtmlImportDropzone
            disabled={htmlImport.isPending}
            onFile={(file) => {
              if (importBusy.current) return;
              importBusy.current = true;
              htmlImport.mutate(file, { onSettled: () => { importBusy.current = false; } });
            }}
          />
          {htmlImport.isPending && (
            <p className="mt-2 text-xs text-ink-muted">Đang tải lên và kiểm tra tệp…</p>
          )}
          {htmlImport.error && (
            <p role="alert" className="mt-2 text-xs text-error">
              Tải lên thất bại: {htmlImport.error.message}
            </p>
          )}
        </div>

        {query.isPending && <Skeleton className="h-24 w-full" />}
        {query.data && rows.length === 0 && (
          <p className="text-sm text-ink-muted">Chưa có hoạt họa nào cho sự kiện này.</p>
        )}
        <ul className="flex flex-col gap-2">
          {rows.map((s: AnimationSceneSummary) => (
            <li
              key={s.id}
              className="flex items-center justify-between rounded-md border border-border bg-surface px-3 py-2"
            >
              <Link
                href={withReturnTo(`/animations/${s.id}/edit`, returnTo)}
                className="truncate font-medium text-ink hover:underline"
              >
                {s.title}
              </Link>
              <div className="flex items-center gap-3">
                <StatusChip status={s.status} />
                <Link
                  href={withReturnTo(`/animations/${s.id}/versions`, returnTo)}
                  className="text-sm text-ink-muted hover:underline"
                >
                  Phiên bản
                </Link>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </PaperCard>
  );
}

/** Media dùng chung — hiển thị assets mà evidence của event đang tham chiếu. */
function EventMediaSection({ eventId }: { eventId: string }) {
  const evidences = useQuery({
    queryKey: qk.evidences.list({ eventId, size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<{ id: string; assetId: string | null }>>(
        `/admin/evidences${toQuery({ eventId, size: 100 })}`,
      ),
  });

  const assetIds = [
    ...new Set(
      (evidences.data?.content ?? [])
        .map((e) => e.assetId)
        .filter((a): a is string => a != null),
    ),
  ];

  const assets = useQuery({
    queryKey: ["assets", "byIds", assetIds],
    queryFn: async () => {
      const res = await Promise.all(
        assetIds.map((id) => apiFetch<AdminAsset>(`/admin/assets/${id}`)),
      );
      return res;
    },
    enabled: assetIds.length > 0,
  });

  return (
    <PaperCard className="p-5">
      <SectionDivider
        eyebrow="MEDIA"
        eyebrowColor="gold"
        title="Hình ảnh / Media"
        description="Assets dùng chung trong thư viện — hiển thị các file đang được tham chiếu bởi bằng chứng của sự kiện này."
        className="mb-4"
      />
      <div className="flex flex-col gap-3">
        {evidences.isPending && <Skeleton className="h-16 w-full" />}
        {evidences.data && assetIds.length === 0 && (
          <p className="text-sm text-ink-muted">
            Chưa có bằng chứng nào đính kèm ảnh — gắn ảnh khi tạo hoặc sửa bằng chứng.
          </p>
        )}
        {assetIds.length > 0 && (
          <>
            {assets.isPending && <Skeleton className="h-20 w-full" />}
            <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {(assets.data ?? []).map((a) => (
                <li key={a.id} className="rounded-md border border-border bg-surface p-2">
                  <a
                    href={a.contentUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="block truncate text-sm font-medium text-brand hover:underline"
                  >
                    {a.originalFilename ?? a.id}
                  </a>
                  <p className="mt-0.5 text-xs text-ink-muted">
                    {a.mimeType} · {(a.sizeBytes / 1024).toFixed(0)} KB
                  </p>
                </li>
              ))}
            </ul>
          </>
        )}
        <Button asChild variant="secondary" className="self-start">
          <Link href="/assets">Mở thư viện media</Link>
        </Button>
      </div>
    </PaperCard>
  );
}

/** Tab Học liệu — Evidence + Media + Animations trong một màn. */
export function EventHocLieuTab({ event }: { event: AdminEventDetail }) {
  const eventId = event.id;
  const returnTo = `/events/${eventId}?tab=${RETURN_TAB}`;

  return (
    <div className="flex flex-col gap-6">
      <PaperCard className="p-5">
        <SectionDivider
          eyebrow="TƯ LIỆU"
          eyebrowColor="brand"
          title="Bằng chứng lịch sử"
          description="Tư liệu có nguồn trích dẫn, dùng để hỗ trợ câu hỏi và hoạt động học tập."
          action={
            <Button asChild>
              <Link href={withReturnTo(`/evidence/new?event=${eventId}`, returnTo)}>
                + Thêm bằng chứng
              </Link>
            </Button>
          }
          className="mb-4"
        />
        <div>
          <EvidenceTable lockedEventId={eventId} returnTo={returnTo} />
        </div>
      </PaperCard>

      <EventMediaSection eventId={eventId} />
      <EventScenesSection eventId={eventId} returnTo={returnTo} />
    </div>
  );
}
