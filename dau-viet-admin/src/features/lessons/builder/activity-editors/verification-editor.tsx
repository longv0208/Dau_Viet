"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";

import { EvidenceRefPicker } from "./evidence-ref-picker";
import {
  ActivityCommonFields,
  evidenceSelectActivities,
  type EditorProps,
} from "./shared-fields";

/**
 * VERIFICATION — Bước 3 Kiểm chứng (4-step flow).
 *
 * Chế độ interactive (mặc định, không có evidenceSource):
 *   Học viên thấy danh sách visibleSourceIds / visibleEvidenceIds và chọn
 *   bằng chứng ủng hộ giả thuyết của mình; server chấm selectedEvidenceIds.
 *
 * Chế độ legacy (có evidenceSource):
 *   Server tự chấm từ output của EVIDENCE_SELECT upstream — không cần UI
 *   tương tác.
 *
 * hypothesisSource: ghi đè activity HYPOTHESIS_CHOICE nguồn (dùng khi có
 * nhiều bước giả thuyết).
 */
export function VerificationEditor(props: EditorProps) {
  const { activity, stage, eventId, draft, readOnly, onChange } = props;
  const config = activity.config ?? {};
  const visibleIds = (config.visibleSourceIds as string[] | undefined) ?? [];
  const requiredIds = (config.requiredEvidenceIds as string[] | undefined) ?? [];
  const evidenceSource = String(config.evidenceSource ?? "");
  const hypothesisSource = String(config.hypothesisSource ?? "");
  const isLegacy = Boolean(evidenceSource);

  const sourceCandidates = evidenceSelectActivities(draft, activity.id, {
    stageId: stage.id,
    activityId: activity.id,
    required: activity.required,
  });
  const hypothesisCandidates = (draft?.stages ?? [])
    .flatMap((s) => s.activities)
    .filter((a) => a.type === "HYPOTHESIS_CHOICE" && a.id !== activity.id);

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />

      {/* Liên kết giả thuyết — mặc định server dùng giả thuyết đã chọn gần
          nhất; chỉ cần cấu hình khi có nhiều HYPOTHESIS_CHOICE. */}
      {hypothesisCandidates.length > 1 && (
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`hypsrc-${activity.id}`}>Liên kết giả thuyết</Label>
          <Select
            id={`hypsrc-${activity.id}`}
            value={hypothesisSource}
            disabled={readOnly}
            onChange={(e) =>
              onChange({
                config: {
                  ...config,
                  hypothesisSource: e.target.value || undefined,
                },
              })
            }
          >
            <option value="">— tự động (giả thuyết đã chọn ở Bước 2) —</option>
            {hypothesisCandidates.map((a) => (
              <option key={a.id} value={a.id}>
                {a.instruction?.slice(0, 50) || a.id}
              </option>
            ))}
          </Select>
          <p className="text-xs text-ink-muted">
            Chỉ cần chọn khi có nhiều bước giả thuyết trong bài học.
          </p>
        </div>
      )}

      {/* Chế độ kiểm chứng */}
      <div className="flex flex-col gap-1.5">
        <Label>Chế độ kiểm chứng</Label>
        <div className="flex gap-2">
          <label
            className={
              "flex flex-1 cursor-pointer items-start gap-2 rounded-md border px-3 py-2.5 text-sm " +
              (!isLegacy ? "border-brand bg-brand/5 text-ink" : "border-border text-ink-muted")
            }
          >
            <input
              type="radio"
              name={`vfmode-${activity.id}`}
              checked={!isLegacy}
              disabled={readOnly}
              className="mt-0.5 accent-brand"
              onChange={() => {
                const next = { ...config };
                delete next.evidenceSource;
                onChange({ config: next });
              }}
            />
            <span>
              <span className="block font-medium">Tương tác</span>
              <span className="block text-xs">
                Học viên tự chọn bằng chứng ủng hộ giả thuyết — server chấm
                lựa chọn của học viên.
              </span>
            </span>
          </label>
          <label
            className={
              "flex flex-1 cursor-pointer items-start gap-2 rounded-md border px-3 py-2.5 text-sm " +
              (isLegacy ? "border-brand bg-brand/5 text-ink" : "border-border text-ink-muted")
            }
          >
            <input
              type="radio"
              name={`vfmode-${activity.id}`}
              checked={isLegacy}
              disabled={readOnly}
              className="mt-0.5 accent-brand"
              onChange={() => {
                // Keep existing evidenceSource or show candidate picker
                onChange({ config: { ...config } });
              }}
            />
            <span>
              <span className="block font-medium">Tự động (legacy)</span>
              <span className="block text-xs">
                Server dùng bằng chứng đã thu thập từ EVIDENCE_SELECT trước
                đó — không cần tương tác thêm.
              </span>
            </span>
          </label>
        </div>
      </div>

      {/* Legacy mode: chọn EVIDENCE_SELECT nguồn */}
      {isLegacy && (
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`evsrc-${activity.id}`}>
            Nguồn bằng chứng đã thu thập
          </Label>
          <Select
            id={`evsrc-${activity.id}`}
            value={evidenceSource}
            disabled={readOnly}
            onChange={(e) =>
              onChange({
                config: { ...config, evidenceSource: e.target.value || undefined },
              })
            }
          >
            <option value="">— chọn hoạt động EVIDENCE_SELECT —</option>
            {sourceCandidates.map((c) => (
              <option key={c.id} value={c.id}>
                {c.label} ({c.stageId})
              </option>
            ))}
          </Select>
          <p className="text-xs text-ink-muted">
            Server chấm kiểm chứng dựa trên bằng chứng học viên đã chọn ở hoạt
            động EVIDENCE_SELECT này — không tin dữ liệu client gửi.
          </p>
        </div>
      )}

      {/* Interactive mode: bằng chứng hiển thị cho học viên chọn */}
      {!isLegacy && (
        <EvidenceRefPicker
          label="Bằng chứng học viên được xem và chọn"
          hint="Học viên sẽ chọn từ các nguồn này để ủng hộ giả thuyết của mình — đây là UI chọn bằng chứng ở Bước 3."
          selectedIds={visibleIds}
          eventId={eventId}
          readOnly={readOnly}
          onChange={(next) =>
            onChange({ config: { ...config, visibleSourceIds: next } })
          }
        />
      )}

      {/* Bằng chứng bắt buộc — server check selectedEvidenceIds ⊇ required */}
      <EvidenceRefPicker
        label="Bằng chứng bắt buộc phải có trong lựa chọn"
        hint="Bằng chứng học viên phải trích trong phần kiểm chứng (không hiển thị là đáp án cho học viên)."
        selectedIds={requiredIds}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) =>
          onChange({ config: { ...config, requiredEvidenceIds: next } })
        }
      />

      {/* maxAttempts */}
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`vfatt-${activity.id}`}>Số lần kiểm chứng tối đa</Label>
        <Input
          id={`vfatt-${activity.id}`}
          inputMode="numeric"
          className="w-28"
          value={String((config.maxAttempts as number | undefined) ?? "")}
          disabled={readOnly}
          placeholder="Không giới hạn"
          onChange={(e) => {
            const n = e.target.value.trim();
            const v = n === "" ? undefined : Number(n);
            if (v !== undefined && Number.isNaN(v)) return;
            onChange({ config: { ...config, maxAttempts: v } });
          }}
        />
        <p className="text-xs text-ink-muted">
          Để trống = không giới hạn (mặc định cũ). Khi hết lượt ở kết quả
          PARTIAL/CONTRADICTED, hoạt động tính là đã duyệt (exhausted) và học
          viên đi tiếp — kết quả không được nâng thành SUPPORTED; phản hồi
          &ldquo;Khi hết lượt thử&rdquo; ở phần trên sẽ hiển thị cho học viên.
        </p>
      </div>
    </div>
  );
}
