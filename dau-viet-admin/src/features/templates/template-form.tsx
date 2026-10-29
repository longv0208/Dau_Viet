"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import { parseReturnTo } from "@/lib/return-to";
import type {
  AdminLessonTemplateCreateRequest,
  AdminLessonTemplateUpdateRequest,
  LessonTemplate,
} from "@/lib/dto/lesson";
import { applyServerFieldErrors, toSlug } from "@/lib/form-utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";
import {
  confirmDiscard,
  useUnsavedChangesGuard,
} from "@/components/unsaved-changes-guard";
import { parseDraft } from "@/features/lessons/builder/draft-model";

import { TemplateDesigner } from "./template-designer";
import { TemplateStructurePreview } from "./template-structure-preview";
import {
  buildPresetJson,
  isNonLinearDraft,
  type Draft,
  type Stage,
} from "./template-catalog";

const CODE_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const templateSchema = z.object({
  name: z.string().min(1, "Vui lòng nhập tên khung").max(150, "Tối đa 150 ký tự"),
  code: z
    .string()
    .min(1, "Vui lòng nhập mã khung")
    .max(64, "Tối đa 64 ký tự")
    .regex(CODE_RE, "Mã chỉ gồm chữ thường, số và dấu gạch ngang"),
  description: z.string().optional().or(z.literal("")),
  enabled: z.boolean(),
});

type TemplateFormValues = z.infer<typeof templateSchema>;

/** Rehydrate editable stages from a stored presetJson — keeps activities,
 * unknown keys and non-linear links untouched. */
function stagesFromPreset(presetJson: string): { stages: Stage[]; draft: Draft | null } {
  try {
    const draft = parseDraft(presetJson);
    return { stages: draft.stages, draft };
  } catch {
    return { stages: [], draft: null };
  }
}

// Issue #35: preset mirrors the 4-phase learner journey (Khám phá 4 Dấu Vết
// -> Đặt giả thuyết -> Kiểm chứng -> Dựng lại -> Kết luận CER).
const DEFAULT_PRESET: Stage[] = [
  { id: "context", type: "CONTEXT", title: "Bối cảnh lịch sử", required: true, activities: [], nextStageIds: ["discovery"] },
  { id: "discovery", type: "DISCOVERY", title: "Khám phá bản đồ / dấu vết", required: true, activities: [], nextStageIds: ["evidence"] },
  { id: "evidence", type: "EVIDENCE", title: "Khám phá 4 Dấu Vết", required: true, activities: [], nextStageIds: ["hypothesis"] },
  { id: "hypothesis", type: "HYPOTHESIS", title: "Đặt giả thuyết", required: true, activities: [], nextStageIds: ["verification"] },
  { id: "verification", type: "VERIFICATION", title: "Kiểm chứng dữ kiện", required: true, activities: [], nextStageIds: ["reconstruction"] },
  { id: "reconstruction", type: "RECONSTRUCTION", title: "Dựng lại sự kiện", required: true, activities: [], nextStageIds: ["conclusion"] },
  { id: "conclusion", type: "CONCLUSION", title: "Kết luận (CER)", required: true, activities: [], nextStageIds: [] },
];

interface Props {
  /** When provided the form edits that template (PATCH); code is locked. */
  templateId?: string;
}

/**
 * /templates/new + /templates/[id] — two-panel visual designer.
 * Metadata sits in a collapsible setup block; the designer fills the
 * remaining viewport height and both panels scroll independently.
 */
