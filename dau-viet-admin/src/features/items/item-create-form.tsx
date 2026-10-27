"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
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

const CODE_RE = /^[A-Za-z0-9]+(?:_[A-Za-z0-9]+)*$/;

const RENDER_KEY_SUGGESTIONS = [
  "decor.cay_da",
  "decor.nha_tranh",
  "decor.ho_sen",
  "decor.cau_kieu",
  "decor.bui_tre",
  "decor.gieng_co",
  "decor.cong_lang",
  "decor.den_long_hoi_an",
  "decor.dinh_lang",
  "decor.thuyen_rong",
  "decor.thap_but",
  "decor.khue_van_cac",
];

const schema = z.object({
  code: z
    .string()
    .min(1, "Vui lòng nhập mã vật phẩm")
    .max(80, "Tối đa 80 ký tự")
    .regex(CODE_RE, "Mã chỉ gồm chữ cái, số và gạch dưới (vd: DECOR_DEN_LONG hoặc decor_den_long)"),
  name: z.string().min(1, "Vui lòng nhập tên vật phẩm").max(160),
  description: z.string().optional().or(z.literal("")),
  category: z.string().min(1, "Vui lòng chọn nhóm").max(48),
  itemType: z.enum(["HISTORICAL_REPLICA", "DIGITAL_EDITION", "COMMEMORATIVE_BADGE", "DECOR"]),
  rarity: z.enum(["COMMON", "UNCOMMON", "RARE", "EPIC"]),
  placeable: z.boolean(),
  renderKey: z.string().max(120).optional().or(z.literal("")),
  assetId: z.string().optional().or(z.literal("")),
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
      code: "",
      name: "",
      description: "",
      category: "DECOR",
      itemType: "DECOR",
      rarity: "COMMON",
      placeable: true,
      renderKey: "",
      assetId: "",
    },
  });

  const watchedItemType = form.watch("itemType");
  const isNonPlaceableType =
    watchedItemType === "DIGITAL_EDITION" || watchedItemType === "COMMEMORATIVE_BADGE";

  useEffect(() => {
    if (watchedItemType === "DECOR") {
      form.setValue("placeable", true);
      if (form.getValues("category") !== "DECOR") {
        form.setValue("category", "DECOR");
      }
    } else if (isNonPlaceableType) {
      form.setValue("placeable", false);
    }
  }, [watchedItemType, isNonPlaceableType, form]);

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
        placeable: isNonPlaceableType ? false : v.placeable,
        renderKey: v.renderKey?.trim() || null,
        assetId: v.assetId?.trim() || null,
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
          Mã dùng để nhận diện trong API — không đổi sau khi tạo. Vật phẩm có{" "}
          <code>placeable = true</code> có thể đưa lên Cửa hàng Đảo Di Sản và đặt vào ô trên đảo.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
          <div className="grid gap-4 md:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="code">Mã *</Label>
              <Input
                id="code"
                placeholder="decor_dinh_lang hoặc MO_HINH_TRONG_DONG"
                {...form.register("code")}
              />
              {form.formState.errors.code && (
                <p role="alert" className="text-xs text-error">
                  {form.formState.errors.code.message}
                </p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="name">Tên hiển thị *</Label>
              <Input
                id="name"
                placeholder="Đình Làng Mái Đao"
                {...form.register("name")}
              />
              {form.formState.errors.name && (
                <p role="alert" className="text-xs text-error">
                  {form.formState.errors.name.message}
                </p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="category">Nhóm (Category)</Label>
              <Select id="category" {...form.register("category")}>
                <option value="DECOR">Trang trí Đảo Di Sản (DECOR)</option>
                <option value="MO_HINH">Mô hình (MO_HINH)</option>
                <option value="PHIEN_BAN_SO">Phiên bản số (PHIEN_BAN_SO)</option>
                <option value="HUY_HIEU">Huy hiệu (HUY_HIEU)</option>
              </Select>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="itemType">Loại vật phẩm (Item Type)</Label>
              <Select id="itemType" {...form.register("itemType")}>
                <option value="DECOR">Trang trí Đảo Di Sản (DECOR)</option>
                <option value="HISTORICAL_REPLICA">Mô hình (HISTORICAL_REPLICA)</option>
                <option value="DIGITAL_EDITION">Phiên bản số (DIGITAL_EDITION)</option>
                <option value="COMMEMORATIVE_BADGE">Huy hiệu (COMMEMORATIVE_BADGE)</option>
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
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="renderKey">Render Key (Artwork / Sprite Key)</Label>
              <Input
                id="renderKey"
                list="render-key-suggestions"
                placeholder="vd: decor.dinh_lang"
                {...form.register("renderKey")}
              />
              <datalist id="render-key-suggestions">
                {RENDER_KEY_SUGGESTIONS.map((rk) => (
                  <option key={rk} value={rk} />
                ))}
              </datalist>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="assetId">Asset UUID (tùy chọn)</Label>
              <Input
                id="assetId"
                placeholder="UUID media asset nếu có"
                {...form.register("assetId")}
              />
            </div>
            <div className="flex flex-col justify-center gap-1.5 pt-4">
              <label className="flex items-center gap-2 text-sm font-medium text-ink">
                <input
                  type="checkbox"
                  disabled={isNonPlaceableType}
                  {...form.register("placeable")}
                />
                Có thể đặt lên Đảo Di Sản (placeable)
              </label>
              {isNonPlaceableType && (
                <p className="text-xs text-ink-muted">
                  Phiên bản số và Huy hiệu không thể đặt lên đảo.
                </p>
              )}
            </div>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="description">Mô tả</Label>
            <Textarea
              id="description"
              rows={3}
              placeholder="Ghi rõ là vật phẩm trang trí đảo / mô hình / phiên bản số / huy hiệu — không mô tả như cổ vật thật."
              {...form.register("description")}
            />
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
            <Button
              type="button"
              variant="secondary"
              onClick={() => router.push("/items")}
            >
              Huỷ
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
