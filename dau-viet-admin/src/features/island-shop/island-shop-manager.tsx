"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useMemo, useState } from "react";
import { Eye, Pencil, Plus, Sparkles, Store, Trash2 } from "lucide-react";

import { apiFetch, toQuery } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { AdminItem } from "@/lib/dto/item";
import { ClueTag } from "@/components/atoms/clue-tag";
import { EmptyStateCard } from "@/components/atoms/empty-state-card";
import { PaperCard } from "@/components/atoms/paper-card";
import { RareFrame, type RarityTier } from "@/components/atoms/rare-frame";
import { SectionDivider } from "@/components/atoms/section-divider";
import { SectionEyebrow } from "@/components/atoms/section-eyebrow";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";

import {
  islandShopApi,
  type AdminIslandShopOfferDto,
  type CreateShopOfferRequest,
  type UpdateShopOfferRequest,
} from "./island-shop-api";

interface PageResponse<T> {
  content: T[];
  totalElements: number;
}

const RARITY_LABELS: Record<string, string> = {
  COMMON: "Thường",
  UNCOMMON: "Không phổ biến",
  RARE: "Hiếm",
  EPIC: "Sử thi",
};

const RARITY_BADGE_CLASSES: Record<string, string> = {
  COMMON: "bg-surface-alt text-ink-muted",
  UNCOMMON: "bg-emerald-100 text-emerald-800",
  RARE: "bg-blue-100 text-blue-800",
  EPIC: "bg-purple-100 text-purple-800",
};

const TYPE_LABELS: Record<string, string> = {
  DECOR: "Trang trí Đảo",
  HISTORICAL_REPLICA: "Mô hình",
  DIGITAL_EDITION: "Phiên bản số",
  COMMEMORATIVE_BADGE: "Huy hiệu",
};

