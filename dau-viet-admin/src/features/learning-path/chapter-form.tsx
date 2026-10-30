"use client";

import { useState, type FormEvent } from "react";
import type { PathChapter, PathNodeType } from "@/lib/dto/learning-path";
import { HeritageBackgroundEditor } from "@/components/heritage/heritage-background-editor";
import {
  normalizeHeritageBackgroundConfig,
  type HeritageBackgroundConfig,
} from "@/lib/dto/heritage-background";
import { Dialog } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import {
  getAllowedParentChapters,
  NODE_TYPE_META,
  resolveNodeType,
} from "./builder-types";

export function ChapterForm({
  chapter,
  allChapters,
  initialNodeType,
  initialParentId,
  busy,
  onClose,
  onSave,
}: {
  chapter?: PathChapter;
  allChapters: PathChapter[];
  initialNodeType?: PathNodeType;
  initialParentId?: string | null;
  busy: boolean;
  onClose: () => void;
  onSave: (values: Record<string, unknown>) => Promise<boolean>;
}) {
  const data = chapter?.chapter;
  const defaultType: PathNodeType = data
    ? resolveNodeType(chapter)
    : initialNodeType ?? "PERIOD";
  const [nodeType, setNodeType] = useState<PathNodeType>(defaultType);
  const allowedParents = getAllowedParentChapters(
    allChapters,
    nodeType,
    data?.id,
  );
  const [parentId, setParentId] = useState<string>(() => {
    const raw = data ? data.parentId : initialParentId ?? null;
    if (!raw) return "";
    return raw;
  });
  const [error, setError] = useState<string | null>(null);
  const [titlePreview, setTitlePreview] = useState(data?.title ?? "");
  const [periodLabelPreview, setPeriodLabelPreview] = useState(
    data?.periodLabel ?? "",
  );
  const [backgroundConfig, setBackgroundConfig] =
    useState<HeritageBackgroundConfig>(() =>
      normalizeHeritageBackgroundConfig(data?.backgroundConfig),
    );

  const hasChildren = Boolean(
    data && allChapters.some((c) => c.chapter.parentId === data.id),
  );
  const hasEvents = Boolean(chapter && chapter.events.length > 0);

  const handleNodeTypeChange = (nextType: PathNodeType) => {
    setNodeType(nextType);
    const nextAllowed = getAllowedParentChapters(allChapters, nextType, data?.id);
    if (nextType === "ERA") {
      setParentId("");
    } else if (nextType === "PHASE") {
      if (!nextAllowed.some((c) => c.chapter.id === parentId)) {
        setParentId(nextAllowed[0]?.chapter.id ?? "");
      }
    } else if (parentId && !nextAllowed.some((c) => c.chapter.id === parentId)) {
      setParentId("");
    }
  };

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const values = new FormData(event.currentTarget);
    const startYear = Number(values.get("startYear"));
    const endYear = Number(values.get("endYear"));
    if (!Number.isInteger(startYear) || !Number.isInteger(endYear) || startYear > endYear) {
      setError("Năm bắt đầu phải là số nguyên và không lớn hơn năm kết thúc.");
      return;
    }
    if (nodeType === "ERA" && hasEvents) {
      setError("Không thể đổi sang Đại thời kỳ (ERA) khi chương đang chứa sự kiện trực tiếp.");
      return;
    }
    if (nodeType === "PHASE" && !parentId) {
      setError("Giai đoạn con (PHASE) bắt buộc phải trực thuộc một Thời kỳ (PERIOD).");
      return;
    }
    setError(null);
    const resolvedParentId =
      nodeType === "ERA" ? null : parentId.trim() ? parentId.trim() : null;

    const rawCoverImageKey = String(values.get("coverImageKey") ?? "").trim();
    const selectedParent = allowedParents.find((p) => p.chapter.id === resolvedParentId);

    const saved = await onSave({
      code: String(values.get("code")).trim(),
      title: String(values.get("title")).trim(),
      description: String(values.get("description")),
      startYear,
      endYear,
      periodLabel: String(values.get("periodLabel")).trim(),
      themeKey: String(values.get("themeKey")).trim(),
      coverImageKey: rawCoverImageKey || undefined,
      ...(data?.coverImageKey && !rawCoverImageKey ? { clearCoverImage: true } : {}),
      backgroundConfig,
      nodeType,
      parentId: resolvedParentId,
    });
    if (saved) onClose();
    else setError("Chưa lưu được đơn vị lộ trình. Kiểm tra thông báo lỗi và thử lại.");
  };

  const selectedParentTitle =
    allowedParents.find((p) => p.chapter.id === parentId)?.chapter.title;

  return (
    <Dialog
      open
      size="xl"
      onOpenChange={(open) => {
        if (!open && !busy) onClose();
      }}
      title={data ? "Chỉnh sửa đơn vị lộ trình" : "Thêm đơn vị vào cây lộ trình"}
      description="Thiết kế phân cấp Đại thời kỳ (ERA) → Thời kỳ (PERIOD) → Giai đoạn con (PHASE)."
    >
      <form onSubmit={(event) => void submit(event)} className="space-y-4">
        <fieldset disabled={busy} className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <Label htmlFor="chapter-node-type">Cấp đơn vị (Node Type)</Label>
              <Select
                id="chapter-node-type"
                value={nodeType}
                onChange={(e) => handleNodeTypeChange(e.target.value as PathNodeType)}
              >
                <option value="ERA" disabled={hasEvents}>
                  Đại thời kỳ (ERA) — Cấp gốc
                </option>
                <option value="PERIOD">
                  Thời kỳ (PERIOD) — Đơn vị mở khóa
                </option>
                <option value="PHASE" disabled={hasChildren}>
                  Giai đoạn con (PHASE) — Nhánh nhỏ
                </option>
              </Select>
            </div>

            <div>
              <Label htmlFor="chapter-parent">Trực thuộc đơn vị cha</Label>
              {nodeType === "ERA" ? (
                <Input
                  id="chapter-parent"
                  disabled
                  value="— Cấp gốc (Không có đơn vị cha) —"
                />
              ) : (
                <Select
                  id="chapter-parent"
                  value={parentId}
                  onChange={(e) => setParentId(e.target.value)}
                  required={nodeType === "PHASE"}
                >
                  {nodeType === "PERIOD" && (
                    <option value="">— Cấp gốc (Độc lập) —</option>
                  )}
                  {nodeType === "PHASE" && allowedParents.length === 0 && (
                    <option value="">— Chưa có Thời kỳ (PERIOD) nào —</option>
                  )}
                  {allowedParents.map((p) => (
                    <option key={p.chapter.id} value={p.chapter.id}>
                      [{resolveNodeType(p)}] {p.chapter.title}
                    </option>
                  ))}
                </Select>
              )}
            </div>
          </div>

          <p className="rounded-md border border-border bg-surface px-3 py-2 text-xs text-ink-muted">
            {NODE_TYPE_META[nodeType].description}
          </p>

          <div>
            <Label htmlFor="chapter-title">Tên hiển thị *</Label>
            <Input
              id="chapter-title"
              name="title"
              required
              maxLength={255}
              placeholder={
                nodeType === "ERA"
                  ? "Ví dụ: Thời kỳ Phong kiến Độc lập Tự chủ"
                  : nodeType === "PERIOD"
                    ? "Ví dụ: Thời nhà Lý"
                    : "Ví dụ: Kháng chiến chống Tống giai đoạn 2"
              }
              defaultValue={data?.title ?? ""}
              onChange={(e) => setTitlePreview(e.target.value)}
              autoFocus
            />
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <Label htmlFor="chapter-code">Mã định danh (Code) *</Label>
              <Input
                id="chapter-code"
                name="code"
                required
                maxLength={64}
                placeholder="LY_DYNASTY"
                defaultValue={data?.code ?? ""}
              />
            </div>
            <div>
              <Label htmlFor="chapter-theme">Theme key *</Label>
              <Input
                id="chapter-theme"
                name="themeKey"
                required
                maxLength={64}
                placeholder="LY_DYNASTY"
                defaultValue={data?.themeKey ?? "EARLY_INDEPENDENCE"}
              />
            </div>
          </div>
          <div>
            <Label htmlFor="chapter-description">Mô tả tóm tắt</Label>
            <Textarea
              id="chapter-description"
              name="description"
              rows={2}
              defaultValue={data?.description ?? ""}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label htmlFor="chapter-start">Năm bắt đầu *</Label>
              <Input
                id="chapter-start"
                name="startYear"
                type="number"
                step={1}
                min={-2147483647}
                max={2147483647}
                required
                defaultValue={data?.startYear ?? ""}
              />
            </div>
            <div>
              <Label htmlFor="chapter-end">Năm kết thúc *</Label>
              <Input
                id="chapter-end"
                name="endYear"
                type="number"
                step={1}
                min={-2147483647}
                max={2147483647}
                required
                defaultValue={data?.endYear ?? ""}
              />
            </div>
          </div>
          <p className="text-xs text-ink-muted">Dùng số âm cho năm trước Công nguyên (ví dụ: -2879).</p>
          <div>
            <Label htmlFor="chapter-period">Nhãn niên đại hiển thị *</Label>
            <Input
              id="chapter-period"
              name="periodLabel"
              required
              maxLength={120}
              placeholder="Năm 1009 – năm 1225"
              defaultValue={data?.periodLabel ?? ""}
              onChange={(e) => setPeriodLabelPreview(e.target.value)}
            />
          </div>
          {nodeType === "PERIOD" && (
            <div>
              <Label htmlFor="chapter-cover-image">
                Khóa ảnh đại diện / Thumbnail thẻ thời kỳ (tùy chọn)
              </Label>
              <Input
                id="chapter-cover-image"
                name="coverImageKey"
                maxLength={255}
                placeholder="periods/LY_DYNASTY/cover.jpg"
                defaultValue={data?.coverImageKey ?? ""}
              />
              <p className="mt-1 text-xs text-ink-muted">
                Ảnh nhỏ hiển thị ở danh sách chọn thời kỳ (phân biệt với{" "}
                <strong>Ảnh nền Hành trình thời kỳ</strong> bên dưới). Bỏ trống
                để dùng ảnh đại diện mặc định theo <code>code</code>.
              </p>
            </div>
          )}
          <HeritageBackgroundEditor
            value={backgroundConfig}
            onChange={setBackgroundConfig}
            disabled={busy}
            contextType="period"
            previewTitle={titlePreview}
            previewSubtitle={periodLabelPreview}
            previewParentTitle={selectedParentTitle}
          />
          {error && (
            <p role="alert" className="text-sm text-error">
              {error}
            </p>
          )}
          <div className="flex justify-end gap-2">
            <Button type="button" variant="secondary" onClick={onClose}>
              Hủy
            </Button>
            <Button type="submit">{busy ? "Đang lưu…" : "Lưu đơn vị"}</Button>
          </div>
        </fieldset>
      </form>
    </Dialog>
  );
}
