"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { AdminItem, AdminItemRequest } from "@/lib/dto/item";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

const CODE_RE = /^[A-Z0-9]+(?:_[A-Z0-9]+)*$/;

const schema = z.object({
  code: z
    .string()
    .min(1, "Vui lòng nhập mã vật phẩm")
    .max(80, "Tối đa 80 ký tự")
    .regex(CODE_RE, "Mã chỉ gồm chữ HOA, số và gạch dưới (vd: MO_HINH_X)"),
  name: z.string().min(1, "Vui lòng nhập tên vật phẩm").max(160),
  description: z.string().optional().or(z.literal("")),
  category: z.string().min(1, "Vui lòng chọn nhóm").max(48),
  itemType: z.enum(["HISTORICAL_REPLICA", "DIGITAL_EDITION", "COMMEMORATIVE_BADGE"]),
  rarity: z.enum(["COMMON", "UNCOMMON", "RARE", "EPIC"]),
});

type FormValues = z.infer<typeof schema>;

/** /items/new — tạo vật phẩm catalog; rule gán sau ở trang chi tiết. */
export function ItemCreateForm() {
  const router = useRouter();
  const qc = useQueryClient();
  const [serverError, setServerError] = useState<string | null>(null);

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      code: "", name: "", description: "", category: "MO_HINH",
      itemType: "HISTORICAL_REPLICA", rarity: "COMMON",
    },
  });

  const onSubmit = form.handleSubmit(async (v) => {
    setServerError(null);
    try {
      const payload: AdminItemRequest = {
        code: v.code.trim(),
        name: v.name.trim(),
        description: v.description?.trim() || undefined,
        category: v.category,
        itemType: v.itemType,
        rarity: v.rarity,
        active: true,
      };
      const created = await apiFetch<AdminItem>("/admin/items", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      qc.invalidateQueries({ queryKey: ["items"] });
      router.push(`/items/${created.id}`);
    } catch (err) {
      setServerError(toUserMessage(err));
    }
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle>Vật phẩm mới</CardTitle>
        <CardDescription>
          Mã dùng để nhận diện trong API — không đổi sau khi tạo. Điều kiện
          mở khóa cấu hình ở trang chi tiết sau khi tạo.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
          <div className="grid gap-4 md:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="code">Mã *</Label>
              <Input id="code" placeholder="MO_HINH_TRONG_DONG"
                {...form.register("code")} />
              {form.formState.errors.code && (
                <p role="alert" className="text-xs text-error">
                  {form.formState.errors.code.message}
                </p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="name">Tên hiển thị *</Label>
              <Input id="name" placeholder="Mô hình trống đồng"
                {...form.register("name")} />
              {form.formState.errors.name && (
                <p role="alert" className="text-xs text-error">
                  {form.formState.errors.name.message}
                </p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="category">Nhóm</Label>
              <Select id="category" {...form.register("category")}>
                <option value="MO_HINH">Mô hình</option>
                <option value="PHIEN_BAN_SO">Phiên bản số</option>
                <option value="HUY_HIEU">Huy hiệu</option>
              </Select>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="itemType">Loại</Label>
              <Select id="itemType" {...form.register("itemType")}>
                <option value="HISTORICAL_REPLICA">Mô hình</option>
                <option value="DIGITAL_EDITION">Phiên bản số</option>
                <option value="COMMEMORATIVE_BADGE">Huy hiệu</option>
              </Select>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="rarity">Độ hiếm</Label>
              <Select id="rarity" {...form.register("rarity")}>
                <option value="COMMON">Thường</option>
                <option value="UNCOMMON">Không phổ biến</option>
                <option value="RARE">Hiếm</option>
                <option value="EPIC">Sử thi</option>
              </Select>
            </div>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="description">Mô tả</Label>
            <Textarea id="description" rows={3}
              placeholder="Ghi rõ là mô hình / phiên bản số / huy hiệu — không mô tả như cổ vật thật."
              {...form.register("description")} />
          </div>
          {serverError && (
            <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
              {serverError}
            </p>
          )}
          <div className="flex items-center gap-3">
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? "Đang tạo..." : "Tạo vật phẩm"}
            </Button>
            <Button type="button" variant="secondary"
              onClick={() => router.push("/items")}>
              Huỷ
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