export function TemplateForm({ templateId }: Props) {
  const router = useRouter();
  const qc = useQueryClient();
  const searchParams = useSearchParams();
  const returnTo = parseReturnTo(searchParams.get("return"));
  const isEdit = Boolean(templateId);

  const [serverError, setServerError] = useState<string | null>(null);
  const [codeTouched, setCodeTouched] = useState(false);
  const [setupOpen, setSetupOpen] = useState(true);
  const [previewOpen, setPreviewOpen] = useState(false);
  const [stages, setStages] = useState<Stage[]>(DEFAULT_PRESET);
  const [sourceDraft, setSourceDraft] = useState<Draft | null>(null);
  const [dirty, setDirty] = useState(false);

  const templateQuery = useQuery({
    queryKey: ["templates", "detail", templateId],
    queryFn: () => apiFetch<LessonTemplate>(`/admin/lesson-templates/${templateId}`),
    enabled: isEdit,
  });

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    setError,
    reset,
    formState: { errors, isDirty, isSubmitting },
  } = useForm<TemplateFormValues>({
    resolver: zodResolver(templateSchema),
    defaultValues: { name: "", code: "", description: "", enabled: true },
  });

  const nameValue = watch("name");

  // Populate the form once the template loads (edit mode only) — keep the
  // preset's real activities and detect non-linear graphs for read-only.
  useEffect(() => {
    const t = templateQuery.data;
    if (!t) return;
    reset({
      name: t.name,
      code: t.code,
      description: t.description ?? "",
      enabled: t.enabled,
    });
    const { stages: loaded, draft } = stagesFromPreset(t.presetJson);
    setStages(loaded.length > 0 ? loaded : DEFAULT_PRESET);
    setSourceDraft(draft && isNonLinearDraft(draft) ? draft : null);
    setDirty(false);
  }, [templateQuery.data, reset]);

  // Suggest a code from the name until the admin edits the field directly.
  useEffect(() => {
    if (!isEdit && !codeTouched) {
      setValue("code", toSlug(nameValue).slice(0, 64), { shouldDirty: false });
    }
  }, [nameValue, codeTouched, setValue, isEdit]);

  const anyDirty = isDirty || dirty;
  useUnsavedChangesGuard(anyDirty);

  const onStagesChange = (next: Stage[]) => {
    setStages(next);
    setDirty(true);
  };

  const onSubmit = handleSubmit(async (v) => {
    setServerError(null);
    const presetJson = buildPresetJson(stages);
    try {
      if (isEdit && templateId) {
        const payload: AdminLessonTemplateUpdateRequest = {
          name: v.name.trim(),
          description: v.description?.trim() || undefined,
          enabled: v.enabled,
          presetJson,
        };
        await apiFetch<LessonTemplate>(`/admin/lesson-templates/${templateId}`, {
          method: "PATCH",
          body: JSON.stringify(payload),
        });
        qc.invalidateQueries({ queryKey: ["templates"] });
        router.push(returnTo ?? "/templates");
      } else {
        const payload: AdminLessonTemplateCreateRequest = {
          code: v.code.trim(),
          name: v.name.trim(),
          description: v.description?.trim() || undefined,
          presetJson,
        };
        const res = await apiFetch<LessonTemplate>("/admin/lesson-templates", {
          method: "POST",
          body: JSON.stringify(payload),
        });
        qc.invalidateQueries({ queryKey: ["templates"] });
        // Returning from the wizard: hand the new template back so it is
        // auto-selected and the previously chosen event stays in the URL.
        if (returnTo) {
          const sep = returnTo.includes("?") ? "&" : "?";
          router.push(`${returnTo}${sep}template=${res.id}`);
        } else {
          router.push("/templates");
        }
      }
    } catch (err) {
      const mapped = applyServerFieldErrors(err, setError, ["name", "code", "description"] as const);
      if (!mapped) setServerError(toUserMessage(err));
    }
  });

  if (isEdit && templateQuery.isPending) {
    return <Skeleton className="h-96 w-full" />;
  }
  if (isEdit && templateQuery.isError) {
    return <ErrorState error={templateQuery.error} onRetry={() => templateQuery.refetch()} />;
  }

  return (
    <form
      onSubmit={onSubmit}
      noValidate
      className="flex h-[calc(100vh-13rem)] min-h-[32rem] flex-col gap-3"
    >
      {/* Collapsible setup — keeps metadata out of the panels' way. */}
      <section className="rounded-lg border border-border bg-white">
        <button
          type="button"
          onClick={() => setSetupOpen((o) => !o)}
          aria-expanded={setupOpen}
          className="flex w-full items-center justify-between px-4 py-2.5 text-left"
        >
          <span className="text-sm font-semibold text-ink">
            Thiết kế khung bài học
            {nameValue ? ` — ${nameValue}` : ""}
          </span>
          <span className="text-xs text-ink-muted">{setupOpen ? "Thu gọn ▲" : "Thông tin khung ▼"}</span>
        </button>
        {setupOpen && (
          <div className="flex flex-col gap-4 border-t border-border px-4 py-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="name">Tên khung *</Label>
                <Input
                  id="name"
                  placeholder="Điều tra sự kiện lịch sử"
                  aria-invalid={Boolean(errors.name)}
                  {...register("name")}
                />
                {errors.name && (
                  <p role="alert" className="text-xs text-error">{errors.name.message}</p>
                )}
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="code">Mã khung *</Label>
                <Input
                  id="code"
                  placeholder="dieu-tra-su-kien-lich-su"
                  aria-invalid={Boolean(errors.code)}
                  disabled={isEdit}
                  {...register("code", { onChange: () => setCodeTouched(true) })}
                />
                <p className="text-xs text-ink-muted">
                  {isEdit
                    ? "Mã dùng để nhận diện khung — không đổi sau khi tạo."
                    : "Duy nhất, chỉ gồm chữ thường không dấu, số và gạch ngang — không đổi sau khi tạo."}
                </p>
                {errors.code && (
                  <p role="alert" className="text-xs text-error">{errors.code.message}</p>
                )}
              </div>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="description">Mô tả</Label>
              <Textarea
                id="description"
                rows={2}
                placeholder="Mô tả ngắn về cấu trúc và mục đích của khung."
                {...register("description")}
              />
              {errors.description && (
                <p role="alert" className="text-xs text-error">{errors.description.message}</p>
              )}
            </div>
            {isEdit && (
              <label className="flex items-center gap-2 text-sm text-ink">
                <input type="checkbox" {...register("enabled")} />
                Khung đang bật (hiển thị khi tạo bài học)
              </label>
            )}
          </div>
        )}
      </section>

      {serverError && (
        <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
          {serverError}
        </p>
      )}

      {/* Designer fills the remaining viewport — panels scroll internally. */}
      <TemplateDesigner
        stages={stages}
        onChange={onStagesChange}
        sourceDraft={sourceDraft}
        onPreview={() => setPreviewOpen(true)}
      />

      <div className="flex items-center gap-3 border-t border-border pt-3">
        <Button type="submit" disabled={isSubmitting || stages.length === 0}>
          {isSubmitting ? "Đang lưu..." : isEdit ? "Lưu khung" : "Tạo khung bài học"}
        </Button>
        <Button
          type="button"
          variant="secondary"
          onClick={() => {
            if (confirmDiscard(anyDirty)) router.push(returnTo ?? "/templates");
          }}
        >
          Huỷ
        </Button>
        {stages.length === 0 && (
          <p className="text-xs text-ink-muted">Cần ít nhất 1 giai đoạn để lưu khung.</p>
        )}
      </div>

      <TemplateStructurePreview
        stages={stages}
        open={previewOpen}
        onClose={() => setPreviewOpen(false)}
      />
    </form>
  );
}
