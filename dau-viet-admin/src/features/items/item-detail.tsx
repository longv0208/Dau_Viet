"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type {
  AdminItem,
  AdminItemRequest,
  AdminRuleRequest,
} from "@/lib/dto/item";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";

const ITEM_TYPES = [
  { value: "HISTORICAL_REPLICA", label: "Mô hình" },
  { value: "DIGITAL_EDITION", label: "Phiên bản số" },
  { value: "COMMEMORATIVE_BADGE", label: "Huy hiệu" },
] as const;

const RARITIES = [
  { value: "COMMON", label: "Thường" },
  { value: "UNCOMMON", label: "Không phổ biến" },
  { value: "RARE", label: "Hiếm" },
  { value: "EPIC", label: "Sử thi" },
] as const;

const RULE_TYPES = [
  { value: "LESSON_COMPLETED", label: "Hoàn thành bài học cụ thể" },
  { value: "COLLECTION_COUNT", label: "Sưu tầm đủ N bằng chứng" },
  { value: "LESSON_COUNT", label: "Hoàn thành đủ N bài học" },
] as const;

const itemSchema = z.object({
  name: z.string().min(1, "Vui lòng nhập tên vật phẩm").max(160),
  description: z.string().optional().or(z.literal("")),
  category: z.string().min(1, "Vui lòng nhập nhóm").max(48),
  itemType: z.enum(["HISTORICAL_REPLICA", "DIGITAL_EDITION", "COMMEMORATIVE_BADGE"]),
  rarity: z.enum(["COMMON", "UNCOMMON", "RARE", "EPIC"]),
  active: z.boolean(),
});

const ruleSchema = z.object({
  ruleType: z.enum(["LESSON_COMPLETED", "COLLECTION_COUNT", "LESSON_COUNT"]),
  lessonId: z.string().optional().or(z.literal("")),
  threshold: z.coerce.number().int().positive().optional(),
});

type ItemFormValues = z.infer<typeof itemSchema>;
type RuleFormValues = z.infer<typeof ruleSchema>;

interface PageResponse<T> {
  content: T[];
}

/** Lessons published — dùng cho dropdown rule LESSON_COMPLETED. */
interface LessonSummary {
  id: string;
  title: string;
}

