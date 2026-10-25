"use client";

import type { AdminPolicyValidation } from "@/lib/dto/gamification";
import { ConfirmDialog } from "@/components/confirm-dialog";

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
  return (
    <ConfirmDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Xuất bản chính sách mới?"
      description="Phiên bản PUBLISHED hiện tại (nếu có) sẽ chuyển sang ARCHIVED. Tiến trình learner đã đạt không bị thu hồi."
      confirmLabel="Xuất bản"
      onConfirm={onConfirm}
    >
      {diff?.from && diff.to && (
        <div className="mt-4 rounded-md border border-border bg-surface-alt p-3 text-sm">
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
            Tuỳ chọn: {diff.from.optionalCount} → {diff.to.optionalCount}
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
    </ConfirmDialog>
  );
}
