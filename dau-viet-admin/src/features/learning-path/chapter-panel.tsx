"use client";

import { useState } from "react";
import {
  ChevronDown,
  ChevronRight,
  Compass,
  FolderPlus,
  GitBranch,
  Landmark,
  Pencil,
  Plus,
  Trash2,
} from "lucide-react";
import type { PathChapter, PathDetail, PathNodeType } from "@/lib/dto/learning-path";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { cn } from "@/lib/utils";
import { ChapterForm } from "./chapter-form";
import { SortableList } from "./sortable-list";
import {
  buildChapterTree,
  type ChapterTreeNode,
  historicalYear,
  NODE_TYPE_META,
  type PathChange,
} from "./builder-types";

interface EditorModalState {
  mode: "create" | "edit";
  chapter?: PathChapter;
  initialNodeType?: PathNodeType;
  initialParentId?: string | null;
}

function NodeIcon({ nodeType }: { nodeType: PathNodeType }) {
  if (nodeType === "ERA") return <Landmark className="size-3.5 shrink-0" aria-hidden />;
  if (nodeType === "PERIOD") return <Compass className="size-3.5 shrink-0" aria-hidden />;
  return <GitBranch className="size-3.5 shrink-0" aria-hidden />;
}

export function ChapterPanel({
  detail,
  selectedId,
  disabled,
  readOnly,
  onSelect,
  change,
}: {
  detail: PathDetail;
  selectedId?: string;
  disabled: boolean;
  readOnly: boolean;
  onSelect: (id: string) => void;
  change: PathChange;
}) {
  const [modal, setModal] = useState<EditorModalState | null>(null);
  const [deleting, setDeleting] = useState<PathChapter | null>(null);
  const [collapsedIds, setCollapsedIds] = useState<Record<string, boolean>>({});

  const treeRoots = buildChapterTree(detail.chapters);

  const toggleCollapse = (id: string) => {
    setCollapsedIds((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  const renderTreeGroup = (nodes: ChapterTreeNode[], parentId: string | null) => {
    if (nodes.length === 0) return null;
    return (
      <SortableList
        items={nodes}
        getId={(node) => node.row.chapter.id}
        scope={`chapters:${detail.version.id}:${parentId ?? "root"}`}
        disabled={readOnly || disabled}
        onReorder={(chapterIds) =>
          change("/chapters/reorder", "PUT", { parentId, chapterIds })
        }
      >
        {(node) => {
          const { row, nodeType, children, totalSubtreeEvents } = node;
          const isSelected = selectedId === row.chapter.id;
          const isCollapsed = Boolean(collapsedIds[row.chapter.id]);
          const hasChildren = children.length > 0;
          const canDelete = row.events.length === 0 && !hasChildren;
          const meta = NODE_TYPE_META[nodeType];

          return (
            <div
              className={cn(
                "space-y-1.5",
                nodeType === "ERA" && "border-l-4 border-brand pl-2",
                nodeType === "PERIOD" && parentId && "border-l-2 border-warning/60 pl-2",
                nodeType === "PHASE" && "border-l-2 border-border pl-2",
              )}
            >
              <div
                className={cn(
                  "rounded-md border border-transparent px-2.5 py-2 transition-colors duration-150",
                  isSelected
                    ? "border-brand/40 bg-surface-alt ring-1 ring-brand/30"
                    : "hover:bg-surface-alt/70",
                )}
              >
                <div className="flex items-start gap-1.5">
                  {hasChildren ? (
                    <button
                      type="button"
                      onClick={() => toggleCollapse(row.chapter.id)}
                      aria-label={isCollapsed ? "Mở rộng nhánh con" : "Thu gọn nhánh con"}
                      className="mt-0.5 flex size-6 shrink-0 cursor-pointer items-center justify-center rounded text-ink-muted hover:bg-surface hover:text-ink"
                    >
                      {isCollapsed ? (
                        <ChevronRight className="size-4" aria-hidden />
                      ) : (
                        <ChevronDown className="size-4" aria-hidden />
                      )}
                    </button>
                  ) : (
                    <span className="mt-1 inline-block size-4 shrink-0" aria-hidden />
                  )}

                  <button
                    type="button"
                    onClick={() => onSelect(row.chapter.id)}
                    aria-pressed={isSelected}
                    className="min-w-0 flex-1 cursor-pointer text-left"
                  >
                    <div className="flex flex-wrap items-center gap-1.5">
                      <span
                        className={cn(
                          "inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[11px] font-semibold uppercase tracking-wide",
                          meta.badgeClass,
                        )}
                      >
                        <NodeIcon nodeType={nodeType} />
                        {meta.shortLabel} {row.chapter.sortOrder}
                      </span>
                      <span className="text-[11px] text-ink-muted">
                        {historicalYear(row.chapter.startYear)} – {historicalYear(row.chapter.endYear)}
                      </span>
                    </div>
                    <span className="mt-1 block font-medium text-ink">
                      {row.chapter.title}
                    </span>
                    <span className="mt-0.5 block text-xs text-ink-muted">
                      {nodeType === "ERA"
                        ? `${children.length} thời kỳ con · Tổng ${totalSubtreeEvents} sự kiện`
                        : hasChildren
                          ? `${row.events.length} sự kiện trực tiếp · ${children.length} giai đoạn con`
                          : `${row.events.length} sự kiện`}
                    </span>
                  </button>
                </div>

                {!readOnly && (
                  <div className="mt-2 flex flex-wrap items-center gap-1 pl-5">
                    {nodeType === "ERA" && (
                      <Button
                        type="button"
                        variant="secondary"
                        size="sm"
                        disabled={disabled}
                        className="h-7 px-2 text-xs"
                        onClick={() =>
                          setModal({
                            mode: "create",
                            initialNodeType: "PERIOD",
                            initialParentId: row.chapter.id,
                          })
                        }
                      >
                        <FolderPlus className="size-3.5" aria-hidden />
                        + Thời kỳ
                      </Button>
                    )}
                    {nodeType === "PERIOD" && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        disabled={disabled}
                        className="h-7 px-2 text-xs"
                        onClick={() =>
                          setModal({
                            mode: "create",
                            initialNodeType: "PHASE",
                            initialParentId: row.chapter.id,
                          })
                        }
                      >
                        <FolderPlus className="size-3.5" aria-hidden />
                        + Giai đoạn
                      </Button>
                    )}
                    <Button
                      variant="ghost"
                      size="icon"
                      disabled={disabled}
                      className="size-7"
                      aria-label={`Sửa ${row.chapter.title}`}
                      onClick={() => setModal({ mode: "edit", chapter: row })}
                    >
                      <Pencil className="size-3.5" aria-hidden />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      disabled={disabled || !canDelete}
                      className="size-7"
                      title={
                        !canDelete
                          ? "Chỉ xóa được đơn vị rỗng (không có nhánh con và không có sự kiện)"
                          : "Xóa đơn vị rỗng"
                      }
                      aria-label={`Xóa ${row.chapter.title}`}
                      onClick={() => setDeleting(row)}
                    >
                      <Trash2 className="size-3.5" aria-hidden />
                    </Button>
                  </div>
                )}
              </div>

              {hasChildren && !isCollapsed && (
                <div className="ml-4 border-l border-dashed border-border pl-2">
                  {renderTreeGroup(children, row.chapter.id)}
                </div>
              )}
            </div>
          );
        }}
      </SortableList>
    );
  };

  return (
    <section aria-label="Cây lộ trình lịch sử" className="space-y-3 p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 className="font-display text-lg font-semibold">Cây lộ trình</h2>
          <p className="text-xs text-ink-muted">
            Đại thời kỳ (ERA) → Thời kỳ (PERIOD) → Giai đoạn (PHASE)
          </p>
        </div>
        {!readOnly && (
          <div className="flex gap-1.5">
            <Button
              variant="secondary"
              size="sm"
              disabled={disabled}
              onClick={() =>
                setModal({
                  mode: "create",
                  initialNodeType: "ERA",
                  initialParentId: null,
                })
              }
            >
              <Plus className="size-3.5" aria-hidden />
              Đại thời kỳ
            </Button>
            <Button
              variant="secondary"
              size="icon"
              aria-label="Thêm đơn vị lộ trình"
              disabled={disabled}
              onClick={() =>
                setModal({
                  mode: "create",
                  initialNodeType: "PERIOD",
                  initialParentId: null,
                })
              }
            >
              <Plus aria-hidden />
            </Button>
          </div>
        )}
      </div>

      {renderTreeGroup(treeRoots, null)}

      {detail.chapters.length === 0 && (
        <p className="rounded-lg border border-dashed border-border p-5 text-sm text-ink-muted">
          Chưa có đơn vị nào trên cây lộ trình. Thêm Đại thời kỳ (ERA) hoặc Thời kỳ (PERIOD) đầu tiên để bắt đầu thiết kế.
        </p>
      )}

      {modal && (
        <ChapterForm
          chapter={modal.mode === "edit" ? modal.chapter : undefined}
          allChapters={detail.chapters}
          initialNodeType={modal.initialNodeType}
          initialParentId={modal.initialParentId}
          busy={disabled}
          onClose={() => setModal(null)}
          onSave={async (values) => {
            const result = await change(
              modal.mode === "create"
                ? "/chapters"
                : `/chapters/${modal.chapter!.chapter.id}`,
              modal.mode === "create" ? "POST" : "PATCH",
              values,
            );
            if (result && modal.mode === "create") {
              const added = result.chapters.find(
                (row) => !detail.chapters.some((old) => old.chapter.id === row.chapter.id),
              );
              if (added) onSelect(added.chapter.id);
            }
            return result != null;
          }}
        />
      )}

      <ConfirmDialog
        open={deleting != null}
        onOpenChange={(open) => {
          if (!open) setDeleting(null);
        }}
        title="Xóa đơn vị lộ trình rỗng?"
        description={deleting?.chapter.title}
        destructive
        confirmLabel="Xóa đơn vị"
        onConfirm={() => {
          if (deleting && !disabled) {
            void change(`/chapters/${deleting.chapter.id}`, "DELETE");
          }
        }}
      />
    </section>
  );
}
