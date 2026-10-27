"use client";

import { useState, type FormEvent } from "react";
import type { PathChapter } from "@/lib/dto/learning-path";
import { Dialog } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";

export function ChapterForm({ chapter, busy, onClose, onSave }: {
  chapter?: PathChapter;
  busy: boolean;
  onClose: () => void;
  onSave: (values: Record<string, unknown>) => Promise<boolean>;
}) {
  const data = chapter?.chapter;
  const [error, setError] = useState<string | null>(null);
  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const values = new FormData(event.currentTarget);
    const startYear = Number(values.get("startYear"));
    const endYear = Number(values.get("endYear"));
    if (!Number.isInteger(startYear) || !Number.isInteger(endYear) || startYear > endYear) {
      setError("Năm bắt đầu phải là số nguyên và không lớn hơn năm kết thúc."); return;
    }
    setError(null);
    const saved = await onSave({ code: String(values.get("code")).trim(), title: String(values.get("title")).trim(),
      description: String(values.get("description")), startYear, endYear,
      periodLabel: String(values.get("periodLabel")).trim(), themeKey: String(values.get("themeKey")).trim() });
    if (saved) onClose();
    else setError("Chưa lưu được chương. Kiểm tra thông báo lỗi và thử lại.");
  };
  return <Dialog open onOpenChange={(open) => { if (!open && !busy) onClose(); }} title={data ? "Chỉnh sửa chương" : "Thêm chương lịch sử"}
    description="Niên đại dùng để hiển thị. Thứ tự hành trình do bạn sắp xếp.">
    <form onSubmit={(event) => void submit(event)} className="space-y-4">
      <fieldset disabled={busy} className="space-y-4">
        <div><Label htmlFor="chapter-title">Tên chương</Label><Input id="chapter-title" name="title" required maxLength={255} defaultValue={data?.title ?? ""} autoFocus /></div>
        <div><Label htmlFor="chapter-code">Mã chương</Label><Input id="chapter-code" name="code" required maxLength={64} defaultValue={data?.code ?? ""} /></div>
        <div><Label htmlFor="chapter-description">Mô tả</Label><Textarea id="chapter-description" name="description" defaultValue={data?.description ?? ""} /></div>
        <div className="grid grid-cols-2 gap-3">
          <div><Label htmlFor="chapter-start">Năm bắt đầu</Label><Input id="chapter-start" name="startYear" type="number" step={1} min={-2147483647} max={2147483647} required defaultValue={data?.startYear ?? ""} /></div>
          <div><Label htmlFor="chapter-end">Năm kết thúc</Label><Input id="chapter-end" name="endYear" type="number" step={1} min={-2147483647} max={2147483647} required defaultValue={data?.endYear ?? ""} /></div>
        </div>
        <p className="text-xs text-ink-muted">Dùng số âm cho năm trước Công nguyên.</p>
        <div><Label htmlFor="chapter-period">Nhãn thời kỳ</Label><Input id="chapter-period" name="periodLabel" required maxLength={120} defaultValue={data?.periodLabel ?? ""} /></div>
        <div><Label htmlFor="chapter-theme">Theme key</Label><Input id="chapter-theme" name="themeKey" required maxLength={64} defaultValue={data?.themeKey ?? ""} /></div>
        {error && <p role="alert" className="text-sm text-error">{error}</p>}
        <div className="flex justify-end gap-2"><Button type="button" variant="secondary" onClick={onClose}>Hủy</Button><Button type="submit">{busy ? "Đang lưu…" : "Lưu chương"}</Button></div>
      </fieldset>
    </form>
  </Dialog>;
}
