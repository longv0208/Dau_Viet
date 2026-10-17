"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import type { UseFormReset, UseFormSetError } from "react-hook-form";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { AdminAsset, Evidence } from "@/lib/dto/evidence";
import { applyServerFieldErrors } from "@/lib/form-utils";
import { qk } from "@/lib/query-keys";

import type { EvidenceFormValues } from "./evidence-form-schema";

const SERVER_FIELDS = [
  "title",
  "evidenceType",
  "description",
  "sourceTitle",
  "sourceAuthor",
  "sourceUrl",
  "sourceCitation",
  "sourcePublishedAt",
  "relevance",
] as const;

function toPayload(v: EvidenceFormValues): Record<string, unknown> {
  return {
    title: v.title.trim(),
    evidenceType: v.evidenceType,
    description: v.description?.trim() || undefined,
    sourceTitle: v.sourceTitle.trim(),
    sourceAuthor: v.sourceAuthor?.trim() || undefined,
    sourceUrl: v.sourceUrl?.trim() || undefined,
    sourceCitation: v.sourceCitation?.trim() || undefined,
    sourcePublishedAt: v.sourcePublishedAt?.trim() || undefined,
    reliability: v.reliability || undefined,
    relevance: v.relevance?.trim() || undefined,
  };
}

function valuesFromResponse(res: Evidence): EvidenceFormValues {
  return {
    eventId: res.eventId,
    title: res.title,
    evidenceType: res.evidenceType,
    description: res.description ?? "",
    sourceTitle: res.sourceTitle,
    sourceAuthor: res.sourceAuthor ?? "",
    sourceUrl: res.sourceUrl ?? "",
    sourceCitation: res.sourceCitation ?? "",
    sourcePublishedAt: res.sourcePublishedAt ?? "",
    reliability: res.reliability ?? "",
    relevance: res.relevance ?? "",
  };
}

interface SubmitDeps {
  initial?: Evidence;
  asset: AdminAsset | null;
  assetCleared: boolean;
  reset: UseFormReset<EvidenceFormValues>;
  setError: UseFormSetError<EvidenceFormValues>;
  onSaved: () => void;
  onServerError: (msg: string) => void;
  resetAsset: () => void;
}

/** Submit handler for both POST create and PATCH edit branches. */
export function useEvidenceSubmit() {
  const router = useRouter();
  const qc = useQueryClient();

  return async function submit(v: EvidenceFormValues, deps: SubmitDeps) {
    const { initial, asset, assetCleared, reset, setError, onSaved, onServerError, resetAsset } =
      deps;
    onServerError("");
    const payload = toPayload(v);
    try {
      if (initial) {
        // PATCH contract: absent = keep, explicit null = clear. Form state is
        // authoritative for editable fields; expectedRowVersion drives
        // optimistic concurrency. clearAsset is the explicit "unset" flag —
        // JSON cannot distinguish absent from null for assetId.
        const body: Record<string, unknown> = {
          ...payload,
          expectedRowVersion: initial.rowVersion,
        };
        if (asset) {
          body.assetId = asset.id;
        } else if (assetCleared && initial.assetId) {
          body.clearAsset = true;
        }
        const res = await apiFetch<Evidence>(`/admin/evidences/${initial.id}`, {
          method: "PATCH",
          body: JSON.stringify(body),
        });
        reset(valuesFromResponse(res));
        resetAsset();
        onSaved();
        qc.invalidateQueries({ queryKey: ["evidences"] });
        qc.invalidateQueries({ queryKey: qk.evidences.detail(initial.id) });
      } else {
        const res = await apiFetch<Evidence>("/admin/evidences", {
          method: "POST",
          body: JSON.stringify({ ...payload, eventId: v.eventId, assetId: asset?.id }),
        });
        qc.invalidateQueries({ queryKey: ["evidences"] });
        router.push(`/evidence/${res.id}`);
      }
    } catch (err) {
      const mapped = applyServerFieldErrors(err, setError, SERVER_FIELDS);
      if (!mapped) onServerError(toUserMessage(err));
      if (err instanceof ApiClientError && err.isConflict) {
        onServerError(
          "Bằng chứng đã bị ai đó sửa đồng thời. Tải lại trang để lấy dữ liệu mới.",
        );
      }
    }
  };
}
