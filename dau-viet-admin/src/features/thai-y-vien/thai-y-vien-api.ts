import { apiFetch } from "@/lib/api-client";

export type EnergyRemedyRarity = "COMMON" | "UNCOMMON" | "RARE" | "EPIC";

export interface AdminEnergySettingsDto {
  enabled: boolean;
  maxEnergy: number;
  incorrectPenalty: number;
  recoveryAmount: number;
  recoveryIntervalSeconds: number;
  updatedAt: string;
  updatedBy: string | null;
  rowVersion: number;
}

export interface UpdateEnergySettingsRequest {
  enabled: boolean;
  maxEnergy: number;
  incorrectPenalty: number;
  recoveryAmount: number;
  recoveryIntervalSeconds: number;
}

export interface AdminEnergyRemedyDto {
  id: string;
  code: string;
  title: string;
  description: string;
  rarity: EnergyRemedyRarity;
  iconKey: string;
  assetId: string | null;
  energyGain: number;
  pointsCost: number;
  cooldownSeconds: number;
  active: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
  rowVersion: number;
}

export interface CreateEnergyRemedyRequest {
  code: string;
  title: string;
  description: string;
  rarity: EnergyRemedyRarity;
  iconKey: string;
  assetId?: string | null;
  energyGain: number;
  pointsCost: number;
  cooldownSeconds: number;
  active?: boolean;
  sortOrder?: number;
}

export interface UpdateEnergyRemedyRequest {
  title: string;
  description: string;
  rarity: EnergyRemedyRarity;
  iconKey: string;
  assetId?: string | null;
  energyGain: number;
  pointsCost: number;
  cooldownSeconds: number;
  active: boolean;
  sortOrder: number;
}

export type PatchEnergyRemedyRequest = Partial<UpdateEnergyRemedyRequest>;

export const thaiYVienApi = {
  getSettings: () => apiFetch<AdminEnergySettingsDto>("/admin/energy/settings"),
  updateSettings: (req: UpdateEnergySettingsRequest) =>
    apiFetch<AdminEnergySettingsDto>("/admin/energy/settings", {
      method: "PUT",
      body: JSON.stringify(req),
    }),

  listRemedies: () =>
    apiFetch<AdminEnergyRemedyDto[]>("/admin/energy/remedies"),
  getRemedy: (id: string) =>
    apiFetch<AdminEnergyRemedyDto>(`/admin/energy/remedies/${id}`),
  createRemedy: (req: CreateEnergyRemedyRequest) =>
    apiFetch<AdminEnergyRemedyDto>("/admin/energy/remedies", {
      method: "POST",
      body: JSON.stringify(req),
    }),
  updateRemedy: (id: string, req: UpdateEnergyRemedyRequest) =>
    apiFetch<AdminEnergyRemedyDto>(`/admin/energy/remedies/${id}`, {
      method: "PUT",
      body: JSON.stringify(req),
    }),
  patchRemedy: (id: string, req: PatchEnergyRemedyRequest) =>
    apiFetch<AdminEnergyRemedyDto>(`/admin/energy/remedies/${id}`, {
      method: "PATCH",
      body: JSON.stringify(req),
    }),
  deleteRemedy: (id: string) =>
    apiFetch<void>(`/admin/energy/remedies/${id}`, {
      method: "DELETE",
    }),
};
