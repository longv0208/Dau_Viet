"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQueryClient } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useFieldArray, useForm } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { AdminLessonTemplateCreateRequest, LessonTemplate } from "@/lib/dto/lesson";
import { applyServerFieldErrors, toSlug } from "@/lib/form-utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import {
  confirmDiscard,
  useUnsavedChangesGuard,
} from "@/components/unsaved-changes-guard";
import { STAGE_TYPES, type StageType } from "@/features/lessons/builder/draft-model";
import { genSlugId } from "@/features/lessons/builder/draft-id";

const CODE_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const stageSchema = z.object({
  id: z.string(),
  type: z.enum(STAGE_TYPES),
  title: z.string().min(1, "Vui lòng nhập tiêu đề giai đoạn").max(150),
});

const templateSchema = z.object({
  name: z.string().min(1, "Vui lòng nhập tên khung").max(150, "Tối đa 150 ký tự"),
  code: z
    .string()
    .min(1, "Vui lòng nhập mã khung")
    .max(64, "Tối đa 64 ký tự")
    .regex(CODE_RE, "Mã chỉ gồm chữ thường, số và dấu gạch ngang"),
  description: z.string().optional().or(z.literal("")),
  stages: z.array(stageSchema).min(1, "Cần ít nhất 1 giai đoạn"),
});

type TemplateFormValues = z.infer<typeof templateSchema>;

/** Human-readable labels per stage type (kept next to the enum order). */
const STAGE_TYPE_LABELS: Record<StageType, string> = {
  CONTEXT: "Bối cảnh",
  DISCOVERY: "Khám phá",
  EVIDENCE: "Bằng chứng",
  REASONING: "Suy luận",
  HYPOTHESIS: "Giả thuyết",
  RECONSTRUCTION: "Tái dựng",
  VERIFICATION: "Kiểm chứng",
  CONCLUSION: "Kết luận",
  REFLECTION: "Suy ngẫm",
};

function buildPresetJson(stages: TemplateFormValues["stages"]): string {
  const stageObjects = stages.map((s, i) => ({
    id: s.id,
    type: s.type,
    title: s.title.trim(),
    required: true,
    activities: [] as unknown[],
    // Linear skeleton: each stage leads to the next; last one is terminal.
    nextStageIds: i < stages.length - 1 ? [stages[i + 1]!.id] : [],
  }));
  return JSON.stringify({ schemaVersion: 1, stages: stageObjects });
}

/** Stage list editor rows work on ids + type + title; ids are auto-generated. */
function makeStage(index: number, existingIds: string[]): z.infer<typeof stageSchema> {
  return {
    id: genSlugId(`stage-${index + 1}`, existingIds),
    type: "CONTEXT",
    title: "",
  };
}

