"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQuery } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";

import { apiFetch, toQuery } from "@/lib/api-client";
import { parseReturnTo } from "@/lib/return-to";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { AdminAsset, Evidence } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  confirmDiscard,
  useUnsavedChangesGuard,
} from "@/components/unsaved-changes-guard";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";

import { evidenceFormSchema, type EvidenceFormValues } from "./evidence-form-schema";
import { EvidenceBasicFields, EvidenceSourceFields } from "./evidence-form-sections";
import { EvidenceAssetField } from "./evidence-asset-field";
import { useEvidenceSubmit } from "./use-evidence-submit";

interface Props {
  /** When provided the form is in edit mode (PATCH). */
  initial?: Evidence;
}

/** Create/edit evidence. Shared between /evidence/new and /evidence/[id].
 * `?event=<uuid>` pre-fills the event when creating from a workspace;
 * `?return=<path>` redirects back after save (validated, else /evidence). */
export function EvidenceForm({ initial }: Props) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const presetEventId = searchParams.get("event") ?? "";
  const returnTo = parseReturnTo(searchParams.get("return"));
  const isEdit = Boolean(initial);
  const [serverError, setServerError] = useState<string | null>(null);
  const [savedTick, setSavedTick] = useState(false);
  const [asset, setAsset] = useState<AdminAsset | null>(null);
  const [assetCleared, setAssetCleared] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);

  const eventsQuery = useQuery({
    queryKey: qk.events.list({ size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminEventSummary>>(`/admin/events${toQuery({ size: 100 })}`),
  });

  // Load attached asset so we render a friendly name/thumbnail, never a raw UUID.
  const assetQuery = useQuery({
    queryKey: qk.assets.detail(initial?.assetId ?? "none"),
    queryFn: initial?.assetId
      ? () => apiFetch<AdminAsset>(`/admin/assets/${initial.assetId}`)
      : () => Promise.resolve(null),
    enabled: Boolean(initial?.assetId),
  });

  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors, isDirty, isSubmitting },
  } = useForm<EvidenceFormValues>({
    resolver: zodResolver(evidenceFormSchema),
    defaultValues: initial
      ? {
          eventId: initial.eventId,
          title: initial.title,
          evidenceType: initial.evidenceType,
          description: initial.description ?? "",
          sourceTitle: initial.sourceTitle,
          sourceAuthor: initial.sourceAuthor ?? "",
          sourceUrl: initial.sourceUrl ?? "",
          sourceCitation: initial.sourceCitation ?? "",
          sourcePublishedAt: initial.sourcePublishedAt ?? "",
          reliability: initial.reliability ?? "",
          relevance: initial.relevance ?? "",
        }
      : {
          eventId: presetEventId,
          title: "",
          evidenceType: "",
          description: "",
          sourceTitle: "",
          sourceAuthor: "",
          sourceUrl: "",
          sourceCitation: "",
          sourcePublishedAt: "",
          reliability: "",
          relevance: "",
        },
  });

  const submit = useEvidenceSubmit();
  const formDirty = isDirty || asset !== null || assetCleared;
  useUnsavedChangesGuard(formDirty);

  // Attached = newly picked (takes precedence) → then loaded from backend.
  const attached = asset ?? (assetCleared ? null : assetQuery.data ?? null);

  const onSubmit = handleSubmit((v) =>
    submit(v, {
      initial,
      asset,
      assetCleared,
      reset,
      setError,
      onSaved: () => {
        if (returnTo) {
          router.push(returnTo);
          return;
        }
        setSavedTick(true);
        setTimeout(() => setSavedTick(false), 3000);
      },
      onServerError: (msg) => setServerError(msg || null),
      resetAsset: () => {
        setAsset(null);
        setAssetCleared(false);
      },
    }),
  );

  return (
    <PaperCard className="p-5">
      <SectionDivider
        eyebrow="THÔNG TIN"
        title={isEdit ? "Thông tin bằng chứng lịch sử" : "Khởi tạo bằng chứng lịch sử"}
        className="mb-5"
      />
      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
        <EvidenceBasicFields
          register={register}
          errors={errors}
          isEdit={isEdit}
          events={eventsQuery.data?.content ?? []}
        />

        <EvidenceSourceFields register={register} errors={errors} />

        <div className="flex flex-col gap-1.5">
          <Label htmlFor="relevance" className="font-medium text-ink-secondary">Tầm quan trọng / lý do sử dụng</Label>
        <Textarea
          id="relevance"
          rows={2}
          placeholder="Vì sao bằng chứng này quan trọng với câu hỏi trung tâm của bài học?"
          {...register("relevance")}
        />
        {errors.relevance && (
          <p role="alert" className="text-xs text-error">{errors.relevance.message}</p>
        )}
      </div>

      <EvidenceAssetField
        attached={attached}
        onPick={() => setPickerOpen(true)}
        onClear={() => {
          setAsset(null);
          setAssetCleared(true);
        }}
      />

      {initial?.sourceTitle?.trim() === "" && (
        <p className="rounded-md bg-warning/20 px-3 py-2 text-sm text-ink">
          Nguồn chưa đầy đủ — chưa nên dùng trong bài học xuất bản.
        </p>
      )}

      {serverError && (
        <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
          {serverError}
        </p>
      )}
      {savedTick && (
        <p role="status" className="rounded-md bg-success/10 px-3 py-2 text-sm text-success">
          Đã lưu thay đổi.
        </p>
      )}

      <div className="flex items-center gap-3">
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? "Đang lưu..." : isEdit ? "Lưu thay đổi" : "Tạo bằng chứng"}
        </Button>
        <Button
          type="button"
          variant="secondary"
          onClick={() => {
            if (confirmDiscard(formDirty)) router.push(returnTo ?? "/evidence");
          }}
        >
          Huỷ
        </Button>
      </div>

      <AssetPickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        onSelect={(a) => {
          setAsset(a);
          setAssetCleared(false);
        }}
      />
      </form>
    </PaperCard>
  );
}
