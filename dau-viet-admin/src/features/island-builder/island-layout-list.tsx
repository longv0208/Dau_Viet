"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import {
  CheckCircle2,
  Copy,
  Edit3,
  Eye,
  FolderPlus,
  History,
  Layers,
  Plus,
  Sparkles,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";
import { EmptyState } from "@/components/empty-state";
import { toUserMessage } from "@/lib/api-error";

import {
  islandBuilderApi,
  type LayoutSummaryDto,
} from "./island-builder-api";

export function IslandLayoutList() {
  const router = useRouter();
  const qc = useQueryClient();

  const [showCreateModal, setShowCreateModal] = useState(false);
  const [selectedLayoutId, setSelectedLayoutId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  // Form tạo layout mới (khớp đúng CreateLayoutRequest: layoutKey, name, description, canvasWidth, canvasHeight, themeKey, defaultLayout)
  const [layoutKey, setLayoutKey] = useState("");
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [themeKey, setThemeKey] = useState("heritage");
  const [canvasWidth, setCanvasWidth] = useState("960");
  const [canvasHeight, setCanvasHeight] = useState("720");

  const layoutsQuery = useQuery({
    queryKey: ["admin-island-layouts"],
    queryFn: () => islandBuilderApi.listLayouts(),
  });

  const detailQuery = useQuery({
    queryKey: ["admin-island-layout-detail", selectedLayoutId],
    queryFn: () => islandBuilderApi.getLayout(selectedLayoutId!),
    enabled: Boolean(selectedLayoutId),
  });

  const createLayoutMutation = useMutation({
    mutationFn: async () => {
      const created = await islandBuilderApi.createLayout({
        layoutKey: layoutKey.trim(),
        name: name.trim(),
        description: description.trim() || null,
        themeKey: themeKey.trim() || "heritage",
        canvasWidth: Number(canvasWidth) || 960,
        canvasHeight: Number(canvasHeight) || 720,
        defaultLayout: false,
      });
      const initialDraft = created.versions.find((v) => v.status === "DRAFT");
      if (initialDraft) {
        return initialDraft.id;
      }
      const draft = await islandBuilderApi.createDraft(created.id);
      return draft.id;
    },
    onSuccess: (draftVersionId) => {
      qc.invalidateQueries({ queryKey: ["admin-island-layouts"] });
      setShowCreateModal(false);
      router.push(`/island-builder/${draftVersionId}`);
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const createDraftMutation = useMutation({
    mutationFn: (layoutId: string) => islandBuilderApi.createDraft(layoutId),
    onSuccess: (draft) => {
      qc.invalidateQueries({ queryKey: ["admin-island-layouts"] });
      qc.invalidateQueries({
        queryKey: ["admin-island-layout-detail", draft.definitionId],
      });
      router.push(`/island-builder/${draft.id}`);
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const cloneVersionMutation = useMutation({
    mutationFn: (versionId: string) => islandBuilderApi.cloneVersion(versionId),
    onSuccess: (draft) => {
      qc.invalidateQueries({ queryKey: ["admin-island-layouts"] });
      qc.invalidateQueries({
        queryKey: ["admin-island-layout-detail", draft.definitionId],
      });
      router.push(`/island-builder/${draft.id}`);
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const setDefaultMutation = useMutation({
    mutationFn: (layoutId: string) =>
      islandBuilderApi.updateLayout(layoutId, { defaultLayout: true }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin-island-layouts"] });
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  if (layoutsQuery.isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-44 w-full" />
      </div>
    );
  }

  if (layoutsQuery.isError) {
    return (
      <ErrorState
        message={toUserMessage(layoutsQuery.error)}
        onRetry={() => layoutsQuery.refetch()}
      />
    );
  }

  const layouts = layoutsQuery.data ?? [];

  return (
    <div className="space-y-6">
      {/* Top Action Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border bg-white p-4 shadow-sm">
        <div>
          <h2 className="text-base font-semibold text-ink">
            Danh sách bố cục Đảo Di Sản ({layouts.length})
          </h2>
          <p className="text-xs text-ink-muted">
            Mỗi bố cục quản lý theo phiên bản DRAFT → PUBLISHED → ARCHIVED. Người học mới tự động ghim vào phiên bản PUBLISHED mặc định.
          </p>
        </div>
        <Button
          onClick={() => {
            setActionError(null);
            setLayoutKey("");
            setName("");
            setDescription("");
            setThemeKey("heritage");
            setCanvasWidth("960");
            setCanvasHeight("720");
            setShowCreateModal(true);
          }}
        >
          <FolderPlus className="mr-1.5 size-4" />
          Tạo bố cục mới
        </Button>
      </div>

      {actionError && (
        <div className="rounded-lg border border-error/40 bg-error/10 px-4 py-3 text-sm text-error">
          {actionError}
        </div>
      )}

      {layouts.length === 0 ? (
        <EmptyState
          title="Chưa có bố cục Đảo Di Sản nào"
          description="Hãy tạo bố cục đầu tiên để thiết kế vùng đất, ô đặt vật phẩm và các lớp cảnh quan."
        />
      ) : (
        <div className="overflow-hidden rounded-xl border border-border bg-white shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-border bg-surface-alt text-xs font-semibold uppercase text-ink-muted">
                <tr>
                  <th className="px-4 py-3">Tên layout</th>
                  <th className="px-4 py-3">Key / Theme</th>
                  <th className="px-4 py-3">Canvas</th>
                  <th className="px-4 py-3">Số phiên bản</th>
                  <th className="px-4 py-3">Phiên bản đang xuất bản</th>
                  <th className="px-4 py-3">Trạng thái</th>
                  <th className="px-4 py-3">Cập nhật</th>
                  <th className="px-4 py-3 text-right">Thao tác</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {layouts.map((layout: LayoutSummaryDto) => {
                  const hasPublished = layout.publishedVersionId !== null;
                  const hasDraft = layout.latestDraftVersionId !== null;
                  return (
                    <tr
                      key={layout.id}
                      className="transition-colors hover:bg-surface-alt/50"
                    >
                      <td className="px-4 py-3.5">
                        <div className="flex items-center gap-2">
                          <span className="font-semibold text-ink">
                            {layout.name}
                          </span>
                          {layout.defaultLayout && (
                            <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-semibold text-amber-800">
                              <Sparkles className="size-3" />
                              Mặc định
                            </span>
                          )}
                        </div>
                        {layout.description && (
                          <p className="mt-0.5 line-clamp-1 text-xs text-ink-muted">
                            {layout.description}
                          </p>
                        )}
                      </td>
                      <td className="px-4 py-3.5">
                        <code className="rounded bg-surface-alt px-1.5 py-0.5 text-xs font-mono text-ink">
                          {layout.layoutKey}
                        </code>
                        <div className="mt-0.5 text-xs text-ink-muted">
                          Theme: {layout.themeKey || "heritage"}
                        </div>
                      </td>
                      <td className="px-4 py-3.5 text-xs text-ink-muted">
                        {layout.canvasWidth} × {layout.canvasHeight}px
                      </td>
                      <td className="px-4 py-3.5 font-medium text-ink">
                        {layout.versionCount} bản
                      </td>
                      <td className="px-4 py-3.5">
                        {hasPublished ? (
                          <span className="inline-flex items-center gap-1 rounded-md bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700">
                            <CheckCircle2 className="size-3.5" />
                            v{layout.publishedVersionNumber} (PUBLISHED)
                          </span>
                        ) : (
                          <span className="text-xs text-ink-muted">
                            Chưa xuất bản
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3.5">
                        <div className="flex flex-wrap gap-1.5">
                          {hasDraft && (
                            <span className="rounded bg-blue-50 px-2 py-0.5 text-xs font-medium text-blue-700">
                              Bản nháp v{layout.latestDraftVersionNumber}
                            </span>
                          )}
                          {!hasDraft && hasPublished && (
                            <span className="rounded bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700">
                              {layout.latestStatus}
                            </span>
                          )}
                          {!hasDraft && !hasPublished && (
                            <span className="rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600">
                              {layout.latestStatus}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3.5 text-xs text-ink-muted">
                        {new Date(layout.updatedAt).toLocaleString("vi-VN")}
                      </td>
                      <td className="px-4 py-3.5 text-right">
                        <div className="flex flex-wrap items-center justify-end gap-1.5">
                          {hasDraft ? (
                            <Button
                              size="sm"
                              onClick={() =>
                                router.push(
                                  `/island-builder/${layout.latestDraftVersionId}`,
                                )
                              }
                            >
                              <Edit3 className="mr-1 size-3.5" />
                              Sửa Draft v{layout.latestDraftVersionNumber}
                            </Button>
                          ) : (
                            <Button
                              size="sm"
                              disabled={createDraftMutation.isPending}
                              onClick={() =>
                                createDraftMutation.mutate(layout.id)
                              }
                            >
                              <Plus className="mr-1 size-3.5" />
                              Tạo bản nháp mới
                            </Button>
                          )}

                          {hasPublished && (
                            <Button
                              size="sm"
                              variant="secondary"
                              onClick={() =>
                                router.push(
                                  `/island-builder/${layout.publishedVersionId}?mode=preview`,
                                )
                              }
                            >
                              <Eye className="mr-1 size-3.5" />
                              Xem trước
                            </Button>
                          )}

                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() =>
                              setSelectedLayoutId(
                                selectedLayoutId === layout.id
                                  ? null
                                  : layout.id,
                              )
                            }
                          >
                            <History className="mr-1 size-3.5" />
                            Phiên bản
                          </Button>

                          {!layout.defaultLayout &&
                            (hasPublished ? (
                              <Button
                                size="sm"
                                variant="ghost"
                                disabled={setDefaultMutation.isPending}
                                onClick={() =>
                                  setDefaultMutation.mutate(layout.id)
                                }
                              >
                                Đặt mặc định
                              </Button>
                            ) : (
                              <span
                                className="inline-flex items-center rounded-md border border-border bg-surface-alt px-2.5 py-1 text-[11px] text-ink-muted"
                                title="Bố cục chỉ có thể đặt làm mặc định sau khi đã xuất bản ít nhất 1 phiên bản PUBLISHED"
                              >
                                Chưa thể đặt mặc định (cần Publish)
                              </span>
                            ))}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Drawer / Panel danh sách phiên bản của Layout đang chọn */}
      {selectedLayoutId && (
        <div className="rounded-xl border border-border bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Layers className="size-5 text-brand" />
              <h3 className="text-base font-semibold text-ink">
                Lịch sử phiên bản — {detailQuery.data?.name ?? "..."}
              </h3>
            </div>
            <div className="flex items-center gap-2">
              <Button
                size="sm"
                disabled={createDraftMutation.isPending}
                onClick={() => createDraftMutation.mutate(selectedLayoutId)}
              >
                <Plus className="mr-1 size-3.5" />
                Tạo phiên bản nháp mới
              </Button>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => setSelectedLayoutId(null)}
              >
                Đóng
              </Button>
            </div>
          </div>

          {detailQuery.isLoading ? (
            <Skeleton className="h-24 w-full" />
          ) : detailQuery.data ? (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-border bg-surface-alt text-xs font-semibold uppercase text-ink-muted">
                  <tr>
                    <th className="px-3 py-2">Phiên bản</th>
                    <th className="px-3 py-2">Trạng thái</th>
                    <th className="px-3 py-2">Revision</th>
                    <th className="px-3 py-2">Xuất bản lúc</th>
                    <th className="px-3 py-2">Cập nhật</th>
                    <th className="px-3 py-2 text-right">Hành động</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {detailQuery.data.versions.map((ver) => (
                    <tr key={ver.id}>
                      <td className="px-3 py-2.5 font-semibold text-ink">
                        Phiên bản v{ver.versionNumber}
                      </td>
                      <td className="px-3 py-2.5">
                        <span
                          className={
                            ver.status === "PUBLISHED"
                              ? "rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-semibold text-emerald-800"
                              : ver.status === "DRAFT"
                                ? "rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-semibold text-blue-800"
                                : "rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-semibold text-gray-700"
                          }
                        >
                          {ver.status}
                        </span>
                      </td>
                      <td className="px-3 py-2.5 font-mono text-xs">
                        #{ver.rowVersion}
                      </td>
                      <td className="px-3 py-2.5 text-xs text-ink-muted">
                        {ver.publishedAt
                          ? new Date(ver.publishedAt).toLocaleString("vi-VN")
                          : "—"}
                      </td>
                      <td className="px-3 py-2.5 text-xs text-ink-muted">
                        {new Date(ver.updatedAt).toLocaleString("vi-VN")}
                      </td>
                      <td className="px-3 py-2.5 text-right">
                        <div className="flex justify-end gap-1.5">
                          <Button
                            size="sm"
                            variant={
                              ver.status === "DRAFT" ? "primary" : "secondary"
                            }
                            onClick={() =>
                              router.push(`/island-builder/${ver.id}`)
                            }
                          >
                            {ver.status === "DRAFT" ? (
                              <>
                                <Edit3 className="mr-1 size-3.5" />
                                Mở Builder
                              </>
                            ) : (
                              <>
                                <Eye className="mr-1 size-3.5" />
                                Xem chi tiết
                              </>
                            )}
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={cloneVersionMutation.isPending}
                            onClick={() => cloneVersionMutation.mutate(ver.id)}
                          >
                            <Copy className="mr-1 size-3.5" />
                            Nhân bản ra Draft
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : null}
        </div>
      )}

      {/* Modal tạo bố cục mới */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-lg rounded-xl border border-border bg-white p-6 shadow-xl">
            <h3 className="text-lg font-bold text-ink">
              Tạo bố cục Đảo Di Sản mới
            </h3>
            <p className="mt-1 text-xs text-ink-muted">
              Hệ thống sẽ khởi tạo bố cục và tạo sẵn bản nháp v1 gồm 3 vùng đất (Tier 1/2/3) và 12 slot chuẩn để bạn chỉnh sửa trực quan.
            </p>

            <div className="mt-4 space-y-3">
              <div>
                <Label htmlFor="layout-key">Mã định danh (layoutKey)</Label>
                <Input
                  id="layout-key"
                  placeholder="vd: imperial-citadel-island"
                  value={layoutKey}
                  onChange={(e) => setLayoutKey(e.target.value)}
                />
              </div>

              <div>
                <Label htmlFor="layout-name">Tên hiển thị (name)</Label>
                <Input
                  id="layout-name"
                  placeholder="vd: Đảo Hoàng Thành Thăng Long"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>

              <div>
                <Label htmlFor="layout-desc">Mô tả</Label>
                <Input
                  id="layout-desc"
                  placeholder="Mô tả phong cách và bố cục đảo..."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <Label htmlFor="layout-theme">Theme Key</Label>
                  <Input
                    id="layout-theme"
                    value={themeKey}
                    onChange={(e) => setThemeKey(e.target.value)}
                  />
                </div>
                <div>
                  <Label htmlFor="canvas-w">Canvas Rộng (px)</Label>
                  <Input
                    id="canvas-w"
                    type="number"
                    value={canvasWidth}
                    onChange={(e) => setCanvasWidth(e.target.value)}
                  />
                </div>
                <div>
                  <Label htmlFor="canvas-h">Canvas Cao (px)</Label>
                  <Input
                    id="canvas-h"
                    type="number"
                    value={canvasHeight}
                    onChange={(e) => setCanvasHeight(e.target.value)}
                  />
                </div>
              </div>

              <div className="rounded-lg border border-amber-200 bg-amber-50/70 px-3 py-2 text-xs text-amber-900">
                Bố cục mới được khởi tạo với bản nháp <strong>DRAFT v1</strong>. Để tránh gián đoạn cho người học mới, bạn sẽ đặt làm bố cục mặc định sau khi kiểm tra và xuất bản (<strong>Publish</strong>).
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-2">
              <Button
                variant="secondary"
                onClick={() => setShowCreateModal(false)}
              >
                Hủy
              </Button>
              <Button
                disabled={
                  !layoutKey.trim() ||
                  !name.trim() ||
                  createLayoutMutation.isPending
                }
                onClick={() => createLayoutMutation.mutate()}
              >
                {createLayoutMutation.isPending
                  ? "Đang khởi tạo..."
                  : "Tạo & Mở Builder"}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