/** A-07 — /templates/new: create a lesson template without writing JSON by hand. */
export function TemplateForm() {
  const router = useRouter();
  const qc = useQueryClient();
  const searchParams = useSearchParams();
  const returnTo = searchParams.get("return");

  const [serverError, setServerError] = useState<string | null>(null);
  const [codeTouched, setCodeTouched] = useState(false);

  const {
    register,
    handleSubmit,
    control,
    watch,
    setValue,
    setError,
    formState: { errors, isDirty, isSubmitting },
  } = useForm<TemplateFormValues>({
    resolver: zodResolver(templateSchema),
    defaultValues: {
      name: "",
      code: "",
      description: "",
      stages: [
        { id: "context", type: "CONTEXT", title: "Bối cảnh lịch sử" },
        { id: "evidence", type: "EVIDENCE", title: "Điều tra bằng chứng" },
        { id: "reconstruction", type: "RECONSTRUCTION", title: "Tái dựng diễn biến" },
        { id: "conclusion", type: "CONCLUSION", title: "Lập luận và kết luận" },
      ],
    },
  });

  const stages = useFieldArray({ control, name: "stages" });
  const nameValue = watch("name");

  // Suggest a code from the name until the admin edits the field directly.
  useEffect(() => {
    if (!codeTouched) setValue("code", toSlug(nameValue).slice(0, 64), { shouldDirty: false });
  }, [nameValue, codeTouched, setValue]);

  useUnsavedChangesGuard(isDirty);

  const move = (from: number, to: number) => {
    if (to < 0 || to >= stages.fields.length) return;
    stages.move(from, to);
  };

  const onSubmit = handleSubmit(async (v) => {
    setServerError(null);
    const payload: AdminLessonTemplateCreateRequest = {
      code: v.code.trim(),
      name: v.name.trim(),
      description: v.description?.trim() || undefined,
      presetJson: buildPresetJson(v.stages),
    };
    try {
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
    } catch (err) {
      const mapped = applyServerFieldErrors(err, setError, ["name", "code", "description"] as const);
      if (!mapped) setServerError(toUserMessage(err));
    }
  });

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
      <Card>
        <CardHeader>
          <CardTitle>Thông tin khung</CardTitle>
          <CardDescription>
            Tên và mã hiển thị trong danh sách khung và bước chọn khung của wizard.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
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
                {...register("code", { onChange: () => setCodeTouched(true) })}
              />
              <p className="text-xs text-ink-muted">
                Duy nhất, chữ thường, dùng dấu gạch ngang — không đổi sau khi tạo.
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
              rows={3}
              placeholder="Mô tả ngắn về cấu trúc và mục đích của khung."
              {...register("description")}
            />
            {errors.description && (
              <p role="alert" className="text-xs text-error">{errors.description.message}</p>
            )}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Danh sách giai đoạn</CardTitle>
          <CardDescription>
            Thứ tự hiển thị là thứ tự học viên trải nghiệm. Mỗi giai đoạn tự động
            dẫn sang giai đoạn kế tiếp; giai đoạn cuối kết thúc bài học.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          {stages.fields.map((f, i) => (
            <div
              key={f.id}
              className="grid gap-2 rounded-md border border-border p-3 md:grid-cols-[auto_1fr_180px_auto] md:items-end"
            >
              <div className="flex items-center gap-1 md:flex-col md:items-stretch">
                <span className="text-xs text-ink-muted md:hidden">#{i + 1}</span>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => move(i, i - 1)}
                  disabled={i === 0}
                  aria-label={`Đưa giai đoạn ${i + 1} lên`}
                >
                  ↑
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => move(i, i + 1)}
                  disabled={i === stages.fields.length - 1}
                  aria-label={`Đưa giai đoạn ${i + 1} xuống`}
                >
                  ↓
                </Button>
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor={`stages.${i}.title`}>Tiêu đề giai đoạn {i + 1} *</Label>
                <Input
                  id={`stages.${i}.title`}
                  placeholder="Ví dụ: Bối cảnh lịch sử"
                  aria-invalid={Boolean(errors.stages?.[i]?.title)}
                  {...register(`stages.${i}.title` as const)}
                />
                {errors.stages?.[i]?.title && (
                  <p role="alert" className="text-xs text-error">
                    {errors.stages[i]?.title?.message}
                  </p>
                )}
                <p className="text-xs text-ink-muted">
                  id: <code>{watch(`stages.${i}.id`)}</code>
                </p>
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor={`stages.${i}.type`}>Loại giai đoạn</Label>
                <Select id={`stages.${i}.type`} {...register(`stages.${i}.type` as const)}>
                  {STAGE_TYPES.map((t) => (
                    <option key={t} value={t}>
                      {STAGE_TYPE_LABELS[t]} ({t})
                    </option>
                  ))}
                </Select>
              </div>
              <Button
                type="button"
                variant="secondary"
                onClick={() => stages.remove(i)}
                disabled={stages.fields.length === 1}
                aria-label={`Xoá giai đoạn ${i + 1}`}
              >
                Xoá
              </Button>
            </div>
          ))}
          <Button
            type="button"
            variant="secondary"
            className="self-start"
            onClick={() =>
              stages.append(
                makeStage(
                  stages.fields.length,
                  stages.fields.map((_, idx) => watch(`stages.${idx}.id`)),
                ),
              )
            }
          >
            + Thêm giai đoạn
          </Button>
          {typeof errors.stages?.message === "string" && (
            <p role="alert" className="text-xs text-error">{errors.stages.message}</p>
          )}
        </CardContent>
      </Card>

      {serverError && (
        <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
          {serverError}
        </p>
      )}

      <div className="flex items-center gap-3">
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? "Đang lưu..." : "Tạo khung bài học"}
        </Button>
        <Button
          type="button"
          variant="secondary"
          onClick={() => {
            if (confirmDiscard(isDirty)) router.push(returnTo ?? "/templates");
          }}
        >
          Huỷ
        </Button>
      </div>
    </form>
  );
}
