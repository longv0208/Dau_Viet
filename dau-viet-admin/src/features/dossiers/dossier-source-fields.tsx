"use client";

import type { DossierSource } from "@/lib/dto/gamification";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";

const RELIABILITIES = ["HIGH", "MEDIUM", "LOW", "UNASSESSED"] as const;
const REL_LABELS: Record<(typeof RELIABILITIES)[number], string> = {
  HIGH: "Cao",
  MEDIUM: "Trung bình",
  LOW: "Thấp",
  UNASSESSED: "Chưa đánh giá",
};

/** Fieldset nguon tham khao — dung chung create + edit. */
export function DossierSourceFields({
  value,
  onChange,
}: {
  value: DossierSource;
  onChange: (v: DossierSource) => void;
}) {
  const set = (patch: Partial<DossierSource>) =>
    onChange({ ...value, ...patch });

  return (
    <fieldset className="flex flex-col gap-3 rounded-lg border border-border p-4">
      <legend className="px-1 text-sm font-medium text-ink">
        Nguồn tham khảo
      </legend>
      <div>
        <Label htmlFor="src-title">Tên nguồn *</Label>
        <Input
          id="src-title"
          value={value.title ?? ""}
          onChange={(e) => set({ title: e.target.value })}
          placeholder="VD: Đại Việt sử ký toàn thư"
        />
      </div>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <div>
          <Label htmlFor="src-author">Tác giả</Label>
          <Input
            id="src-author"
            value={value.author ?? ""}
            onChange={(e) => set({ author: e.target.value || null })}
          />
        </div>
        <div>
          <Label htmlFor="src-rel">Độ tin cậy</Label>
          <Select
            id="src-rel"
            value={value.reliability ?? ""}
            onChange={(e) =>
              set({
                reliability: (e.target.value ||
                  null) as DossierSource["reliability"],
              })
            }
          >
            <option value="">—</option>
            {RELIABILITIES.map((r) => (
              <option key={r} value={r}>
                {REL_LABELS[r]}
              </option>
            ))}
          </Select>
        </div>
      </div>
      <div>
        <Label htmlFor="src-citation">Trích dẫn</Label>
        <Input
          id="src-citation"
          value={value.citation ?? ""}
          onChange={(e) => set({ citation: e.target.value || null })}
          placeholder="VD: Ngoại kỷ, quyển 5, kỷ Ngô Quyền"
        />
      </div>
      <div>
        <Label htmlFor="src-url">Đường dẫn</Label>
        <Input
          id="src-url"
          type="url"
          value={value.url ?? ""}
          onChange={(e) => set({ url: e.target.value || null })}
          placeholder="https://…"
        />
      </div>
    </fieldset>
  );
}
