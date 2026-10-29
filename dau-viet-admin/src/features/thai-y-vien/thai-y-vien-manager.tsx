"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import {
  Eye,
  HeartPulse,
  Pencil,
  Plus,
  Sparkles,
  Store,
  Trash2,
  Zap,
} from "lucide-react";

import { toUserMessage } from "@/lib/api-error";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/error-state";

import {
  thaiYVienApi,
  type AdminEnergyRemedyDto,
  type CreateEnergyRemedyRequest,
  type EnergyRemedyRarity,
  type UpdateEnergyRemedyRequest,
} from "./thai-y-vien-api";

const RARITY_LABELS: Record<EnergyRemedyRarity, string> = {
  COMMON: "Phổ thông",
  UNCOMMON: "Thanh tao",
  RARE: "Quý hiếm",
  EPIC: "Bảo vật",
};

const RARITY_BADGE_CLASSES: Record<EnergyRemedyRarity, string> = {
  COMMON: "bg-surface-alt text-ink-muted",
  UNCOMMON: "bg-emerald-100 text-emerald-800",
  RARE: "bg-blue-100 text-blue-800",
  EPIC: "bg-purple-100 text-purple-800",
};

const ICON_CHOICES: { value: string; label: string }[] = [
  { value: "energy_nuoc_voi", label: "Nước Vối (bát nước ấm)" },
  { value: "energy_tra_sen", label: "Trà Sen (tách trà)" },
  { value: "energy_linh_chi", label: "Nấm Linh Chi" },
  { value: "energy_sam_ngoc_linh", label: "Sâm Ngọc Linh" },
];

function formatCooldown(seconds: number): string {
  if (seconds <= 0) return "Không giới hạn";
  if (seconds % 3600 === 0) {
    const h = seconds / 3600;
    return h === 1 ? "1 giờ" : `${h} giờ`;
  }
  if (seconds % 60 === 0) return `${seconds / 60} phút`;
  return `${seconds} giây`;
}

