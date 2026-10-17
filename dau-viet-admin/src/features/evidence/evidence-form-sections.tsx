"use client";

import type { UseFormRegister, FieldErrors } from "react-hook-form";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { EvidenceReliability } from "@/lib/dto/evidence";

import { EVIDENCE_TYPES, EVIDENCE_TYPE_LABELS, RELIABILITY_LABELS } from "./evidence-labels";
import type { EvidenceFormValues } from "./evidence-form-schema";

/** Top block: event + type + title. */
export function EvidenceBasicFields({
  register,
  errors,
  isEdit,
  events,
}: {
  register: UseFormRegister<EvidenceFormValues>;
  errors: FieldErrors<EvidenceFormValues>;
  isEdit: boolean;
  events: AdminEventSummary[];
}) {
  return (
    <>
      <div className="grid gap-4 md:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="eventId">Sự kiện *</Label>
          <Select
            id="eventId"
            aria-invalid={Boolean(errors.eventId)}
            disabled={isEdit}
            {...register("eventId")}
          >
            <option value="">— Chọn sự kiện —</option>
            {events.map((ev) => (
              <option key={ev.id} value={ev.id}>
                {ev.title}
              </option>
            ))}
          </Select>
          {isEdit && (
            <p className="text-xs text-ink-muted">Không đổi sự kiện sau khi đã tạo.</p>
          )}
          {errors.eventId && (
            <p role="alert" className="text-xs text-error">{errors.eventId.message}</p>
          )}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="evidenceType">Loại bằng chứng *</Label>
          <Select
            id="evidenceType"
            aria-invalid={Boolean(errors.evidenceType)}
            {...register("evidenceType")}
          >
            <option value="">— Chọn loại —</option>
            {EVIDENCE_TYPES.map((t) => (
              <option key={t} value={t}>
                {EVIDENCE_TYPE_LABELS[t]?.label ?? t}
              </option>
            ))}
          </Select>
          {errors.evidenceType && (
            <p role="alert" className="text-xs text-error">{errors.evidenceType.message}</p>
          )}
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="title">Tiêu đề *</Label>
        <Input
          id="title"
          placeholder="Ví dụ: Bản đồ sông Bạch Đằng khắc gỗ"
          aria-invalid={Boolean(errors.title)}
          {...register("title")}
        />
        {errors.title && <p role="alert" className="text-xs text-error">{errors.title.message}</p>}
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="description">Mô tả</Label>
        <Textarea
          id="description"
          rows={3}
          placeholder="Ngắn gọn về nội dung và bối cảnh bằng chứng."
          {...register("description")}
        />
        {errors.description && (
          <p role="alert" className="text-xs text-error">{errors.description.message}</p>
        )}
      </div>
    </>
  );
}

/** Source citation block — emphasises the sourceTitle requirement. */
export function EvidenceSourceFields({
  register,
  errors,
}: {
  register: UseFormRegister<EvidenceFormValues>;
  errors: FieldErrors<EvidenceFormValues>;
}) {
  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-surface p-4">
      <p className="text-sm font-medium text-ink">Nguồn trích dẫn</p>
      <p className="text-xs text-ink-muted">
        Cần ít nhất tên nguồn để đánh dấu là đã chứng thực. Thiếu nguồn, bằng
        chứng sẽ bị cảnh báo khi dùng trong bài học.
      </p>
      <div className="grid gap-4 md:grid-cols-2">
        <div className="flex flex-col gap-1.5 md:col-span-2">
          <Label htmlFor="sourceTitle">Tên nguồn *</Label>
          <Input
            id="sourceTitle"
            placeholder="Ví dụ: Đại Việt sử ký toàn thư"
            aria-invalid={Boolean(errors.sourceTitle)}
            {...register("sourceTitle")}
          />
          {errors.sourceTitle && (
            <p role="alert" className="text-xs text-error">{errors.sourceTitle.message}</p>
          )}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="sourceAuthor">Tác giả</Label>
          <Input id="sourceAuthor" placeholder="Ngô Sĩ Liên" {...register("sourceAuthor")} />
          {errors.sourceAuthor && (
            <p role="alert" className="text-xs text-error">{errors.sourceAuthor.message}</p>
          )}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="sourcePublishedAt">Năm xuất bản / triển khai</Label>
          <Input
            id="sourcePublishedAt"
            type="date"
            {...register("sourcePublishedAt")}
          />
          {errors.sourcePublishedAt && (
            <p role="alert" className="text-xs text-error">{errors.sourcePublishedAt.message}</p>
          )}
        </div>
        <div className="flex flex-col gap-1.5 md:col-span-2">
          <Label htmlFor="sourceUrl">Đường dẫn nguồn</Label>
          <Input
            id="sourceUrl"
            type="url"
            placeholder="https://…"
            {...register("sourceUrl")}
          />
          {errors.sourceUrl && (
            <p role="alert" className="text-xs text-error">{errors.sourceUrl.message}</p>
          )}
        </div>
        <div className="flex flex-col gap-1.5 md:col-span-2">
          <Label htmlFor="sourceCitation">Trích dẫn đầy đủ</Label>
          <Textarea
            id="sourceCitation"
            rows={2}
            placeholder="Ví dụ: Ngô Sĩ Liên (1479), Đại Việt sử ký toàn thư, quyển 5."
            {...register("sourceCitation")}
          />
          {errors.sourceCitation && (
            <p role="alert" className="text-xs text-error">{errors.sourceCitation.message}</p>
          )}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="reliability">Độ tin cậy</Label>
          <Select id="reliability" {...register("reliability")}>
            <option value="">— Chưa đánh giá —</option>
            {(["HIGH", "MEDIUM", "LOW", "UNASSESSED"] as EvidenceReliability[]).map((r) => (
              <option key={r} value={r}>
                {RELIABILITY_LABELS[r] ?? r}
              </option>
            ))}
          </Select>
          {errors.reliability && (
            <p role="alert" className="text-xs text-error">{errors.reliability.message}</p>
          )}
        </div>
      </div>
    </div>
  );
}
