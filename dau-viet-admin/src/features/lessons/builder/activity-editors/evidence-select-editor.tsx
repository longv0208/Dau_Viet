"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { EvidenceRefPicker } from "./evidence-ref-picker";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/**
 * EVIDENCE_SELECT — 2 chế độ rõ ràng:
 *  - COLLECT (graded:false): thu thập bằng chứng tự do (≥ minRequired), không trừ Thể lực;
 *    kết quả nuôi bước HYPOTHESIS_CHOICE / VERIFICATION / CER_CHOICE phía sau.
 *  - ASSESS  (graded:true) : chấm điểm theo tập đáp án acceptedEvidenceIds (F1),
 *    có giới hạn lượt thử (maxAttempts + remedialAttempts) và phản hồi đúng/sai từng thẻ đã chọn.
 */
export function EvidenceSelectEditor(props: EditorProps) {
  const { activity, eventId, readOnly, onChange } = props;
  const ids = (activity.config?.visibleEvidenceIds as string[] | undefined) ?? [];
  const minRequired = (activity.config?.minRequired as number | undefined) ?? "";
  const graded = activity.config?.graded === true;
  const acceptedIds = (activity.config?.acceptedEvidenceIds as string[] | undefined) ?? [];
  const maxAttemptsRaw = activity.config?.maxAttempts as number | undefined;
  const remedialAttemptsRaw = activity.config?.remedialAttempts as number | undefined;

  const visibleSet = new Set(ids);
  const extraAcceptedIds = acceptedIds.filter((id) => !visibleSet.has(id));
  const noDistractorWarning =
    graded &&
    ids.length > 0 &&
    acceptedIds.length > 0 &&
    extraAcceptedIds.length === 0 &&
    acceptedIds.length === ids.length;

  const effectiveMin =
    typeof minRequired === "number" && minRequired > 0 ? minRequired : 1;
  const effectiveMaxAttempts =
    typeof maxAttemptsRaw === "number" && maxAttemptsRaw > 0 ? maxAttemptsRaw : 1;
  const effectiveRemedial =
    typeof remedialAttemptsRaw === "number" && remedialAttemptsRaw > 0
      ? remedialAttemptsRaw
      : 0;

  const updateConfig = (nextConfig: Record<string, unknown>) => {
    onChange({ config: nextConfig });
  };

  const setMode = (nextGraded: boolean) => {
    const base: Record<string, unknown> = { ...(activity.config ?? {}) };
    if (nextGraded) {
      base.graded = true;
    } else {
      base.graded = false;
      delete base.acceptedEvidenceIds;
      delete base.maxAttempts;
      delete base.remedialAttempts;
    }
    updateConfig(base);
  };

  return (
    <div className="flex flex-col gap-3.5 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />

      <div
        className="rounded-md border border-amber-300/80 bg-amber-50/70 p-3 text-xs text-ink"
        data-testid="evidence-select-guide"
      >
        <p className="font-semibold text-ink">
          Hướng dẫn cơ chế hoạt động Chọn bằng chứng (EVIDENCE_SELECT)
        </p>
        <p className="mt-1 leading-relaxed text-ink-muted">
          Các bằng chứng học viên chọn ở bước này sẽ được hệ thống lưu lại và{" "}
          <strong className="font-semibold text-ink">
            chuyển tiếp sang bước Đặt giả thuyết, Kiểm chứng và Kết luận (CER)
          </strong>{" "}
          phía sau. Hãy chọn 1 trong 2 chế độ dưới đây tùy theo mục đích sư phạm của bài học:
        </p>
      </div>

      <fieldset className="flex flex-col gap-2" disabled={readOnly}>
        <legend className="text-sm font-medium text-ink">
          Chế độ hoạt động
        </legend>
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
          <label
            className={`flex cursor-pointer items-start gap-2.5 rounded-md border p-2.5 text-sm transition ${
              !graded
                ? "border-brand bg-brand/5 ring-1 ring-brand/30"
                : "border-border bg-white hover:bg-surface-muted/50"
            }`}
          >
            <input
              type="radio"
              name={`es-mode-${activity.id}`}
              className="mt-1 size-4 accent-brand"
              checked={!graded}
              disabled={readOnly}
              onChange={() => setMode(false)}
            />
            <span className="flex flex-col gap-0.5">
              <span className="font-semibold text-ink">
                Thu thập bằng chứng (không chấm điểm)
              </span>
              <span className="text-xs leading-relaxed text-ink-muted">
                Học viên chọn tự do các dấu vết họ thấy liên quan. Kết quả được mang
                sang bước Giả thuyết / Kiểm chứng — nếu thiếu bằng chứng, học viên sẽ
                được quay lại đây sửa sau khi đối chiếu. Không trừ Thể lực.
              </span>
            </span>
          </label>

          <label
            className={`flex cursor-pointer items-start gap-2.5 rounded-md border p-2.5 text-sm transition ${
              graded
                ? "border-brand bg-brand/5 ring-1 ring-brand/30"
                : "border-border bg-white hover:bg-surface-muted/50"
            }`}
          >
            <input
              type="radio"
              name={`es-mode-${activity.id}`}
              className="mt-1 size-4 accent-brand"
              checked={graded}
              disabled={readOnly}
              onChange={() => setMode(true)}
            />
            <span className="flex flex-col gap-0.5">
              <span className="font-semibold text-ink">
                Đánh giá bằng chứng (chấm điểm)
              </span>
              <span className="text-xs leading-relaxed text-ink-muted">
                Học viên phải chọn đúng tập đáp án. Sai → trừ Thể lực và tính lượt thử.
                Dùng khi danh sách có dấu vết &apos;bẫy&apos; (distractor) và bạn muốn
                kiểm tra khả năng phân biệt nguồn.
              </span>
            </span>
          </label>
        </div>
      </fieldset>

      <EvidenceRefPicker
        label="Bằng chứng học viên được xem"
        hint="Học viên sẽ chọn trong danh sách này — chọn từ thư viện bằng chứng. Nên có ít nhất 1–3 dấu vết 'bẫy' (liên quan đến sự kiện nhưng KHÔNG trả lời câu hỏi trung tâm) nếu bạn chọn chế độ Đánh giá — không thì học viên chỉ cần chọn tất cả là đúng."
        required
        selectedIds={ids}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) =>
          updateConfig({ ...activity.config, graded, visibleEvidenceIds: next })
        }
      />

      {graded && (
        <>
          <EvidenceRefPicker
            label="Bằng chứng đúng (đáp án) *"
            hint="Tập con của danh sách trên — không hiển thị cho học viên. Học viên chọn đúng hết mới được điểm tối đa; chọn thiếu hoặc thừa đều bị trừ điểm theo F1."
            required
            selectedIds={acceptedIds}
            eventId={eventId}
            readOnly={readOnly}
            onChange={(next) =>
              updateConfig({ ...activity.config, graded: true, acceptedEvidenceIds: next })
            }
          />

          {extraAcceptedIds.length > 0 && (
            <p
              role="alert"
              className="rounded-md border border-red-300 bg-red-50 px-3 py-2 text-xs text-red-800"
            >
              Có {extraAcceptedIds.length} bằng chứng đáp án chưa nằm trong danh sách
              hiển thị cho học viên — hãy thêm vào danh sách hiển thị hoặc gỡ khỏi đáp án.
            </p>
          )}

          {noDistractorWarning && (
            <p
              role="status"
              className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-xs text-amber-900"
            >
              Cảnh báo thiết kế: Tất cả {ids.length} bằng chứng hiển thị đều là đáp án
              đúng (chưa có dấu vết &apos;bẫy&apos;). Học viên chỉ cần chọn tất cả là đạt
              điểm tối đa — nên thêm ít nhất 1 dấu vết bẫy hoặc chuyển sang chế độ Thu thập.
            </p>
          )}

          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`att-${activity.id}`}>Số lần thử tối đa (có chấm)</Label>
            <Input
              id={`att-${activity.id}`}
              inputMode="numeric"
              className="w-28"
              value={String(maxAttemptsRaw ?? "")}
              disabled={readOnly}
              placeholder="1"
              onChange={(e) => {
                const n = e.target.value.trim();
                const v = n === "" ? undefined : Number(n);
                if (v !== undefined && Number.isNaN(v)) return;
                updateConfig({ ...activity.config, graded: true, maxAttempts: v });
              }}
            />
            <p className="text-xs text-ink-muted">
              Số lần học viên được nộp đáp án có chấm. Hết số này hoạt động tính là đã
              duyệt (exhausted) — học viên đi tiếp nhưng kết quả ghi theo lần cuối.
            </p>
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`rem-${activity.id}`}>Lượt sửa bài bổ sung (remedial)</Label>
            <Input
              id={`rem-${activity.id}`}
              inputMode="numeric"
              className="w-28"
              value={String(remedialAttemptsRaw ?? "")}
              disabled={readOnly}
              placeholder="0"
              onChange={(e) => {
                const n = e.target.value.trim();
                const v = n === "" ? undefined : Number(n);
                if (v !== undefined && Number.isNaN(v)) return;
                updateConfig({ ...activity.config, graded: true, remedialAttempts: v });
              }}
            />
            <p className="text-xs text-ink-muted">
              Lượt sửa chỉ mở khi (a) đã hết lượt chấm VÀ (b) học viên được đưa quay lại
              đây từ bước sau (ví dụ Kiểm chứng báo thiếu bằng chứng). Sau khi cạn cả hai
              ngân sách, câu trả lời đúng cũng không đổi kết quả.
            </p>
          </div>
        </>
      )}

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`min-${activity.id}`}>Số bằng chứng tối thiểu phải chọn</Label>
        <Input
          id={`min-${activity.id}`}
          inputMode="numeric"
          className="w-28"
          value={String(minRequired)}
          disabled={readOnly}
          placeholder="1"
          onChange={(e) => {
            const n = e.target.value.trim();
            const v = n === "" ? undefined : Number(n);
            if (v !== undefined && Number.isNaN(v)) return;
            updateConfig({
              ...activity.config,
              graded,
              minRequired: v,
            });
          }}
        />
        <p className="text-xs text-ink-muted">
          Ngưỡng để nút GỬI được bật — KHÔNG phải đáp án đúng. Ở chế độ Đánh giá, chọn
          đúng tập đáp án mới được điểm; ngưỡng này chỉ quyết định học viên có được phép
          submit hay không.
        </p>
      </div>

      <div
        className="rounded-md border border-border bg-surface-muted/40 p-3 text-xs"
        data-testid="evidence-select-learner-preview"
      >
        <p className="font-semibold text-ink">Xem trước trải nghiệm học viên trên ứng dụng:</p>
        {graded ? (
          <p className="mt-1 leading-relaxed text-ink-muted">
            Học viên thấy:{" "}
            <strong className="font-semibold text-ink">
              &quot;THU THẬP DẤU VẾT · CHỌN ĐÚNG CÁC DẤU VẾT LIÊN QUAN · Sai mất Thể lực · còn{" "}
              {effectiveMaxAttempts} lượt
              {effectiveRemedial > 0 ? ` + ${effectiveRemedial} sửa` : ""}&quot;
            </strong>{" "}
            (Đáp án đúng: {acceptedIds.length}/{ids.length} dấu vết; cần chọn tối thiểu{" "}
            {effectiveMin} thẻ để bật nút Gửi).
          </p>
        ) : (
          <p className="mt-1 leading-relaxed text-ink-muted">
            Học viên thấy:{" "}
            <strong className="font-semibold text-ink">
              &quot;THU THẬP DẤU VẾT · CHỌN ÍT NHẤT {effectiveMin}&quot;
            </strong>{" "}
            — Chọn các dấu vết bạn thấy liên quan đến câu hỏi — không mất Thể lực.
          </p>
        )}
      </div>
    </div>
  );
}
