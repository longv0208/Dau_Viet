import { apiFetch } from "@/lib/api-client";

export interface AdminIslandShopOfferDto {
  itemId: string;
  code: string;
  name: string;
  description: string | null;
  category: string;
  itemType: string;
  rarity: "COMMON" | "UNCOMMON" | "RARE" | "EPIC";
  assetId: string | null;
  renderKey: string | null;
  placeable: boolean;
  catalogActive: boolean;
  pricePoints: number | null;
  active: boolean;
  purchasable: boolean;
  sortOrder: number;
}

export interface CreateShopOfferRequest {
  itemId: string;
  pricePoints?: number | null;
  active?: boolean;
  sortOrder?: number | null;
}

export interface UpdateShopOfferRequest {
  pricePoints?: number | null;
  clearPrice?: boolean;
  active?: boolean;
  sortOrder?: number | null;
}

export const islandShopApi = {
  listOffers: () => apiFetch<AdminIslandShopOfferDto[]>("/admin/island-shop"),
  getOffer: (itemId: string) =>
    apiFetch<AdminIslandShopOfferDto>(`/admin/island-shop/${itemId}`),
  createOffer: (req: CreateShopOfferRequest) =>
    apiFetch<AdminIslandShopOfferDto>("/admin/island-shop", {
      method: "POST",
      body: JSON.stringify(req),
    }),
  updateOffer: (itemId: string, req: UpdateShopOfferRequest) =>
    apiFetch<AdminIslandShopOfferDto>(`/admin/island-shop/${itemId}`, {
      method: "PUT",
      body: JSON.stringify(req),
    }),
  removeOffer: (itemId: string) =>
    apiFetch<void>(`/admin/island-shop/${itemId}`, {
      method: "DELETE",
    }),
};