export function IslandShopManager() {
  const qc = useQueryClient();
  const [actionError, setActionError] = useState<string | null>(null);
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);

  const [addModalOpen, setAddModalOpen] = useState(false);
  const [selectedItemId, setSelectedItemId] = useState("");
  const [newPrice, setNewPrice] = useState("150");
  const [newActive, setNewActive] = useState(true);
  const [newSortOrder, setNewSortOrder] = useState("10");

  const [editingOffer, setEditingOffer] = useState<AdminIslandShopOfferDto | null>(null);
  const [editPrice, setEditPrice] = useState("");
  const [editUnpriced, setEditUnpriced] = useState(false);
  const [editActive, setEditActive] = useState(true);
  const [editSortOrder, setEditSortOrder] = useState("0");

  const [previewOffer, setPreviewOffer] = useState<AdminIslandShopOfferDto | null>(null);

  const offersQuery = useQuery({
    queryKey: ["island-shop", "offers"],
    queryFn: () => islandShopApi.listOffers(),
  });

  const catalogQuery = useQuery({
    queryKey: ["items", "list-all-for-shop"],
    queryFn: () =>
      apiFetch<PageResponse<AdminItem>>(`/admin/items${toQuery({ size: 100 })}`),
  });

  const existingItemIds = useMemo(() => {
    return new Set((offersQuery.data ?? []).map((o) => o.itemId));
  }, [offersQuery.data]);

  const eligibleCatalogItems = useMemo(() => {
    const all = catalogQuery.data?.content ?? [];
    return all.filter(
      (it) =>
        it.active &&
        Boolean(it.placeable) &&
        it.itemType !== "DIGITAL_EDITION" &&
        it.itemType !== "COMMEMORATIVE_BADGE" &&
        !existingItemIds.has(it.id),
    );
  }, [catalogQuery.data, existingItemIds]);

  const createMutation = useMutation({
    mutationFn: (req: CreateShopOfferRequest) => islandShopApi.createOffer(req),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["island-shop"] });
      setAddModalOpen(false);
      setActionError(null);
      setActionSuccess("Đã đưa vật phẩm lên Cửa hàng Đảo Di Sản.");
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const updateMutation = useMutation({
    mutationFn: ({ itemId, req }: { itemId: string; req: UpdateShopOfferRequest }) =>
      islandShopApi.updateOffer(itemId, req),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["island-shop"] });
      setEditingOffer(null);
      setActionError(null);
      setActionSuccess("Đã cập nhật cấu hình bán hàng.");
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const removeMutation = useMutation({
    mutationFn: (itemId: string) => islandShopApi.removeOffer(itemId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["island-shop"] });
      setActionError(null);
      setActionSuccess("Đã gỡ vật phẩm khỏi Cửa hàng Đảo Di Sản (không xóa kho học viên).");
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const openAddModal = () => {
    setActionError(null);
    setActionSuccess(null);
    const first = eligibleCatalogItems[0];
    setSelectedItemId(first?.id ?? "");
    setNewPrice("150");
    setNewActive(true);
    setNewSortOrder(String(((offersQuery.data?.length ?? 0) + 1) * 10));
    setAddModalOpen(true);
  };

  const openEditModal = (offer: AdminIslandShopOfferDto) => {
    setActionError(null);
    setActionSuccess(null);
    setEditingOffer(offer);
    setEditUnpriced(offer.pricePoints == null);
    setEditPrice(offer.pricePoints != null ? String(offer.pricePoints) : "");
    setEditActive(offer.active);
    setEditSortOrder(String(offer.sortOrder));
  };

  const handleCreateSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedItemId) {
      setActionError("Vui lòng chọn vật phẩm từ catalog.");
      return;
    }
    const parsedPrice = newPrice.trim() ? Number(newPrice.trim()) : null;
    if (parsedPrice != null && (Number.isNaN(parsedPrice) || parsedPrice <= 0)) {
      setActionError("Giá Điểm Sử Ký phải lớn hơn 0 (hoặc để trống nếu chưa mở bán).");
      return;
    }
    const parsedSort = Number(newSortOrder) || 0;
    createMutation.mutate({
      itemId: selectedItemId,
      pricePoints: parsedPrice,
      active: parsedPrice == null ? false : newActive,
      sortOrder: parsedSort,
    });
  };

  const handleUpdateSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingOffer) return;
    let parsedPrice: number | null = null;
    if (!editUnpriced && editPrice.trim() !== "") {
      parsedPrice = Number(editPrice.trim());
      if (Number.isNaN(parsedPrice) || parsedPrice <= 0) {
        setActionError("Giá Điểm Sử Ký phải lớn hơn 0.");
        return;
      }
    }
    const parsedSort = Number(editSortOrder) || 0;
    updateMutation.mutate({
      itemId: editingOffer.itemId,
      req: {
        pricePoints: editUnpriced ? null : parsedPrice,
        clearPrice: editUnpriced,
        active: editUnpriced || parsedPrice == null ? false : editActive,
        sortOrder: parsedSort,
      },
    });
  };

  if (offersQuery.isPending) return <Skeleton className="h-96 w-full" />;
  if (offersQuery.isError) {
    return <ErrorState error={offersQuery.error} onRetry={() => offersQuery.refetch()} />;
  }

  const offers = offersQuery.data ?? [];

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="mb-1.5">
            <SectionEyebrow color="gold">QUẢN TRỊ · CỬA HÀNG ĐẢO DI SẢN</SectionEyebrow>
          </div>
          <h1 className="font-display text-2xl font-bold text-ink">
            Cửa hàng Đảo Di Sản
          </h1>
          <p className="text-sm text-ink-muted">
            Quản lý danh sách vật phẩm mở bán bằng Điểm Sử Ký trên Đảo Di Sản. Gỡ khỏi cửa hàng không làm mất vật phẩm học viên đã sở hữu.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Link href="/items/new">
            <Button variant="secondary" type="button">
              + Tạo vật phẩm Catalog
            </Button>
          </Link>
          <Button type="button" onClick={openAddModal}>
            <Plus className="mr-1.5 size-4" />
            Đưa vật phẩm lên Shop
          </Button>
        </div>
      </div>

      {actionError && (
        <div role="alert" className="rounded-md bg-error/10 px-4 py-3 text-sm text-error">
          {actionError}
        </div>
      )}
      {actionSuccess && (
        <div className="rounded-md bg-success/15 px-4 py-3 text-sm text-ink">
          {actionSuccess}
        </div>
      )}

      <PaperCard className="p-5">
        <SectionDivider
          eyebrow="CỬA HÀNG"
          eyebrowColor="gold"
          title={`Danh sách vật phẩm trong Shop (${offers.length})`}
          description={
            <>
              Chỉ những vật phẩm có <code>purchasable = true</code> (đang bật bán, có giá &gt; 0, có <code>placeable = true</code> và đang hiển thị trong Catalog) mới cho phép học viên mua trên ứng dụng.
            </>
          }
          className="mb-4"
        />
        <div>
          {offers.length === 0 ? (
            <EmptyStateCard
              icon={Store}
              title="Chưa có vật phẩm nào trong Cửa hàng Đảo Di Sản"
              description="Nhấn “Đưa vật phẩm lên Shop” để chọn vật phẩm trang trí từ Catalog."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-sm">
                <thead>
                  <tr className="border-b-2 border-heading bg-surface-alt font-sans text-xs font-bold uppercase tracking-wider text-ink-secondary">
                    <th className="py-3 pr-3">Thứ tự</th>
                    <th className="px-3 py-3">Artwork / Render Key</th>
                    <th className="px-3 py-3">Vật phẩm</th>
                    <th className="px-3 py-3">Loại &amp; Độ hiếm</th>
                    <th className="px-3 py-3">Giá (Điểm Sử Ký)</th>
                    <th className="px-3 py-3">Trạng thái bán</th>
                    <th className="py-3 pl-3 text-right">Thao tác</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {offers.map((offer) => {
                    const isPurchasable = offer.purchasable;
                    return (
                      <tr key={offer.itemId} className="hover:bg-surface-alt/50">
                        <td className="py-3 pr-3 font-mono text-xs text-ink-muted">
                          #{offer.sortOrder}
                        </td>
                        <td className="px-3 py-3">
                          <div className="flex items-center gap-2.5">
                            <RareFrame
                              rarity={(offer.rarity?.toLowerCase() as RarityTier) ?? "common"}
                              className="relative flex size-10 shrink-0 items-center justify-center overflow-hidden p-1"
                            >
                              {offer.assetId ? (
                                // eslint-disable-next-line @next/next/no-img-element
                                <img
                                  src={`/api/proxy/assets/${offer.assetId}/content`}
                                  alt={offer.name}
                                  className="size-full object-contain"
                                />
                              ) : (
                                <Sparkles className="size-5 text-gold-dark" />
                              )}
                            </RareFrame>
                            <div className="min-w-0">
                              <code className="block truncate text-xs font-medium text-ink">
                                {offer.renderKey ?? "Chưa gán renderKey"}
                              </code>
                              {offer.assetId && (
                                <span className="block truncate text-[11px] text-ink-muted">
                                  Asset: {offer.assetId.slice(0, 8)}…
                                </span>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="px-3 py-3">
                          <Link
                            href={`/items/${offer.itemId}`}
                            className="font-medium text-brand hover:underline"
                          >
                            {offer.name}
                          </Link>
                          <div className="text-xs text-ink-muted">
                            <code>{offer.code}</code>
                          </div>
                        </td>
                        <td className="px-3 py-3">
                          <div className="flex flex-col gap-1">
                            <span className="text-xs text-ink">
                              {TYPE_LABELS[offer.itemType] ?? offer.itemType}
                            </span>
                            <span
                              className={`inline-flex w-fit items-center rounded-full px-2 py-0.5 text-[11px] font-medium ${
                                RARITY_BADGE_CLASSES[offer.rarity] ?? "bg-surface-alt text-ink-muted"
                              }`}
                            >
                              {RARITY_LABELS[offer.rarity] ?? offer.rarity}
                            </span>
                          </div>
                        </td>
                        <td className="px-3 py-3">
                          {offer.pricePoints != null && offer.pricePoints > 0 ? (
                            <span className="font-semibold text-amber-800">
                              {offer.pricePoints.toLocaleString("vi-VN")} Điểm Sử Ký
                            </span>
                          ) : (
                            <span className="text-xs italic text-ink-muted">
                              Chưa định giá
                            </span>
                          )}
                        </td>
                        <td className="px-3 py-3">
                          <div className="flex flex-col gap-1">
                            <ClueTag
                              label={
                                isPurchasable
                                  ? "Đang mở bán"
                                  : offer.pricePoints == null
                                    ? "Chưa mở bán"
                                    : !offer.active
                                      ? "Tạm dừng bán"
                                      : "Không đủ điều kiện bán"
                              }
                              color={isPurchasable ? "jade" : "gold"}
                              className="w-fit"
                            />
                            {(!offer.catalogActive || !offer.placeable) && (
                              <span className="text-[11px] text-error">
                                {!offer.catalogActive
                                  ? "Catalog đang ẩn"
                                  : "Catalog placeable=false"}
                              </span>
                            )}
                          </div>
                        </td>
                        <td className="py-3 pl-3 text-right">
                          <div className="inline-flex items-center gap-1.5">
                            <Button
                              type="button"
                              variant="secondary"
                              onClick={() => setPreviewOffer(offer)}
                              title="Xem trước hiển thị trên Mobile"
                            >
                              <Eye className="size-4" />
                            </Button>
                            <Button
                              type="button"
                              variant="secondary"
                              onClick={() => openEditModal(offer)}
                              title="Chỉnh sửa giá và trạng thái"
                            >
                              <Pencil className="mr-1 size-3.5" />
                              Sửa
                            </Button>
                            <Button
                              type="button"
                              variant="secondary"
                              onClick={() => {
                                if (
                                  window.confirm(
                                    `Gỡ "${offer.name}" khỏi Cửa hàng Đảo Di Sản? Vật phẩm trong Catalog và kho người chơi vẫn được giữ nguyên.`,
                                  )
                                ) {
                                  removeMutation.mutate(offer.itemId);
                                }
                              }}
                              title="Gỡ khỏi Shop"
                            >
                              <Trash2 className="size-4 text-error" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </PaperCard>

      {/* Modal đưa vật phẩm lên Shop */}
      {addModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl">
            <h2 className="font-display text-lg font-bold text-ink">
              Đưa vật phẩm lên Cửa hàng Đảo Di Sản
            </h2>
            <p className="mt-1 text-xs text-ink-muted">
              Chỉ liệt kê các vật phẩm đang bật (active), có <code>placeable = true</code> và chưa có mặt trong Shop.
            </p>
            <form onSubmit={handleCreateSubmit} className="mt-4 flex flex-col gap-4">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="select-catalog-item">Chọn vật phẩm từ Catalog *</Label>
                {eligibleCatalogItems.length === 0 ? (
                  <p className="rounded-md bg-surface-alt p-3 text-xs text-ink-muted">
                    Tất cả vật phẩm <code>placeable</code> trong Catalog đều đã có trong Shop, hoặc chưa có vật phẩm hợp lệ.{" "}
                    <Link href="/items/new" className="text-primary underline">
                      Tạo vật phẩm mới tại đây
                    </Link>
                    .
                  </p>
                ) : (
                  <Select
                    id="select-catalog-item"
                    value={selectedItemId}
                    onChange={(e) => setSelectedItemId(e.target.value)}
                  >
                    {eligibleCatalogItems.map((it) => (
                      <option key={it.id} value={it.id}>
                        {it.name} ({it.code}) — {it.itemType}
                      </option>
                    ))}
                  </Select>
                )}
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="new-price">Giá bán (Điểm Sử Ký)</Label>
                  <Input
                    id="new-price"
                    type="number"
                    min={1}
                    placeholder="Để trống = Chưa mở bán"
                    value={newPrice}
                    onChange={(e) => setNewPrice(e.target.value)}
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="new-sort">Thứ tự hiển thị (sortOrder)</Label>
                  <Input
                    id="new-sort"
                    type="number"
                    value={newSortOrder}
                    onChange={(e) => setNewSortOrder(e.target.value)}
                  />
                </div>
              </div>
              <label className="flex items-center gap-2 text-sm text-ink">
                <input
                  type="checkbox"
                  checked={newActive}
                  onChange={(e) => setNewActive(e.target.checked)}
                />
                Mở bán ngay sau khi thêm
              </label>
              <div className="mt-2 flex justify-end gap-2">
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setAddModalOpen(false)}
                >
                  Huỷ
                </Button>
                <Button
                  type="submit"
                  disabled={createMutation.isPending || eligibleCatalogItems.length === 0}
                >
                  {createMutation.isPending ? "Đang thêm..." : "Thêm vào Shop"}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal chỉnh sửa cấu hình bán */}
      {editingOffer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl">
            <h2 className="font-display text-lg font-bold text-ink">
              Cấu hình bán: {editingOffer.name}
            </h2>
            <p className="mt-1 text-xs text-ink-muted">
              Mã: <code>{editingOffer.code}</code> • Render Key:{" "}
              <code>{editingOffer.renderKey ?? "Mặc định"}</code>
            </p>
            <form onSubmit={handleUpdateSubmit} className="mt-4 flex flex-col gap-4">
              <label className="flex items-center gap-2 text-sm text-ink">
                <input
                  type="checkbox"
                  checked={editUnpriced}
                  onChange={(e) => {
                    setEditUnpriced(e.target.checked);
                    if (e.target.checked) setEditActive(false);
                  }}
                />
                Chưa định giá (hiển thị trạng thái &ldquo;Chưa mở bán&rdquo;)
              </label>
              <div className="grid grid-cols-2 gap-4">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="edit-price">Giá Điểm Sử Ký</Label>
                  <Input
                    id="edit-price"
                    type="number"
                    min={1}
                    disabled={editUnpriced}
                    value={editPrice}
                    onChange={(e) => setEditPrice(e.target.value)}
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="edit-sort">Thứ tự hiển thị (sortOrder)</Label>
                  <Input
                    id="edit-sort"
                    type="number"
                    value={editSortOrder}
                    onChange={(e) => setEditSortOrder(e.target.value)}
                  />
                </div>
              </div>
              <label className="flex items-center gap-2 text-sm text-ink">
                <input
                  type="checkbox"
                  disabled={editUnpriced}
                  checked={editActive}
                  onChange={(e) => setEditActive(e.target.checked)}
                />
                Đang mở bán trên ứng dụng Mobile
              </label>
              <div className="mt-2 flex justify-end gap-2">
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setEditingOffer(null)}
                >
                  Huỷ
                </Button>
                <Button type="submit" disabled={updateMutation.isPending}>
                  {updateMutation.isPending ? "Đang lưu..." : "Lưu thay đổi"}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Xem trước Mobile */}
      {previewOffer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-2xl border-2 border-[#D4B06A] bg-[#FBF4E3] p-6 shadow-2xl">
            <div className="flex items-center justify-between border-b border-[#D4B06A]/50 pb-3">
              <span className="text-xs font-bold uppercase tracking-wider text-[#6B4A2B]">
                Xem trước thẻ Cửa Hàng Di Sản (Mobile)
              </span>
              <button
                type="button"
                onClick={() => setPreviewOffer(null)}
                className="text-xs font-semibold text-[#6B4A2B] hover:underline"
              >
                Đóng
              </button>
            </div>
            <div className="mt-4 flex items-center gap-3.5 rounded-2xl border-[1.5px] border-[#D4B06A] bg-[#FFFDF8] p-3.5 shadow-sm">
              <div className="flex size-[68px] shrink-0 flex-col items-center justify-center rounded-xl border border-[#D4B06A] bg-[#F5E6C8] p-2 text-center">
                <Sparkles className="size-6 text-[#8B6508]" />
                <span className="mt-1 max-w-full truncate text-[9px] font-mono text-[#6B4A2B]">
                  {previewOffer.renderKey ?? previewOffer.code}
                </span>
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-bold text-[#3D2610]">{previewOffer.name}</p>
                <p className="mt-0.5 line-clamp-2 text-xs text-[#6B4A2B]">
                  {previewOffer.description || "Vật phẩm trang trí Đảo Di Sản."}
                </p>
                <div className="mt-2 flex items-center gap-2">
                  <span className="rounded-md bg-[#F3E2BA] px-2 py-0.5 text-[11px] font-bold text-[#6E470B]">
                    {previewOffer.pricePoints != null && previewOffer.pricePoints > 0
                      ? `${previewOffer.pricePoints} Điểm Sử Ký`
                      : "Chưa mở bán"}
                  </span>
                </div>
              </div>
              <div>
                <span className="inline-block rounded-xl bg-[#D48B19] px-3 py-2 text-xs font-extrabold text-white">
                  {previewOffer.purchasable ? "MUA" : "CHƯA BÁN"}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
