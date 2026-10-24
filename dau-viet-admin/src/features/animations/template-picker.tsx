"use client";

import { useMutation, useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { qk } from "@/lib/query-keys";
import { ApiClientError } from "@/lib/api-error";

import { animationApi } from "./animation-api";
import { RENDERER_CODES, emptyManifest, type AnimationTemplateDto } from "./animation-types";

const RENDERER_LABELS: Record<string, string> = {
  RIVER_TIDE: "Sông & thủy triều",
  JOURNEY_MAP: "Hành trình bản đồ",
  HTML_WEBVIEW: "Hoạt họa HTML",
};

const RENDERER_DESCRIPTIONS: Record<string, string> = {
  RIVER_TIDE: "Cảnh sông có mực nước lên xuống, vật cản ngầm và thuyền di chuyển — phù hợp trận thủy chiến.",
  JOURNEY_MAP: "Bản đồ schematic với địa điểm, tuyến di chuyển và marker tương tác — phù hợp hành trình, dời đô.",
};

/**
 * Screen B — Chọn kiểu cảnh: chỉ hiển thị template enabled và có
 * rendererCode mà app học viên hỗ trợ (RIVER_TIDE / JOURNEY_MAP).
 */
export function TemplatePicker() {
  const router = useRouter();
  const [selected, setSelected] = useState<AnimationTemplateDto | null>(null);
  const [title, setTitle] = useState("");

  const templates = useQuery({
    queryKey: qk.animationTemplates.list({ enabled: true }),
    queryFn: () => animationApi.listTemplates({ enabled: true, size: 100 }),
    select: (page) =>
      page.content.filter(
        (t) =>
          (RENDERER_CODES as readonly string[]).includes(t.rendererCode) &&
          // HTML_WEBVIEW không qua luồng "tạo cảnh rỗng" — scene được sinh ra
          // từ file tải lên (nút "Tải hoạt họa HTML lên" trong thư viện).
          t.rendererCode !== "HTML_WEBVIEW",
      ),
  });

  const create = useMutation({
    mutationFn: (input: { templateId: string; title: string; draftJson: string }) =>
      animationApi.createScene(input),
    onSuccess: (scene) => router.push(`/animations/${scene.id}/edit`),
  });

  const onCreate = () => {
    if (!selected || !title.trim()) return;
    create.mutate({
      templateId: selected.id,
      title: title.trim(),
      draftJson: JSON.stringify(
        emptyManifest(selected.rendererCode, selected.rendererVersion),
      ),
    });
  };

  if (templates.isPending) {
    return <p className="text-sm text-ink-muted">Đang tải kiểu cảnh…</p>;
  }
  if (templates.error) {
    return (
      <p role="alert" className="text-sm text-error">
        Không tải được danh sách kiểu cảnh.
      </p>
    );
  }

  return (
    <div className="flex max-w-3xl flex-col gap-6">
      <div className="grid gap-3 sm:grid-cols-2">
        {(templates.data ?? []).map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setSelected(t)}
            aria-pressed={selected?.id === t.id}
            className={`flex flex-col gap-1 rounded-lg border p-4 text-left transition-colors ${
              selected?.id === t.id
                ? "border-brand bg-brand/5"
                : "border-border bg-white hover:border-brand/50"
            }`}
          >
            <span className="text-sm font-semibold text-ink">
              {RENDERER_LABELS[t.rendererCode] ?? t.name}
            </span>
            <span className="text-xs text-ink-muted">
              {t.description || RENDERER_DESCRIPTIONS[t.rendererCode] || ""}
            </span>
            <span className="mt-1 inline-flex w-fit rounded bg-surface-alt px-2 py-0.5 text-[11px] font-mono text-ink-muted">
              {t.rendererCode}
            </span>
          </button>
        ))}
        {(templates.data ?? []).length === 0 && (
          <p className="text-sm text-ink-muted">
            Chưa có kiểu cảnh nào khả dụng — cần seed animation_templates
            trên backend trước.
          </p>
        )}
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="scene-title">Tên cảnh</Label>
        <Input
          id="scene-title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="VD: Trận Bạch Đằng năm 938"
        />
      </div>

      {create.error instanceof ApiClientError && (
        <p role="alert" className="text-sm text-error">
          {create.error.message}
        </p>
      )}

      <div>
        <Button
          onClick={onCreate}
          disabled={!selected || !title.trim() || create.isPending}
        >
          {create.isPending ? "Đang tạo…" : "Tạo và mở trình soạn"}
        </Button>
      </div>
    </div>
  );
}
