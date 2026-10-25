"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation } from "@tanstack/react-query";

import { apiFetch } from "@/lib/api-client";
import type {
  AdminDossierCreate,
  AdminDossierDetail,
  DossierSource,
  DossierType,
} from "@/lib/dto/gamification";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { ErrorState } from "@/components/error-state";

import { DossierSourceFields } from "./dossier-source-fields";

const CANONICAL_RE = /^[a-z0-9][a-z0-9-]{1,119}$/;

const TYPE_LABELS: Record<DossierType, string> = {
  PERSON: "Nhân vật",
  LOCATION: "Địa điểm",
  ARTIFACT: "Hiện vật",
  CONTEXT: "Bối cảnh",
};

/** Form tao dossier — canonicalCode immutable sau khi tao. */
export function DossierCreateForm() {
  const router = useRouter();
  const [canonicalCode, setCanonicalCode] = useState("");
  const [dossierType, setDossierType] = useState<DossierType>("PERSON");
  const [title, setTitle] = useState("");
  const [summary, setSummary] = useState("");
  const [description, setDescription] = useState("");
  const [source, setSource] = useState<DossierSource>({ title: "" });
  const [codeError, setCodeError] = useState<string | null>(null);

  const create = useMutation({
    mutationFn: (req: AdminDossierCreate) =>
      apiFetch<AdminDossierDetail>(`/admin/dossiers`, {
        method: "POST",
        body: JSON.stringify(req),
      }),
    onSuccess: (d) => router.replace(`/dossiers/${d.id}`),
  });

  const submit = () => {
    if (!CANONICAL_RE.test(canonicalCode)) {
      setCodeError("Mã phải là kebab-case thường (a-z, 0-9, -), tối thiểu 2 ký tự.");
      return;
    }
    setCodeError(null);
    const src =
      source.title.trim() === ""
        ? null
        : {
            title: source.title,
            author: source.author || null,
            citation: source.citation || null,
            url: source.url || null,
            reliability: source.reliability || null,
          };
    create.mutate({
      canonicalCode,
      dossierType,
      title,
      summary: summary || null,
      description: description || null,
      source: src,
    });
  };

  return (
    <div className="flex max-w-3xl flex-col gap-4">
      {create.isError && <ErrorState error={create.error} />}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div>
          <Label htmlFor="code">Mã canonical *</Label>
          <Input
            id="code"
            value={canonicalCode}
            onChange={(e) => setCanonicalCode(e.target.value)}
            placeholder="ngo-quyen"
            aria-invalid={codeError != null}
          />
          {codeError && <p className="mt-1 text-xs text-error">{codeError}</p>}
          <p className="mt-1 text-xs text-ink-muted">
            Khóa duy nhất toàn hệ thống — không đổi được sau khi tạo.
          </p>
        </div>
        <div>
          <Label htmlFor="type">Loại *</Label>
          <Select
            id="type"
            value={dossierType}
            onChange={(e) => setDossierType(e.target.value as DossierType)}
          >
            {Object.entries(TYPE_LABELS).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </Select>
        </div>
      </div>

      <div>
        <Label htmlFor="title">Tiêu đề *</Label>
        <Input
          id="title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />
      </div>
      <div>
        <Label htmlFor="summary">Tóm tắt</Label>
        <Textarea
          id="summary"
          rows={2}
          value={summary}
          onChange={(e) => setSummary(e.target.value)}
        />
      </div>
      <div>
        <Label htmlFor="desc">Mô tả chi tiết</Label>
        <Textarea
          id="desc"
          rows={5}
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
      </div>

      <DossierSourceFields value={source} onChange={setSource} />

      <div className="flex gap-2">
        <Button
          disabled={create.isPending || !title.trim() || !canonicalCode.trim()}
          onClick={submit}
        >
          {create.isPending ? "Đang tạo…" : "Tạo hồ sơ"}
        </Button>
      </div>
    </div>
  );
}
