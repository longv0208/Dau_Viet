"use client";

import type { AdminPolicyValidation } from "@/lib/dto/gamification";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";

/**
 * Confirm publish — hien diff tu PUBLISHED hien tai sang DRAFT moi:
 * required +/−, optional count, threshold cu/moi. Admin xem truoc
 * truoc khi chot.
 */
export function PolicyPublishDialog({
  open,
  onOpenChange,
  validation,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  validation: AdminPolicyValidation | null;
  onConfirm: () => void;
}) {
  const diff = validation?.diff;
  const isInvalid = validation?.valid === false;
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Xuất bản chính sách mới?"
      description="Phiên bản PUBLISHED hiện tại (nếu có) sẽ chuyển sang ARCHIVED. Tiến trình learner đã đạt không bị thu hồi."
      footer={
        <>
          <Button variant="secondary" onClick={() => onOpenChange(false)}>
            Hủy
          </Button>
          <Button
            disabled={isInvalid}
            onClick={() => {
              onConfirm();
              onOpenChange(false);
            }}
          >
            Xuất bản
          </Button>
        </>
      }
    >
      {validation && !validation.valid && (
        <div
          role="alert"
          className="mb-3 rounded-md border border-error/40 bg-error/10 p-3 text-sm text-error"
        >
          <p className="font-semibold">Chính sách chưa đủ điều kiện xuất bản:</p>
          <ul className="mt-1 flex flex-col gap-1">
            {validation.errors.map((e, i) => (
              <li key={i}>
                <span className="font-medium">[{e.code}]</span> {e.message}
                {e.field ? (
                  <span className="text-ink-muted"> — {e.field}</span>
                ) : null}
              </li>
            ))}
          </ul>
        </div>
      )}
      {diff?.from && diff.to && (
        <div className="rounded-md border border-border bg-surface-alt p-3 text-sm">
          <p>
            v{diff.from.policyVersion} → v{diff.to.policyVersion}
          </p>
          <p>
            Bắt buộc: {diff.from.requiredCount} → {diff.to.requiredCount}
            {diff.to.requiredAdded.length > 0 &&
              ` (+${diff.to.requiredAdded.length})`}
            {diff.to.requiredRemoved.length > 0 &&
              ` (−${diff.to.requiredRemoved.length})`}
          </p>
          <p>
            Ngưỡng mastered:{" "}
            {diff.from.masteryThreshold == null
              ? "—"
              : `${diff.from.masteryThreshold}%`}{" "}
            →{" "}
            {diff.to.masteryThreshold == null
              ? "—"
              : `${diff.to.masteryThreshold}%`}
          </p>
        </div>
      )}
    </Dialog>
  );
}
