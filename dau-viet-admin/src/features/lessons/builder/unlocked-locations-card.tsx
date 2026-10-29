"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useMemo, useState } from "react";
import { ExternalLink, Lock, MapPin, Plus, Trash2 } from "lucide-react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import {
  LOCATION_KIND_LABELS,
  resolveHeritageFallbackIllustration,
  type StandaloneLocationResponse,
  type UnlockRuleMode,
} from "@/lib/dto/map-location";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { StatusChip } from "@/components/status-chip";

export function UnlockedLocationsCard({
  lessonId,
  eventId,
  readOnly,
}: {
  lessonId: string;
  eventId: string;
  readOnly: boolean;
}) {
  const qc = useQueryClient();
  const [selectedLocId, setSelectedLocId] = useState("");
  const [selectedMode, setSelectedMode] = useState<UnlockRuleMode>("ANY");
  const [error, setError] = useState<string | null>(null);

  const locationsQuery = useQuery({
    queryKey: qk.mapLocations.standaloneList({}),
    queryFn: () => apiFetch<StandaloneLocationResponse[]>(`/admin/map-locations`),
    staleTime: 30_000,
  });

  const allLocations = useMemo(
    () => locationsQuery.data ?? [],
    [locationsQuery.data],
  );

  const linkedLocations = useMemo(
    () =>
      allLocations.filter(
        (loc) =>
          loc.unlockRuleMode !== "NONE" &&
          loc.unlockLessons.some((u) => u.lessonId === lessonId),
      ),
    [allLocations, lessonId],
  );

  const attachableLocations = useMemo(
    () =>
      allLocations
        .filter((loc) => !loc.unlockLessons.some((u) => u.lessonId === lessonId))
        .sort((a, b) => {
          const aSameEvent =
            a.eventId === eventId || a.events.some((e) => e.eventId === eventId);
          const bSameEvent =
            b.eventId === eventId || b.events.some((e) => e.eventId === eventId);
          if (aSameEvent && !bSameEvent) return -1;
          if (!aSameEvent && bSameEvent) return 1;
          return a.title.localeCompare(b.title, "vi");
        }),
    [allLocations, lessonId, eventId],
  );

  const updateUnlockRuleMutation = useMutation({
    mutationFn: async (p: {
      locationId: string;
      unlockRuleMode: UnlockRuleMode;
      lessonIds: string[];
    }) =>
      apiFetch<StandaloneLocationResponse>(
        `/admin/map-locations/${p.locationId}/unlock-lessons`,
        {
          method: "PUT",
          body: JSON.stringify({
            unlockRuleMode: p.unlockRuleMode,
            lessonIds: p.lessonIds,
          }),
        },
      ),
    onSuccess: () => {
      setError(null);
      setSelectedLocId("");
      void qc.invalidateQueries({ queryKey: ["map-locations"] });
    },
    onError: (err) => setError(toUserMessage(err)),
  });

  return (
    <section
      aria-labelledby="lesson-unlocked-locations-heading"
      className="space-y-3 rounded-md border border-border bg-white p-3"
    >
      <div className="flex items-center justify-between gap-2">
        <h3
          id="lesson-unlocked-locations-heading"
          className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider text-brand"
        >
          <MapPin className="size-3.5" aria-hidden />
          Địa điểm mở khóa ({linkedLocations.length})
        </h3>
        <Link
          href={`/map-locations?eventId=${eventId}`}
          className="inline-flex items-center gap-1 text-[11px] font-medium text-brand hover:underline"
        >
          Quản lý bản đồ
          <ExternalLink className="size-3" aria-hidden />
        </Link>
      </div>

      <p className="text-xs text-ink-muted">
        Phần thưởng khám phá sau khi học (tùy chọn): các địa điểm di tích lịch
        sử sẽ mở khóa cho học viên khi hoàn thành bài học này. Bài học không
        gắn địa điểm vẫn chạy và mở khóa bài tiếp theo bình thường trên Bản đồ
        Dấu Ấn.
      </p>

      {error && (
        <p role="alert" className="rounded bg-error/10 px-2.5 py-1.5 text-xs text-error">
          {error}
        </p>
      )}

      {linkedLocations.length === 0 ? (
        <p className="rounded border border-dashed border-border px-3 py-3 text-center text-xs text-ink-muted">
          Bài học này chưa gắn địa điểm mở khóa nào — không bắt buộc: bài học
          hoạt động độc lập trên Bản đồ Dấu Ấn.
        </p>
      ) : (
        <ul className="space-y-2">
          {linkedLocations.map((loc) => {
            const thumb =
              loc.media.find((m) => m.externalUrl)?.externalUrl ??
              resolveHeritageFallbackIllustration(loc.slug, loc.title);
            return (
              <li
                key={loc.id}
                className="flex items-start gap-2.5 rounded-md border border-border bg-surface p-2"
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={thumb}
                  alt={loc.title}
                  className="size-11 shrink-0 rounded object-cover"
                />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-1">
                    <Link
                      href={`/map-locations?highlight=${loc.id}`}
                      className="truncate text-xs font-semibold text-ink hover:text-brand hover:underline"
                    >
                      {loc.title}
                    </Link>
                    <StatusChip status={loc.status} />
                  </div>
                  <p className="mt-0.5 text-[11px] text-ink-muted">
                    {LOCATION_KIND_LABELS[loc.kind] ?? loc.kind}
                    {(() => {
                      const firstEvent = loc.events[0];
                      return firstEvent
                        ? ` • hiện cạnh sự kiện "${firstEvent.title}" trên Bản đồ Dấu Ấn`
                        : "";
                    })()}
                  </p>
                  <div className="mt-1 flex items-center justify-between gap-1">
                    <span className="inline-flex items-center gap-1 rounded bg-warning/20 px-1.5 py-0.5 text-[10px] font-semibold text-ink">
                      <Lock className="size-2.5" aria-hidden />
                      {loc.unlockRuleMode === "ALL"
                        ? `Cần đủ ${loc.unlockLessons.length} bài (ALL)`
                        : "Mở ngay khi xong bài này (ANY)"}
                    </span>
                    {!readOnly && (
                      <button
                        type="button"
                        disabled={updateUnlockRuleMutation.isPending}
                        onClick={() => {
                          const remainingIds = loc.unlockLessons
                            .map((u) => u.lessonId)
                            .filter((id) => id !== lessonId);
                          updateUnlockRuleMutation.mutate({
                            locationId: loc.id,
                            unlockRuleMode:
                              remainingIds.length === 0 ? "NONE" : loc.unlockRuleMode,
                            lessonIds: remainingIds,
                          });
                        }}
                        title="Gỡ bài học này khỏi điều kiện mở khóa địa điểm"
                        aria-label={`Gỡ liên kết mở khóa ${loc.title}`}
                        className="cursor-pointer rounded p-1 text-ink-muted hover:bg-white hover:text-error"
                      >
                        <Trash2 className="size-3.5" aria-hidden />
                      </button>
                    )}
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      )}

      {!readOnly && attachableLocations.length > 0 && (
        <div className="space-y-2 border-t border-border pt-2.5">
          <p className="text-[11px] font-medium text-ink">
            Gắn bài học này để mở khóa thêm địa điểm:
          </p>
          <Select
            value={selectedLocId}
            onChange={(e) => setSelectedLocId(e.target.value)}
            aria-label="Chọn địa điểm di tích để gắn mở khóa"
            className="h-8 text-xs"
          >
            <option value="">— Chọn địa điểm di tích —</option>
            {attachableLocations.map((loc) => {
              const isSameEvent =
                loc.eventId === eventId ||
                loc.events.some((ev) => ev.eventId === eventId);
              return (
                <option key={loc.id} value={loc.id}>
                  {isSameEvent ? "★ " : ""}
                  {loc.title} ({LOCATION_KIND_LABELS[loc.kind] ?? loc.kind})
                </option>
              );
            })}
          </Select>

          {selectedLocId && (
            <div className="flex items-center gap-1.5">
              <Select
                value={selectedMode}
                onChange={(e) => setSelectedMode(e.target.value as UnlockRuleMode)}
                aria-label="Chế độ mở khóa"
                className="h-8 flex-1 text-xs"
              >
                <option value="ANY">ANY (Xong bài này là mở)</option>
                <option value="ALL">ALL (Cần xong tất cả bài gắn)</option>
              </Select>
              <Button
                type="button"
                size="sm"
                variant="secondary"
                className="h-8 px-2.5 text-xs"
                disabled={updateUnlockRuleMutation.isPending}
                onClick={() => {
                  const target = allLocations.find((l) => l.id === selectedLocId);
                  if (!target) return;
                  const existingIds = target.unlockLessons.map((u) => u.lessonId);
                  const nextIds = existingIds.includes(lessonId)
                    ? existingIds
                    : [...existingIds, lessonId];
                  updateUnlockRuleMutation.mutate({
                    locationId: target.id,
                    unlockRuleMode: selectedMode === "NONE" ? "ANY" : selectedMode,
                    lessonIds: nextIds,
                  });
                }}
              >
                <Plus className="size-3.5" aria-hidden />
                Gắn
              </Button>
            </div>
          )}
        </div>
      )}
    </section>
  );
}
