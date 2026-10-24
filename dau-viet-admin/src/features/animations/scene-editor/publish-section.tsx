"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { ApiClientError } from "@/lib/api-error";
import { qk } from "@/lib/query-keys";

import { animationApi } from "../animation-api";
import type { AnimationSceneDetail, SceneFieldError } from "../animation-types";
import { Section } from "./editor-sections";

/**
 * Section Xuất bản — kiểm tra (validate) hiển thị lỗi theo path, rồi
 * publish tạo phiên bản bất biến mới. Publish yêu cầu draft đã lưu
 * (expectedRowVersion khớp); xung đột 409 báo tải lại.
 */
export function PublishSection({
  scene,
  onSaved,
  onArchived,
}: {
  scene: AnimationSceneDetail;
  onSaved: () => void;
  /** FIX-03: archive thành công → parent refetch + đồng bộ local scene state. */
  onArchived?: () => void;
}) {
  const router = useRouter();
  const qc = useQueryClient();
  const [errors, setErrors] = useState<SceneFieldError[] | null>(null);
  const [checked, setChecked] = useState(false);

  const validate = useMutation({
    mutationFn: () => animationApi.validateScene(scene.id),
    onSuccess: (r) => {
      setErrors(r.errors);
      setChecked(true);
    },
  });

  const publish = useMutation({
    mutationFn: async () => {
      // Gate: validate trước — có lỗi thì không gọi publish.
      const r = await animationApi.validateScene(scene.id);
      setErrors(r.errors);
      setChecked(true);
      if (!r.ready) throw new Error("Cảnh chưa đạt điều kiện xuất bản — sửa các lỗi bên dưới.");
      // rowVersion phải là bản mới nhất: prop `scene` được chụp lúc load trang
      // và không tự cập nhật sau "Lưu nháp" (PATCH tăng rowVersion phía server).
      // Đọc lại từ query cache — save mutation đã setQueryData bản fresh.
      const fresh = qc.getQueryData<AnimationSceneDetail>(qk.animationScenes.detail(scene.id));
      return animationApi.publishScene(scene.id, fresh?.rowVersion ?? scene.rowVersion);
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["animation-scenes"] });
      // FIX-02: refetch scene detail NGAY sau publish — cập nhật
      // status/rowVersion/currentVersionId/currentVersionNo trong cache
      // và gọi onSaved() để editor refetch state nội bộ. Tránh lần
      // publish/upload kế tiếp gửi expectedRowVersion cũ → 409 giả.
      // Optimistic locking vẫn giữ: conflict THẬT (hai admin cùng sửa)
      // vẫn trả 409 như trước.
      try {
        const fresh = await animationApi.getScene(scene.id);
        qc.setQueryData(qk.animationScenes.detail(scene.id), fresh);
      } catch {
        // best-effort — onSaved dưới vẫn cố refetch qua prop callback
      }
      onSaved();
      router.refresh();
    },
  });

  const archive = useMutation({
    mutationFn: () => animationApi.archiveScene(scene.id),
    onSuccess: (fresh) => {
      qc.invalidateQueries({ queryKey: ["animation-scenes"] });
      // Archive trả về scene detail → setQueryData + callback cho parent
      // (HtmlSceneEditor giữ scene trong local state, invalidate không đủ).
      qc.setQueryData(qk.animationScenes.detail(scene.id), fresh);
      onArchived?.();
    },
  });

  const conflict =
    publish.error instanceof ApiClientError && publish.error.status === 409;

  return (
    <Section title="Xuất bản & phiên bản" defaultOpen={false}>
      <div className="flex flex-col gap-3">
        <p className="text-xs text-ink-muted">
          Xuất bản đóng băng cảnh thành một phiên bản bất biến (snapshot +
          checksum). Bài học ghim theo phiên bản — sửa cảnh sau xuất bản không
          ảnh hưởng phiên bản đã phát hành.
        </p>

        {scene.status === "DRAFT" && (
          <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-xs text-amber-800">
            Nhớ bấm “Lưu nháp” trước khi xuất bản — phiên bản được tạo từ bản
            nháp đã lưu trên máy chủ, không phải nội dung đang gõ.
          </p>
        )}

        <div className="flex flex-wrap items-center gap-2">
          <Button variant="secondary" size="sm" onClick={() => validate.mutate()} disabled={validate.isPending}>
            {validate.isPending ? "Đang kiểm tra…" : "Kiểm tra cảnh"}
          </Button>
          {scene.status !== "ARCHIVED" && (
            <Button size="sm" onClick={() => publish.mutate()} disabled={publish.isPending}>
              {publish.isPending ? "Đang xuất bản…" : "Xuất bản phiên bản mới"}
            </Button>
          )}
          {scene.status === "PUBLISHED" && (
            <Button
              variant="outline"
              size="sm"
              onClick={() => archive.mutate()}
              disabled={archive.isPending}
            >
              Lưu trữ cảnh
            </Button>
          )}
        </div>

        {checked && errors !== null && errors.length === 0 && (
          <p className="rounded-md border border-emerald-300 bg-emerald-50 px-3 py-2 text-xs text-emerald-800">
            Cảnh hợp lệ — sẵn sàng xuất bản.
          </p>
        )}
        {errors && errors.length > 0 && (
          <ul className="flex flex-col gap-1 rounded-md border border-error/40 bg-error/5 px-3 py-2">
            {errors.map((e, i) => (
              <li key={i} className="text-xs text-error">
                <code className="font-mono">{e.path || "(root)"}</code> — {e.message}
                <span className="ml-1 text-ink-muted">[{e.code}]</span>
              </li>
            ))}
          </ul>
        )}

        {conflict && (
          <p role="alert" className="rounded-md border border-error/40 bg-error/5 px-3 py-2 text-xs text-error">
            Đã có thay đổi khác trên máy chủ — hãy tải lại trang rồi thử lại.
          </p>
        )}
        {publish.error && !(publish.error instanceof ApiClientError) && (
          <p role="alert" className="text-xs text-error">{publish.error.message}</p>
        )}
        {archive.error && (
          <p role="alert" className="text-xs text-error">
            {archive.error instanceof ApiClientError
              ? archive.error.message
              : "Không lưu trữ được cảnh."}
          </p>
        )}
        {publish.isSuccess && (
          <p className="rounded-md border border-emerald-300 bg-emerald-50 px-3 py-2 text-xs text-emerald-800">
            Đã xuất bản phiên bản v{publish.data.versionNo}.{" "}
            <button
              type="button"
              className="underline"
              onClick={() => {
                onSaved();
                router.push(`/animations/${scene.id}/versions`);
              }}
            >
              Xem danh sách phiên bản
            </button>
          </p>
        )}
      </div>
    </Section>
  );
}
