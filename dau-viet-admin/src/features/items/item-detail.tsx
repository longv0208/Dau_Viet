"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { AdminItem, AdminItemRequest } from "@/lib/dto/item";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";

import { RuleBuilder } from "./rule-builder/rule-builder";
import { ScopeBanner } from "./rule-builder/scope-banner";
import { RuleHistoryTable } from "./rule-history-table";

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

const itemSchema = z.object({
  name: z.string().min(1, "Vui lòng nhập tên vật phẩm").max(160),
  description: z.string().optional().or(z.literal("")),
  category: z.string().min(1, "Vui lòng nhập nhóm").max(48),
  itemType: z.enum(["HISTORICAL_REPLICA", "DIGITAL_EDITION", "COMMEMORATIVE_BADGE"]),
  rarity: z.enum(["COMMON", "UNCOMMON", "RARE", "EPIC"]),
  active: z.boolean(),
});

type ItemFormValues = z.infer<typeof itemSchema>;

/**
 * /items/[id] — sửa metadata + Rule Builder V2 (GAME-06 Module C):
 * ScopeBanner + builder 2-panel + lịch sử revision.
 */
export function ItemDetail({ itemId }: { itemId: string }) {
  const qc = useQueryClient();
  const [metaError, setMetaError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  const itemQuery = useQuery({
    queryKey: qk.items.detail(itemId),
    queryFn: () => apiFetch<AdminItem>(`/admin/items/${itemId}`),
  });

  const itemForm = useForm<ItemFormValues>({
    resolver: zodResolver(itemSchema),
    defaultValues: {
      name: "", description: "", category: "MO_HINH",
      itemType: "HISTORICAL_REPLICA", rarity: "COMMON", active: true,
    },
  });

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
            Vật phẩm đã cấp không bị thu hồi khi đổi điều kiện — lưu mới tạo
            revision mới trong lịch sử.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <ScopeBanner scope={item.scope} />
          <RuleBuilder item={item} />
        </CardContent>
      </Card>

      <RuleHistoryTable itemId={itemId} />

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