/** /items/[id] — sửa metadata + gán điều kiện mở khóa (tối thiểu). */
export function ItemDetail({ itemId }: { itemId: string }) {
  const qc = useQueryClient();
  const [metaError, setMetaError] = useState<string | null>(null);
  const [ruleError, setRuleError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  const itemQuery = useQuery({
    queryKey: qk.items.detail(itemId),
    queryFn: () => apiFetch<AdminItem>(`/admin/items/${itemId}`),
  });

  const lessonsQuery = useQuery({
    queryKey: ["lessons", "list", { status: "PUBLISHED", size: 100 }],
    queryFn: () =>
      apiFetch<PageResponse<LessonSummary>>(
        "/admin/lessons?status=PUBLISHED&size=100",
      ),
  });

  const itemForm = useForm<ItemFormValues>({
    resolver: zodResolver(itemSchema),
    defaultValues: {
      name: "", description: "", category: "MO_HINH",
      itemType: "HISTORICAL_REPLICA", rarity: "COMMON", active: true,
    },
  });

  const ruleForm = useForm<RuleFormValues>({
    resolver: zodResolver(ruleSchema),
    defaultValues: { ruleType: "COLLECTION_COUNT", lessonId: "", threshold: 1 },
  });
  const ruleType = ruleForm.watch("ruleType");

  useEffect(() => {
    const item = itemQuery.data;
    if (!item) return;
    itemForm.reset({
      name: item.name,
      description: item.description ?? "",
      category: item.category,
      itemType: item.itemType,
      rarity: item.rarity,
      active: item.active,
    });
    if (item.rule) {
      ruleForm.reset({
        ruleType: item.rule.ruleType,
        lessonId: item.rule.lessonId ?? "",
        threshold: item.rule.threshold ?? undefined,
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [itemQuery.data]);

  const saveItem = itemForm.handleSubmit(async (v) => {
    setMetaError(null);
    setSaved(false);
    try {
      const payload: AdminItemRequest = {
        code: itemQuery.data?.code ?? "",
        name: v.name.trim(),
        description: v.description?.trim() || undefined,
        category: v.category.trim(),
        itemType: v.itemType,
        rarity: v.rarity,
        active: v.active,
      };
      await apiFetch<AdminItem>(`/admin/items/${itemId}`, {
        method: "PUT",
        body: JSON.stringify(payload),
      });
      qc.invalidateQueries({ queryKey: qk.items.detail(itemId) });
      qc.invalidateQueries({ queryKey: ["items"] });
      setSaved(true);
    } catch (err) {
      setMetaError(toUserMessage(err));
    }
  });

  const saveRule = ruleForm.handleSubmit(async (v) => {
    setRuleError(null);
    setSaved(false);
    try {
      if (v.ruleType === "LESSON_COMPLETED" && !v.lessonId) {
        setRuleError("Chọn bài học cho điều kiện hoàn thành.");
        return;
      }
      if (v.ruleType !== "LESSON_COMPLETED" && !v.threshold) {
        setRuleError("Nhập ngưỡng cho điều kiện đếm.");
        return;
      }
      const payload: AdminRuleRequest = {
        ruleType: v.ruleType,
        lessonId: v.ruleType === "LESSON_COMPLETED" ? v.lessonId : null,
        threshold: v.ruleType === "LESSON_COMPLETED" ? null : v.threshold ?? null,
        active: true,
      };
      await apiFetch<AdminItem>(`/admin/items/${itemId}/rule`, {
        method: "PUT",
        body: JSON.stringify(payload),
      });
      qc.invalidateQueries({ queryKey: qk.items.detail(itemId) });
      setSaved(true);
    } catch (err) {
      setRuleError(toUserMessage(err));
    }
  });

  if (itemQuery.isPending) return <Skeleton className="h-96 w-full" />;
  if (itemQuery.isError) {
    return <ErrorState error={itemQuery.error} onRetry={() => itemQuery.refetch()} />;
  }
  const item = itemQuery.data;

  return (
    <div className="flex flex-col gap-5">
      <Card>
        <CardHeader>
          <CardTitle>{item.name}</CardTitle>
          <CardDescription>
            Mã <code className="text-xs">{item.code}</code> — không đổi sau khi tạo.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={saveItem} noValidate className="flex flex-col gap-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="name">Tên hiển thị *</Label>
                <Input id="name" {...itemForm.register("name")} />
                {itemForm.formState.errors.name && (
                  <p role="alert" className="text-xs text-error">
                    {itemForm.formState.errors.name.message}
                  </p>
                )}
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="category">Nhóm</Label>
                <Select id="category" {...itemForm.register("category")}>
                  <option value="MO_HINH">Mô hình</option>
                  <option value="PHIEN_BAN_SO">Phiên bản số</option>
                  <option value="HUY_HIEU">Huy hiệu</option>
                </Select>
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="itemType">Loại vật phẩm</Label>
                <Select id="itemType" {...itemForm.register("itemType")}>
                  {ITEM_TYPES.map((t) => (
                    <option key={t.value} value={t.value}>{t.label}</option>
                  ))}
                </Select>
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="rarity">Độ hiếm</Label>
                <Select id="rarity" {...itemForm.register("rarity")}>
                  {RARITIES.map((r) => (
                    <option key={r.value} value={r.value}>{r.label}</option>
                  ))}
                </Select>
              </div>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="description">Mô tả</Label>
              <Textarea id="description" rows={3}
                placeholder="Luôn ghi rõ là mô hình / phiên bản số / huy hiệu kỷ niệm — không mô tả như cổ vật thật."
                {...itemForm.register("description")} />
            </div>
            <label className="flex items-center gap-2 text-sm text-ink">
              <input type="checkbox" {...itemForm.register("active")} />
              Hiển thị trong catalog của học viên
            </label>
            {/* assetId + sourceMetadata giữ nguyên khi sửa metadata —
                hiển thị read-only để admin biết liên kết hiện tại, đổi
                qua API nếu cần (không CMS media đầy đủ ở MVP). */}
            {(item.assetId || item.sourceMetadata) && (
              <div className="rounded-md border border-outline-variant bg-surface-subtle px-3 py-2 text-xs text-ink-muted">
                {item.assetId && (
                  <p>Ảnh: <code>{item.assetId}</code></p>
                )}
                {item.sourceMetadata && (
                  <p className="mt-1">
                    Nguồn tham chiếu:{" "}
                    <code>{JSON.stringify(item.sourceMetadata)}</code>
                  </p>
                )}
              </div>
            )}
            {metaError && (
              <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
                {metaError}
              </p>
            )}
            <div>
              <Button type="submit" disabled={itemForm.formState.isSubmitting}>
                {itemForm.formState.isSubmitting ? "Đang lưu..." : "Lưu vật phẩm"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Điều kiện mở khóa</CardTitle>
          <CardDescription>
            Server đánh giá lúc hoàn thành bài học và sau khi sưu tầm bằng chứng.
            Vật phẩm đã cấp không bị thu hồi khi đổi điều kiện.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={saveRule} noValidate className="flex flex-col gap-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="ruleType">Loại điều kiện</Label>
                <Select id="ruleType" {...ruleForm.register("ruleType")}>
                  {RULE_TYPES.map((t) => (
                    <option key={t.value} value={t.value}>{t.label}</option>
                  ))}
                </Select>
              </div>
              {ruleType === "LESSON_COMPLETED" ? (
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="lessonId">Bài học *</Label>
                  <Select id="lessonId" {...ruleForm.register("lessonId")}>
                    <option value="">— Chọn bài học đã xuất bản —</option>
                    {(lessonsQuery.data?.content ?? []).map((l) => (
                      <option key={l.id} value={l.id}>{l.title}</option>
                    ))}
                  </Select>
                </div>
              ) : (
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="threshold">Ngưỡng *</Label>
                  <Input id="threshold" type="number" min={1}
                    {...ruleForm.register("threshold")} />
                  {ruleForm.formState.errors.threshold && (
                    <p role="alert" className="text-xs text-error">
                      Nhập số nguyên dương.
                    </p>
                  )}
                </div>
              )}
            </div>
            {ruleError && (
              <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
                {ruleError}
              </p>
            )}
            <div className="flex items-center gap-3">
              <Button type="submit" disabled={ruleForm.formState.isSubmitting}>
                {ruleForm.formState.isSubmitting ? "Đang lưu..." : "Lưu điều kiện"}
              </Button>
              {item.rule && (
                <p className="text-xs text-ink-muted">
                  Hiện tại: {RULE_TYPES.find((t) => t.value === item.rule?.ruleType)?.label}
                  {item.rule.threshold != null ? ` ≥ ${item.rule.threshold}` : ""}
                </p>
              )}
            </div>
          </form>
        </CardContent>
      </Card>

      {saved && (
        <p className="rounded-md bg-success/15 px-3 py-2 text-sm text-ink">
          Đã lưu. Học viên đã sở hữu vật phẩm này không bị ảnh hưởng.
        </p>
      )}
      <p className="text-sm">
        <Link href="/items" className="text-primary hover:underline">
          ← Về danh sách vật phẩm
        </Link>
      </p>
    </div>
  );
}
