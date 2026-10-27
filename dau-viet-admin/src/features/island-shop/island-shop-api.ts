import { apiFetch } from "@/lib/api-client";

export interface AdminIslandShopOfferDto {
  offerId: string;
  itemId: string;
  code: string;
  name: string;
  description: string | null;
  category: string;
  rarity: "COMMON" | "UNCOMMON" | "RARE" | "EPIC";
  itemType: string;
  placeable: boolean;
  catalogActive: boolean;
  renderKey: string | null;
  assetId: string | null;
  pricePoints: number | null;
  active: boolean;
  sortOrder: number;
  createdAt: string;
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
  getOffer: (offerId: string) =>
    apiFetch<AdminIslandShopOfferDto>(`/admin/island-shop/${offerId}`),
  createOffer: (req: CreateShopOfferRequest) =>
    apiFetch<AdminIslandShopOfferDto>("/admin/island-shop", {
      method: "POST",
      body: JSON.stringify(req),
    }),
  updateOffer: (offerId: string, req: UpdateShopOfferRequest) =>
    apiFetch<AdminIslandShopOfferDto>(`/admin/island-shop/${offerId}`, {
      method: "PUT",
      body: JSON.stringify(req),
    }),
  removeOffer: (offerId: string) =>
    apiFetch<void>(`/admin/island-shop/${offerId}`, {
      method: "DELETE",
    }),
};