export function ThaiYVienManager() {
  const qc = useQueryClient();
  const [actionError, setActionError] = useState<string | null>(null);
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);

  const [addModalOpen, setAddModalOpen] = useState(false);
  const [editingRemedy, setEditingRemedy] =
    useState<AdminEnergyRemedyDto | null>(null);
  const [previewRemedy, setPreviewRemedy] =
    useState<AdminEnergyRemedyDto | null>(null);

  // ---------- Settings form state ----------
  const [formEnabled, setFormEnabled] = useState(true);
  const [formMaxEnergy, setFormMaxEnergy] = useState("100");
  const [formPenalty, setFormPenalty] = useState("10");
  const [formRecoveryAmount, setFormRecoveryAmount] = useState("5");
  const [formRecoveryIntervalMinutes, setFormRecoveryIntervalMinutes] =
    useState("15");
  const [settingsLoaded, setSettingsLoaded] = useState(false);

  // ---------- Queries ----------
  const settingsQuery = useQuery({
    queryKey: ["energy-admin", "settings"],
    queryFn: () => thaiYVienApi.getSettings(),
  });
  const remediesQuery = useQuery({
    queryKey: ["energy-admin", "remedies"],
    queryFn: () => thaiYVienApi.listRemedies(),
  });

  // Đồng bộ settings vào form 1 lần khi fetch xong (không ghi đè khi đang gõ).
  if (!settingsLoaded && settingsQuery.data) {
    const s = settingsQuery.data;
    setFormEnabled(s.enabled);
    setFormMaxEnergy(String(s.maxEnergy));
    setFormPenalty(String(s.incorrectPenalty));
    setFormRecoveryAmount(String(s.recoveryAmount));
    setFormRecoveryIntervalMinutes(
      String(Math.max(1, Math.round(s.recoveryIntervalSeconds / 60))),
    );
    setSettingsLoaded(true);
  }

  // ---------- Mutations ----------
  const settingsMutation = useMutation({
    mutationFn: () =>
      thaiYVienApi.updateSettings({
        enabled: formEnabled,
        maxEnergy: Number(formMaxEnergy),
        incorrectPenalty: Number(formPenalty),
        recoveryAmount: Number(formRecoveryAmount),
        recoveryIntervalSeconds: Number(formRecoveryIntervalMinutes) * 60,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["energy-admin"] });
      setActionError(null);
      setActionSuccess("Đã lưu quy tắc Thể lực chung.");
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const createMutation = useMutation({
    mutationFn: (req: CreateEnergyRemedyRequest) =>
      thaiYVienApi.createRemedy(req),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["energy-admin"] });
      setAddModalOpen(false);
      setActionError(null);
      setActionSuccess("Đã thêm vật phẩm Viện Thái Y mới.");
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, req }: { id: string; req: UpdateEnergyRemedyRequest }) =>
      thaiYVienApi.updateRemedy(id, req),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["energy-admin"] });
      setEditingRemedy(null);
      setActionError(null);
      setActionSuccess("Đã cập nhật vật phẩm Viện Thái Y.");
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const patchMutation = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) =>
      thaiYVienApi.patchRemedy(id, { active }),
    onSuccess: (updated) => {
      qc.invalidateQueries({ queryKey: ["energy-admin"] });
      setActionError(null);
      setActionSuccess(
        updated.active
          ? `Đã mở bán "${updated.title}".`
          : `Đã ẩn "${updated.title}" khỏi Viện Thái Y.`,
      );
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => thaiYVienApi.deleteRemedy(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["energy-admin"] });
      setActionError(null);
      setActionSuccess("Đã xóa vật phẩm Viện Thái Y.");
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  // ---------- Render ----------

  if (settingsQuery.isPending || remediesQuery.isPending) {
    return <Skeleton className="h-96 w-full" />;
  }
  if (settingsQuery.isError) {
    return (
      <ErrorState
        error={settingsQuery.error}
        onRetry={() => settingsQuery.refetch()}
      />
    );
  }
  if (remediesQuery.isError) {
    return (
      <ErrorState
        error={remediesQuery.error}
        onRetry={() => remediesQuery.refetch()}
      />
    );
  }

  const remedies = remediesQuery.data ?? [];
  const maxEnergyNum = Math.max(1, Number(formMaxEnergy) || 1);
  const penaltyNum = Math.max(1, Number(formPenalty) || 1);
  const recAmtNum = Math.max(1, Number(formRecoveryAmount) || 1);
  const recIntMinNum = Math.max(1, Number(formRecoveryIntervalMinutes) || 1);
  const maxErrorsBeforeDepletion = Math.ceil(maxEnergyNum / penaltyNum);
  const minutesToFull = Math.ceil(maxEnergyNum / recAmtNum) * recIntMinNum;
  const fullRecHours = Math.floor(minutesToFull / 60);
  const fullRecMins = minutesToFull % 60;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-display flex items-center gap-2 text-2xl font-bold text-ink">
            <HeartPulse className="size-6 text-error" />
            Viện Thái Y &amp; Thể lực
          </h1>
          <p className="text-sm text-ink-muted">
            Quản lý quy tắc Thể lực toàn hệ thống và danh mục vật phẩm hồi phục
            mà học viên mua/dùng tại Viện Thái Y.
          </p>
        </div>
        <Button type="button" onClick={() => setAddModalOpen(true)}>
          <Plus className="mr-1.5 size-4" />
          Thêm vật phẩm mới
        </Button>
      </div>

      {actionError && (
        <div
          role="alert"
          className="rounded-md bg-error/10 px-4 py-3 text-sm text-error"
        >
          {actionError}
        </div>
      )}
      {actionSuccess && (
        <div className="rounded-md bg-success/15 px-4 py-3 text-sm text-ink">
          {actionSuccess}
        </div>
      )}

      {/* ---------- Khối 1: Quy tắc Thể lực chung ---------- */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Zap className="size-4 text-amber-600" />
            Quy tắc Thể lực chung
          </CardTitle>
          <CardDescription>
            Thông số áp dụng cho mọi learner trong hệ thống. Thay đổi có hiệu
            lực ngay lập tức — không cần deploy lại backend.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form
            className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3"
            onSubmit={(e) => {
              e.preventDefault();
              setActionError(null);
              const maxE = Number(formMaxEnergy);
              const pen = Number(formPenalty);
              const recA = Number(formRecoveryAmount);
              const recIntMin = Number(formRecoveryIntervalMinutes);
              if (
                Number.isNaN(maxE) ||
                maxE < 1 ||
                maxE > 100 ||
                Number.isNaN(pen) ||
                pen < 1 ||
                pen > 100 ||
                Number.isNaN(recA) ||
                recA < 1 ||
                recA > 100 ||
                Number.isNaN(recIntMin) ||
                recIntMin < 1 ||
                recIntMin > 1440
              ) {
                setActionError(
                  "Giá trị không hợp lệ: maxEnergy/penalty/recoveryAmount 1..100, interval 1..1440 phút.",
                );
                return;
              }
              settingsMutation.mutate();
            }}
          >
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="set-max">Thể lực tối đa (⚡)</Label>
              <Input
                id="set-max"
                type="number"
                min={1}
                max={100}
                value={formMaxEnergy}
                onChange={(e) => setFormMaxEnergy(e.target.value)}
              />
              <p className="text-xs text-ink-muted">1..100 — khớp CHECK V21</p>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="set-pen">Trừ khi sai câu chấm điểm (⚡)</Label>
              <Input
                id="set-pen"
                type="number"
                min={1}
                max={100}
                value={formPenalty}
                onChange={(e) => setFormPenalty(e.target.value)}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="set-rec-amt">Hồi tự nhiên mỗi chu kỳ (⚡)</Label>
              <Input
                id="set-rec-amt"
                type="number"
                min={1}
                max={100}
                value={formRecoveryAmount}
                onChange={(e) => setFormRecoveryAmount(e.target.value)}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="set-rec-int">Chu kỳ hồi (phút)</Label>
              <Input
                id="set-rec-int"
                type="number"
                min={1}
                max={1440}
                value={formRecoveryIntervalMinutes}
                onChange={(e) =>
                  setFormRecoveryIntervalMinutes(e.target.value)
                }
              />
              <p className="text-xs text-ink-muted">
                1 phút .. 24 giờ (quy đổi sang giây ở backend)
              </p>
            </div>
            <label className="flex items-center gap-2 self-end pb-2 text-sm text-ink">
              <input
                type="checkbox"
                checked={formEnabled}
                onChange={(e) => setFormEnabled(e.target.checked)}
              />
              Bật hệ thống Thể lực (false = theo dõi chứ không trừ/chặn)
            </label>
            <div className="flex items-end gap-3">
              <Button type="submit" disabled={settingsMutation.isPending}>
                {settingsMutation.isPending ? "Đang lưu..." : "Lưu quy tắc"}
              </Button>
            </div>
          </form>

          {/* Live Balance Preview */}
          <div className="mt-5 rounded-lg border border-amber-300/70 bg-amber-50 p-4 text-sm text-ink">
            <p className="font-semibold">Mô phỏng tự động:</p>
            <ul className="mt-1 list-disc space-y-0.5 pl-5 text-ink-muted">
              <li>
                Số câu sai tối đa trước khi cạn bình:{" "}
                <strong className="text-ink">{maxErrorsBeforeDepletion}</strong>{" "}
                lần ({maxEnergyNum}⚡ / {penaltyNum}⚡ mỗi lần)
              </li>
              <li>
                Hồi đầy từ 0 → {maxEnergyNum}⚡:{" "}
                <strong className="text-ink">
                  {fullRecHours > 0 ? `${fullRecHours} giờ ` : ""}
                  {fullRecMins > 0 ? `${fullRecMins} phút` : ""}
                  {fullRecHours === 0 && fullRecMins === 0 ? "0 phút" : ""}
                </strong>{" "}
                ({recAmtNum}⚡ / {recIntMinNum} phút)
              </li>
            </ul>
          </div>
        </CardContent>
      </Card>

      {/* ---------- Khối 2: Danh mục Vật phẩm Viện Thái Y ---------- */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Store className="size-4 text-amber-600" />
            Danh mục Vật phẩm Viện Thái Y ({remedies.length})
          </CardTitle>
          <CardDescription>
            Vật phẩm learner mua/dùng trong M-28 — giá Điểm Sử Ký, lượng ⚡
            hồi, cooldown và trạng thái mở bán.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {remedies.length === 0 ? (
            <div className="rounded-lg border border-dashed border-border p-8 text-center">
              <Sparkles className="mx-auto mb-2 size-8 text-ink-muted" />
              <p className="font-medium text-ink">
                Chưa có vật phẩm nào trong Viện Thái Y
              </p>
              <p className="mt-1 text-xs text-ink-muted">
                Nhấn &ldquo;Thêm vật phẩm mới&rdquo; để tạo remedy đầu tiên.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-sm">
                <thead>
                  <tr className="border-b border-border text-xs font-semibold uppercase text-ink-muted">
                    <th className="py-3 pr-3">Thứ tự</th>
                    <th className="px-3 py-3">Vật phẩm</th>
                    <th className="px-3 py-3">Phẩm cấp</th>
                    <th className="px-3 py-3">Hồi (⚡)</th>
                    <th className="px-3 py-3">Giá (Điểm Sử Ký)</th>
                    <th className="px-3 py-3">Hồi chiêu</th>
                    <th className="px-3 py-3">Trạng thái</th>
                    <th className="py-3 pl-3 text-right">Thao tác</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {remedies.map((r) => (
                    <tr key={r.id} className="hover:bg-surface-alt/50">
                      <td className="py-3 pr-3 font-mono text-xs text-ink-muted">
                        #{r.sortOrder}
                      </td>
                      <td className="px-3 py-3">
                        <div className="font-medium text-ink">{r.title}</div>
                        <div className="text-xs text-ink-muted">
                          <code>{r.code}</code>
                          <span className="ml-2 italic">{r.iconKey}</span>
                        </div>
                        <div className="mt-0.5 max-w-[280px] truncate text-[11px] text-ink-muted">
                          {r.description}
                        </div>
                      </td>
                      <td className="px-3 py-3">
                        <span
                          className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                            RARITY_BADGE_CLASSES[r.rarity] ??
                            "bg-surface-alt text-ink-muted"
                          }`}
                        >
                          {RARITY_LABELS[r.rarity] ?? r.rarity}
                        </span>
                      </td>
                      <td className="px-3 py-3">
                        <span className="inline-flex items-center rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-semibold text-emerald-800">
                          +{r.energyGain} ⚡
                        </span>
                      </td>
                      <td className="px-3 py-3">
                        {r.pointsCost > 0 ? (
                          <span className="font-semibold text-amber-800">
                            {r.pointsCost.toLocaleString("vi-VN")} Điểm Sử Ký
                          </span>
                        ) : (
                          <span className="text-xs italic text-emerald-700">
                            Miễn phí (0 Điểm)
                          </span>
                        )}
                      </td>
                      <td className="px-3 py-3 text-xs text-ink">
                        {formatCooldown(r.cooldownSeconds)}
                      </td>
                      <td className="px-3 py-3">
                        <span
                          className={
                            r.active
                              ? "inline-flex items-center rounded-full bg-success/20 px-2.5 py-0.5 text-xs font-medium text-ink"
                              : "inline-flex items-center rounded-full bg-surface-alt px-2.5 py-0.5 text-xs font-medium text-ink-muted"
                          }
                        >
                          {r.active ? "Đang mở" : "Tạm ẩn"}
                        </span>
                      </td>
                      <td className="py-3 pl-3 text-right">
                        <div className="inline-flex items-center gap-1.5">
                          <Button
                            type="button"
                            variant="secondary"
                            onClick={() => setPreviewRemedy(r)}
                            title="Xem trước hiển thị trên Mobile"
                          >
                            <Eye className="size-4" />
                          </Button>
                          <Button
                            type="button"
                            variant="secondary"
                            onClick={() => setEditingRemedy(r)}
                            title="Chỉnh sửa"
                          >
                            <Pencil className="mr-1 size-3.5" />
                            Sửa
                          </Button>
                          <Button
                            type="button"
                            variant="secondary"
                            onClick={() =>
                              patchMutation.mutate({
                                id: r.id,
                                active: !r.active,
                              })
                            }
                            title={r.active ? "Tạm ẩn" : "Mở lại"}
                          >
                            {r.active ? "Ẩn" : "Mở"}
                          </Button>
                          <Button
                            type="button"
                            variant="secondary"
                            onClick={() => {
                              if (
                                window.confirm(
                                  `Xóa "${r.title}" khỏi Viện Thái Y? Thao tác không hoàn tác được.`,
                                )
                              ) {
                                deleteMutation.mutate(r.id);
                              }
                            }}
                            title="Xóa vật phẩm"
                          >
                            <Trash2 className="size-4 text-error" />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* ---------- Modal Thêm remedy ---------- */}
      {addModalOpen && (
        <RemedyFormModal
          title="Thêm vật phẩm Viện Thái Y mới"
          submitLabel="Thêm vật phẩm"
          isPending={createMutation.isPending}
          onClose={() => setAddModalOpen(false)}
          onSubmit={(values) => {
            createMutation.mutate({
              code: values.code ?? "",
              title: values.title!,
              description: values.description!,
              rarity: values.rarity!,
              iconKey: values.iconKey!,
              assetId: values.assetId,
              energyGain: values.energyGain!,
              pointsCost: values.pointsCost!,
              cooldownSeconds: values.cooldownSeconds!,
              active: values.active,
              sortOrder: values.sortOrder,
            });
          }}

        />
      )}

      {/* ---------- Modal Sửa remedy ---------- */}
      {editingRemedy && (
        <RemedyFormModal
          title={`Chỉnh sửa: ${editingRemedy.title}`}
          submitLabel="Lưu thay đổi"
          isPending={updateMutation.isPending}
          initial={editingRemedy}
          onClose={() => setEditingRemedy(null)}
          onSubmit={(values) => {
            updateMutation.mutate({
              id: editingRemedy.id,
              req: {
                title: values.title!,
                description: values.description!,
                rarity: values.rarity!,
                iconKey: values.iconKey!,
                assetId: values.assetId,
                energyGain: values.energyGain!,
                pointsCost: values.pointsCost!,
                cooldownSeconds: values.cooldownSeconds!,
                active: values.active!,
                sortOrder: values.sortOrder!,
              },
            });
          }}
        />
      )}

      {/* ---------- Modal Preview ---------- */}
      {previewRemedy && (
        <RemedyPreviewModal
          remedy={previewRemedy}
          onClose={() => setPreviewRemedy(null)}
        />
      )}
    </div>
  );
}

/* ==================== Form modal ==================== */

interface RemedyFormValues {
  code?: string;
  title?: string;
  description?: string;
  rarity?: EnergyRemedyRarity;
  iconKey?: string;
  assetId?: string | null;
  energyGain?: number;
  pointsCost?: number;
  cooldownSeconds?: number;
  active?: boolean;
  sortOrder?: number;
}

interface RemedyFormModalProps {
  title: string;
  submitLabel: string;
  isPending: boolean;
  initial?: AdminEnergyRemedyDto;
  onClose: () => void;
  onSubmit: (values: RemedyFormValues) => void;
}

function RemedyFormModal({
  title,
  submitLabel,
  isPending,
  initial,
  onClose,
  onSubmit,
}: RemedyFormModalProps) {
  const isEdit = initial != null;
  const [code, setCode] = useState(initial?.code ?? "");
  const [rTitle, setTitle] = useState(initial?.title ?? "");
  const [desc, setDesc] = useState(initial?.description ?? "");
  const [rarity, setRarity] = useState<EnergyRemedyRarity>(
    initial?.rarity ?? "COMMON",
  );
  const [iconKey, setIconKey] = useState(
    initial?.iconKey ?? "energy_nuoc_voi",
  );
  const [energyGain, setEnergyGain] = useState(
    String(initial?.energyGain ?? 20),
  );
  const [pointsCost, setPointsCost] = useState(
    String(initial?.pointsCost ?? 0),
  );
  const [cooldownHours, setCooldownHours] = useState(
    String(Math.floor((initial?.cooldownSeconds ?? 0) / 3600)),
  );
  const [cooldownMins, setCooldownMins] = useState(
    String(Math.floor(((initial?.cooldownSeconds ?? 0) % 3600) / 60)),
  );
  const [sortOrder, setSortOrder] = useState(
    String(initial?.sortOrder ?? 0),
  );
  const [active, setActive] = useState(initial?.active ?? true);
  const [formError, setFormError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    const gain = Number(energyGain);
    const cost = Number(pointsCost);
    const cdH = Number(cooldownHours) || 0;
    const cdM = Number(cooldownMins) || 0;
    const cooldown = cdH * 3600 + cdM * 60;
    if (!isEdit && !code.trim()) {
      setFormError("Mã vật phẩm (code) là bắt buộc.");
      return;
    }
    if (!rTitle.trim() || !desc.trim()) {
      setFormError("Tiêu đề và mô tả không được để trống.");
      return;
    }
    if (Number.isNaN(gain) || gain < 1 || gain > 100) {
      setFormError("Lượng hồi phải từ 1 đến 100 ⚡.");
      return;
    }
    if (Number.isNaN(cost) || cost < 0) {
      setFormError("Giá Điểm Sử Ký phải ≥ 0 (0 = Miễn phí).");
      return;
    }
    if (cooldown < 0) {
      setFormError("Cooldown không hợp lệ.");
      return;
    }
    onSubmit({
      code: code.trim().toUpperCase(),
      title: rTitle.trim(),
      description: desc.trim(),
      rarity,
      iconKey,
      assetId: null,
      energyGain: gain,
      pointsCost: cost,
      cooldownSeconds: cooldown,
      active,
      sortOrder: Number(sortOrder) || 0,
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-xl bg-white p-6 shadow-xl">
        <h2 className="font-display text-lg font-bold text-ink">{title}</h2>
        {formError && (
          <div className="mt-3 rounded-md bg-error/10 px-3 py-2 text-sm text-error">
            {formError}
          </div>
        )}
        <form onSubmit={handleSubmit} className="mt-4 flex flex-col gap-4">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-code">Mã vật phẩm (UPPER_SNAKE_CASE) *</Label>
              <Input
                id="f-code"
                placeholder="NUOC_VOI"
                value={code}
                onChange={(e) =>
                  setCode(e.target.value.toUpperCase().replace(/\s/g, "_"))
                }
                disabled={isEdit}
              />
              <p className="text-xs text-ink-muted">
                Không thể sửa sau khi tạo — khóa truy vết trong ledger.
              </p>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-title">Tên hiển thị *</Label>
              <Input
                id="f-title"
                placeholder="Nước Vối Tĩnh Tâm"
                value={rTitle}
                onChange={(e) => setTitle(e.target.value)}
              />
            </div>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="f-desc">Mô tả công dụng *</Label>
            <textarea
              id="f-desc"
              rows={2}
              className="w-full rounded-md border border-border bg-white px-3 py-2 text-sm text-ink"
              placeholder="Bát nước vối ấm lành tính giúp sĩ tử thư giãn gân cốt..."
              value={desc}
              onChange={(e) => setDesc(e.target.value)}
            />
          </div>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-rarity">Phẩm cấp</Label>
              <Select
                id="f-rarity"
                value={rarity}
                onChange={(e) =>
                  setRarity(e.target.value as EnergyRemedyRarity)
                }
              >
                {Object.entries(RARITY_LABELS).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v}
                  </option>
                ))}
              </Select>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-icon">Minh họa</Label>
              <Select
                id="f-icon"
                value={iconKey}
                onChange={(e) => setIconKey(e.target.value)}
              >
                {ICON_CHOICES.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </Select>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-gain">Lượng hồi (+⚡)</Label>
              <Input
                id="f-gain"
                type="number"
                min={1}
                max={100}
                value={energyGain}
                onChange={(e) => setEnergyGain(e.target.value)}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-cost">Giá (Điểm Sử Ký)</Label>
              <Input
                id="f-cost"
                type="number"
                min={0}
                value={pointsCost}
                onChange={(e) => setPointsCost(e.target.value)}
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-cdh">Cooldown — giờ</Label>
              <Input
                id="f-cdh"
                type="number"
                min={0}
                max={72}
                value={cooldownHours}
                onChange={(e) => setCooldownHours(e.target.value)}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-cdm">Cooldown — phút</Label>
              <Input
                id="f-cdm"
                type="number"
                min={0}
                max={59}
                value={cooldownMins}
                onChange={(e) => setCooldownMins(e.target.value)}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="f-sort">Thứ tự hiển thị</Label>
              <Input
                id="f-sort"
                type="number"
                value={sortOrder}
                onChange={(e) => setSortOrder(e.target.value)}
              />
            </div>
            <label className="flex items-center gap-2 self-end pb-2 text-sm text-ink">
              <input
                type="checkbox"
                checked={active}
                onChange={(e) => setActive(e.target.checked)}
              />
              Đang mở bán
            </label>
          </div>
          <div className="mt-2 flex justify-end gap-2">
            <Button type="button" variant="secondary" onClick={onClose}>
              Huỷ
            </Button>
            <Button type="submit" disabled={isPending}>
              {isPending ? "Đang lưu..." : submitLabel}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ==================== Preview modal ==================== */

function RemedyPreviewModal({
  remedy,
  onClose,
}: {
  remedy: AdminEnergyRemedyDto;
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-xl bg-gradient-to-b from-[#FFFBF4] via-[#F7F2E7] to-[#F2EADC] p-6 shadow-xl">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-amber-700">
          Mobile Preview — Viện Thái Y (M-28)
        </p>
        <div className="mt-3 rounded-[20px] border-2 border-amber-500/80 bg-white/90 p-4 shadow-md">
          <div className="flex items-start gap-3">
            <div className="flex size-[76px] shrink-0 items-center justify-center rounded-2xl border border-amber-300/70 bg-amber-50">
              <Sparkles className="size-8 text-amber-700" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-1.5">
                <span
                  className={`inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                    RARITY_BADGE_CLASSES[remedy.rarity]
                  }`}
                >
                  {RARITY_LABELS[remedy.rarity]}
                </span>
                <span className="inline-flex items-center rounded-full bg-riverBlue/10 px-2 py-0.5 text-[11px] font-medium text-blue-800">
                  {formatCooldown(remedy.cooldownSeconds)}
                </span>
              </div>
              <h3 className="mt-1 font-display text-base font-bold text-ink">
                {remedy.title}
              </h3>
              <p className="mt-0.5 line-clamp-2 text-xs text-ink-muted">
                {remedy.description}
              </p>
            </div>
          </div>
          <div className="mt-3 flex items-center justify-between">
            <div>
              {remedy.pointsCost > 0 ? (
                <p className="text-sm font-bold text-amber-800">
                  ★ {remedy.pointsCost.toLocaleString("vi-VN")} Điểm Sử Ký
                </p>
              ) : (
                <p className="text-sm font-bold text-emerald-700">
                  Miễn phí (1 lần/ngày)
                </p>
              )}
              <p className="text-[11px] text-emerald-800">
                +{remedy.energyGain} ⚡ Thể lực
              </p>
            </div>
            <button
              type="button"
              className="rounded-xl bg-gradient-to-b from-[#E85A4F] to-[#C8402F] px-4 py-2 text-xs font-bold uppercase tracking-wide text-white shadow"
              disabled
            >
              {remedy.pointsCost > 0 ? "BỒI BỔ" : "NHẬN NGAY"}
            </button>
          </div>
        </div>
        <div className="mt-4 flex justify-end">
          <Button type="button" variant="secondary" onClick={onClose}>
            Đóng
          </Button>
        </div>
      </div>
    </div>
  );
}
