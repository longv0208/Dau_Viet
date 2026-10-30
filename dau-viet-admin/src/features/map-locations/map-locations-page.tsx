"use client";

import { skipToken, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import dynamic from "next/dynamic";
import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  BookOpen,
  Calendar,
  CheckCircle2,
  Film,
  FolderOpen,
  Image as ImageIcon,
  Layers,
  Lock,
  Map as MapIcon,
  MapPin,
  Pencil,
  Plus,
  ArrowUp,
  ArrowDown,
  Star,
  Search,
  Sparkles,
  Trash2,
  Unlock,
  Upload,
  X,
} from "lucide-react";
import { apiFetch, toQuery } from "@/lib/api-client";
import { qk } from "@/lib/query-keys";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { AdminAsset } from "@/lib/dto/evidence";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import {
  COORDINATE_PRECISION_LABELS,
  type CoordinatePrecision,
  type EventLinkInput,
  HERITAGE_PRESET_ILLUSTRATIONS,
  HERITAGE_PRESET_MAPS,
  LOCATION_KIND_LABELS,
  LOCATION_VISIBILITY_LABELS,
  type LocationMediaType,
  type LocationMediaVisibility,
  type MapLocationEventRole,
  type MapLocationKind,
  type MapLocationStatus,
  type MapLocationVisibility,
  MEDIA_TYPE_LABELS,
  MEDIA_VISIBILITY_LABELS,
  type MediaInput,
  resolveHeritageFallbackIllustration,
  resolveLocationMapPreset,
  resolvePresetIllustrationByAssetId,
  resolvePresetMapByAssetId,
  type StandaloneLocationRequest,
  type StandaloneLocationResponse,
  UNLOCK_RULE_MODE_LABELS,
  type UnlockRuleMode,
} from "@/lib/dto/map-location";
import { cn } from "@/lib/utils";
import { ClueTag } from "@/components/atoms/clue-tag";
import { EmptyStateCard } from "@/components/atoms/empty-state-card";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { SectionEyebrow } from "@/components/atoms/section-eyebrow";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";
import { ErrorState } from "@/components/error-state";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";
import { uploadAsset, validateAssetFile } from "@/features/assets/asset-api";
import { useAssetObjectUrl } from "@/features/assets/use-asset-object-url";
const LatLngMapPicker = dynamic(
  () =>
    import("@/features/events/lat-lng-map-picker").then((m) => ({
      default: m.LatLngMapPicker,
    })),
  { ssr: false, loading: () => <Skeleton className="h-72 w-full" /> },
);

type WorkspaceTab = "metadata" | "events" | "unlock" | "media";

function slugifyVi(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120);
}

function formatCoordinateDisplay(lat: number, lng: number): string {
  if (lng > 100 && lat >= -90 && lat <= 90) {
    return `${Number(lat.toFixed(4))}°N, ${Number(lng.toFixed(4))}°E`;
  }
  return `${Number(lat.toFixed(2))}%, ${Number(lng.toFixed(2))}%`;
}

function LocationCardThumbnail({ loc }: { loc: StandaloneLocationResponse }) {
  const presetCover = resolvePresetIllustrationByAssetId(loc.coverAssetId);
  const presetMapAsCover = resolvePresetMapByAssetId(loc.coverAssetId);
  const mediaExternalUrl = loc.media.find((m) => m.externalUrl)?.externalUrl ?? null;
  const mediaAssetId = loc.media.find((m) => m.assetId)?.assetId ?? null;
  const presetMedia = resolvePresetIllustrationByAssetId(mediaAssetId);

  const customAssetId =
    loc.coverAssetId && !presetCover && !presetMapAsCover
      ? loc.coverAssetId
      : !loc.coverAssetId && !mediaExternalUrl && mediaAssetId && !presetMedia
        ? mediaAssetId
        : null;

  const contentUrl = customAssetId
    ? `/api/v1/admin/assets/${customAssetId}/content`
    : null;
  const { src: customObjectUrl } = useAssetObjectUrl(contentUrl);

  const resolvedSrc =
    customObjectUrl ??
    presetCover?.url ??
    presetMapAsCover?.url ??
    mediaExternalUrl ??
    presetMedia?.url ??
    resolveHeritageFallbackIllustration(loc.slug, loc.title);

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={resolvedSrc}
      alt={loc.title}
      className="size-full object-cover"
      loading="lazy"
    />
  );
}

function MediaItemThumbnail({ item }: { item: MediaInput }) {
  const directSrc = item.externalUrl?.trim() || null;
  const contentUrl = item.assetId ? `/api/v1/admin/assets/${item.assetId}/content` : null;
  const { src: objectUrl } = useAssetObjectUrl(contentUrl);
  const src = objectUrl ?? directSrc;
  if (!src) {
    return (
      <div className="flex size-16 shrink-0 items-center justify-center rounded-lg border border-dashed border-border bg-surface-alt text-ink-muted">
        <ImageIcon className="size-5" aria-hidden />
      </div>
    );
  }
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={src}
      alt={item.title || "Tư liệu địa điểm"}
      className="size-16 shrink-0 rounded-lg border border-border object-cover"
      loading="lazy"
    />
  );
}

export function MapLocationsWorkspace() {
  const qc = useQueryClient();
  const searchParams = useSearchParams();
  const initialEventId = searchParams.get("eventId") ?? "";
  const initialHighlightId = searchParams.get("highlight") ?? "";

  const [q, setQ] = useState("");
  const [kindFilter, setKindFilter] = useState<string>("");
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [eventFilter, setEventFilter] = useState<string>(initialEventId);
  const [page, setPage] = useState(0);
  const pageSize = 8;

  const [selectedId, setSelectedId] = useState<string | "new" | null>(
    initialHighlightId || null,
  );
  const [activeTab, setActiveTab] = useState<WorkspaceTab>("metadata");
  const [bannerMessage, setBannerMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);

  const filterParams = useMemo(
    () => ({
      page,
      size: pageSize,
      q: q.trim() || undefined,
      kind: kindFilter || undefined,
      status: statusFilter || undefined,
      eventId: eventFilter || undefined,
    }),
    [page, pageSize, q, kindFilter, statusFilter, eventFilter],
  );

  const locationsQuery = useQuery({
    queryKey: qk.mapLocations.standaloneList(filterParams),
    queryFn: () =>
      apiFetch<PageResponse<StandaloneLocationResponse> | StandaloneLocationResponse[]>(
        `/admin/map-locations${toQuery(filterParams)}`,
      ),
  });

  const eventsQuery = useQuery({
    queryKey: qk.events.list({ page: 0, size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminEventSummary>>(
        `/admin/events${toQuery({ page: 0, size: 100 })}`,
      ),
    staleTime: 60_000,
  });

  const lessonsQuery = useQuery({
    queryKey: ["lessons", "all-for-heritage-locations"],
    queryFn: async () => {
      const pageSize = 100;
      const first = await apiFetch<PageResponse<AdminLessonSummary>>(
        `/admin/lessons${toQuery({ size: pageSize, page: 0 })}`,
      );
      const rest = await Promise.all(
        Array.from({ length: Math.max(0, first.totalPages - 1) }, (_, i) =>
          apiFetch<PageResponse<AdminLessonSummary>>(
            `/admin/lessons${toQuery({ size: pageSize, page: i + 1 })}`,
          ),
        ),
      );
      return rest.reduce<AdminLessonSummary[]>(
        (acc, p) => acc.concat(p.content),
        [...first.content],
      );
    },
    staleTime: 60_000,
  });

  const locations = useMemo(() => {
    const raw = locationsQuery.data;
    if (!raw) return [];
    return Array.isArray(raw) ? raw : raw.content;
  }, [locationsQuery.data]);
  const totalLocations = useMemo(() => {
    const raw = locationsQuery.data;
    if (!raw) return 0;
    return Array.isArray(raw) ? raw.length : raw.totalElements;
  }, [locationsQuery.data]);
  const totalPages = useMemo(() => {
    const raw = locationsQuery.data;
    if (!raw) return 1;
    return Math.max(1, Array.isArray(raw) ? 1 : raw.totalPages);
  }, [locationsQuery.data]);
  const allEvents = useMemo(() => eventsQuery.data?.content ?? [], [eventsQuery.data]);
  const allLessons = useMemo(() => lessonsQuery.data ?? [], [lessonsQuery.data]);

  const selectedInPage = useMemo(() => {
    if (!selectedId || selectedId === "new") return null;
    return locations.find((l) => l.id === selectedId) ?? null;
  }, [locations, selectedId]);

  const selectedDetailQuery = useQuery({
    queryKey: qk.mapLocations.standaloneDetail(
      selectedId && selectedId !== "new" ? selectedId : "none",
    ),
    queryFn:
      selectedId && selectedId !== "new" && !selectedInPage
        ? () => apiFetch<StandaloneLocationResponse>(`/admin/map-locations/${selectedId}`)
        : skipToken,
  });

  const selectedLocation = useMemo(() => {
    if (!selectedId || selectedId === "new") return null;
    return selectedInPage ?? selectedDetailQuery.data ?? null;
  }, [selectedId, selectedInPage, selectedDetailQuery.data]);

  const setStatusMutation = useMutation({
    mutationFn: (p: { loc: StandaloneLocationResponse; status: MapLocationStatus }) =>
      apiFetch<StandaloneLocationResponse>(
        `/admin/map-locations/${p.loc.id}/status${toQuery({
          status: p.status,
          expectedRowVersion: p.loc.rowVersion,
        })}`,
        { method: "POST" },
      ),
    onSuccess: (updated) => {
      void qc.invalidateQueries({ queryKey: ["map-locations"] });
      setBannerMessage({
        type: "success",
        text: `Đã cập nhật trạng thái "${updated.title}" sang ${updated.status}.`,
      });
    },
    onError: (err) => {
      if (err instanceof ApiClientError && err.isConflict) {
        void qc.invalidateQueries({ queryKey: ["map-locations"] });
      }
      setBannerMessage({ type: "error", text: toUserMessage(err) });
    },
  });

  return (
    <div className="space-y-5">
      {/* Thanh công cụ tìm kiếm & bộ lọc */}
      <PaperCard
        aria-label="Bộ lọc địa điểm di tích"
        className="p-4"
      >
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div className="grid min-w-0 flex-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <Label htmlFor="filter-q" className="font-medium text-ink-secondary">Tìm theo tên / slug</Label>
              <div className="relative mt-1">
                <Search
                  className="pointer-events-none absolute left-2.5 top-2.5 size-4 text-ink-muted"
                  aria-hidden
                />
                <Input
                  id="filter-q"
                  value={q}
                  onChange={(e) => {
                    setQ(e.target.value);
                    setPage(0);
                  }}
                  placeholder="Bạch Đằng, Hoàng thành..."
                  className="pl-8"
                />
              </div>
            </div>

            <div>
              <Label htmlFor="filter-kind" className="font-medium text-ink-secondary">Loại hình di tích</Label>
              <Select
                id="filter-kind"
                className="mt-1"
                value={kindFilter}
                onChange={(e) => {
                  setKindFilter(e.target.value);
                  setPage(0);
                }}
              >
                <option value="">Tất cả loại hình</option>
                {(Object.keys(LOCATION_KIND_LABELS) as MapLocationKind[]).map((k) => (
                  <option key={k} value={k}>
                    {LOCATION_KIND_LABELS[k]}
                  </option>
                ))}
              </Select>
            </div>

            <div>
              <Label htmlFor="filter-status" className="font-medium text-ink-secondary">Trạng thái xuất bản</Label>
              <Select
                id="filter-status"
                className="mt-1"
                value={statusFilter}
                onChange={(e) => {
                  setStatusFilter(e.target.value);
                  setPage(0);
                }}
              >
                <option value="">Tất cả trạng thái</option>
                <option value="DRAFT">Bản nháp (DRAFT)</option>
                <option value="PUBLISHED">Đã xuất bản (PUBLISHED)</option>
                <option value="ARCHIVED">Đã lưu trữ (ARCHIVED)</option>
              </Select>
            </div>

            <div>
              <Label htmlFor="filter-event" className="font-medium text-ink-secondary">Sự kiện liên kết</Label>
              <Select
                id="filter-event"
                className="mt-1"
                value={eventFilter}
                onChange={(e) => {
                  setEventFilter(e.target.value);
                  setPage(0);
                }}
              >
                <option value="">Tất cả sự kiện</option>
                {allEvents.map((ev) => (
                  <option key={ev.id} value={ev.id}>
                    {ev.title}
                  </option>
                ))}
              </Select>
            </div>
          </div>

          <Button
            type="button"
            onClick={() => {
              setSelectedId("new");
              setActiveTab("metadata");
              setBannerMessage(null);
            }}
          >
            <Plus className="size-4" aria-hidden />
            Thêm địa điểm di tích
          </Button>
        </div>
      </PaperCard>

      {bannerMessage && (
        <div
          role={bannerMessage.type === "error" ? "alert" : "status"}
          className={cn(
            "flex items-center justify-between gap-3 rounded-lg border px-4 py-2.5 text-sm",
            bannerMessage.type === "error"
              ? "border-error/30 bg-error/10 text-error"
              : "border-success/30 bg-success/10 text-ink",
          )}
        >
          <span className="flex items-center gap-2">
            {bannerMessage.type === "success" && (
              <CheckCircle2 className="size-4 shrink-0 text-success" aria-hidden />
            )}
            {bannerMessage.text}
          </span>
          <button
            type="button"
            onClick={() => setBannerMessage(null)}
            aria-label="Đóng thông báo"
            className="cursor-pointer rounded p-1 text-ink-muted hover:bg-surface"
          >
            <X className="size-4" aria-hidden />
          </button>
        </div>
      )}

      {/* Bố cục 2 cột: Danh sách thẻ bên trái + Không gian biên tập 4 tab bên phải */}
      <div className="grid items-start gap-5 xl:grid-cols-[minmax(22rem,1fr)_minmax(30rem,1.35fr)]">
        {/* Cột trái: Danh sách Địa điểm */}
        <section aria-label="Danh sách địa điểm di tích" className="space-y-3">
          <SectionDivider
            eyebrow="DANH MỤC"
            title={`Danh mục địa điểm (${totalLocations})`}
            action={
              q || kindFilter || statusFilter || eventFilter ? (
                <ClueTag
                  label="Xóa bộ lọc"
                  color="brand"
                  onClick={() => {
                    setQ("");
                    setKindFilter("");
                    setStatusFilter("");
                    setEventFilter("");
                    setPage(0);
                  }}
                />
              ) : undefined
            }
          />

          {locationsQuery.isPending && (
            <div className="space-y-3">
              <Skeleton className="h-32 w-full rounded-xl" />
              <Skeleton className="h-32 w-full rounded-xl" />
              <Skeleton className="h-32 w-full rounded-xl" />
            </div>
          )}

          {locationsQuery.isError && (
            <ErrorState
              error={locationsQuery.error}
              onRetry={() => void locationsQuery.refetch()}
            />
          )}

          {locationsQuery.isSuccess && locations.length === 0 && (
            <EmptyStateCard
              icon={MapPin}
              title="Chưa tìm thấy địa điểm di tích nào khớp bộ lọc"
              description="Tạo địa điểm di tích mới để liên kết đa sự kiện, cấu hình mở khóa đa bài học và thư viện media."
              action={
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  className="mt-2"
                  onClick={() => {
                    setSelectedId("new");
                    setActiveTab("metadata");
                  }}
                >
                  <Plus className="size-4" aria-hidden />
                  Tạo địa điểm đầu tiên
                </Button>
              }
            />
          )}

          <div className="space-y-3">
            {locations.map((loc) => {
              const isSelected = selectedId === loc.id;

              return (
                <PaperCard
                  key={loc.id}
                  interactive
                  className={cn(
                    "overflow-hidden",
                    isSelected
                      ? "border-brand ring-2 ring-brand/25"
                      : "border-border hover:border-brand/40",
                  )}
                >
                  <div className="flex flex-col sm:flex-row">
                    <button
                      type="button"
                      onClick={() => {
                        setSelectedId(loc.id);
                        setBannerMessage(null);
                      }}
                      className="relative h-32 w-full shrink-0 cursor-pointer overflow-hidden rounded-t border-b border-border bg-surface-alt sm:h-auto sm:w-40 sm:rounded-l sm:rounded-tr-none sm:border-b-0 sm:border-r"
                    >
                      <LocationCardThumbnail loc={loc} />
                      <span className="absolute bottom-1.5 left-1.5 rounded bg-black/70 px-1.5 py-0.5 text-[10px] font-medium text-white">
                        {LOCATION_KIND_LABELS[loc.kind] ?? loc.kind}
                      </span>
                    </button>
                    <div className="flex min-w-0 flex-1 flex-col justify-between p-3.5">
                      <div>
                        <div className="flex flex-wrap items-start justify-between gap-2">
                          <button
                            type="button"
                            onClick={() => {
                              setSelectedId(loc.id);
                              setBannerMessage(null);
                            }}
                            className="min-w-0 flex-1 cursor-pointer text-left"
                          >
                            <h3 className="truncate font-display text-base font-semibold text-ink hover:text-brand">
                              {loc.title}
                            </h3>
                            <p className="truncate text-xs text-ink-muted">
                              Slug: <code className="font-mono">{loc.slug ?? "chưa đặt"}</code> · Tọa độ:{" "}
                              {formatCoordinateDisplay(loc.latitude, loc.longitude)}
                            </p>
                          </button>
                          <StatusChip status={loc.status} />
                        </div>

                        {loc.shortSummary && (
                          <p className="mt-1.5 line-clamp-2 text-xs text-ink-muted">
                            {loc.shortSummary}
                          </p>
                        )}
                      </div>

                      <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-border pt-2.5 text-xs text-ink-muted">
                        <div className="flex flex-wrap items-center gap-3">
                          <span className="inline-flex items-center gap-1" title="Số sự kiện liên kết">
                            <Calendar className="size-3.5 text-brand" aria-hidden />
                            {loc.events.length} sự kiện
                          </span>
                          <span className="inline-flex items-center gap-1" title="Quy tắc mở khóa">
                            {loc.unlockRuleMode === "NONE" || loc.unlockLessons.length === 0 ? (
                              <Unlock className="size-3.5 text-success" aria-hidden />
                            ) : (
                              <Lock className="size-3.5 text-warning" aria-hidden />
                            )}
                            {loc.unlockRuleMode === "NONE"
                              ? "Luôn mở"
                              : loc.unlockLessons.length === 0
                                ? "Mở sẵn (0 bài)"
                                : `${loc.unlockRuleMode} (${loc.unlockLessons.length} bài)`}
                          </span>
                          <span className="inline-flex items-center gap-1" title="Số tư liệu media">
                            <Film className="size-3.5 text-ink-muted" aria-hidden />
                            {loc.media.length} media
                          </span>
                        </div>

                        <div className="flex items-center gap-1.5">
                          <Button
                            type="button"
                            variant="secondary"
                            size="sm"
                            className="h-7 px-2.5 text-xs"
                            onClick={() => {
                              setSelectedId(loc.id);
                              setBannerMessage(null);
                            }}
                          >
                            <Pencil className="size-3" aria-hidden />
                            Thiết kế
                          </Button>
                          {loc.status !== "PUBLISHED" ? (
                            <Button
                              type="button"
                              variant="secondary"
                              size="sm"
                              className="h-7 px-2.5 text-xs"
                              disabled={setStatusMutation.isPending}
                              onClick={() =>
                                setStatusMutation.mutate({ loc, status: "PUBLISHED" })
                              }
                            >
                              Xuất bản
                            </Button>
                          ) : (
                            <Button
                              type="button"
                              variant="ghost"
                              size="sm"
                              className="h-7 px-2 text-xs"
                              disabled={setStatusMutation.isPending}
                              onClick={() =>
                                setStatusMutation.mutate({ loc, status: "ARCHIVED" })
                              }
                            >
                              Lưu trữ
                            </Button>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                </PaperCard>
              );
            })}
          </div>

          {totalLocations > 0 && (
            <PaperCard className="flex items-center justify-between px-3.5 py-2.5 text-sm text-ink-muted">
              <span>
                Trang {page + 1} / {totalPages} · {totalLocations} địa điểm
              </span>
              <div className="flex gap-2">
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={page <= 0}
                  onClick={() => setPage((p) => p - 1)}
                >
                  Trước
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={page + 1 >= totalPages}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Sau
                </Button>
              </div>
            </PaperCard>
          )}
        </section>

        {/* Cột phải: Không gian Biên tập 4 Tab */}
        <PaperCard
          aria-label="Chi tiết và cấu hình địa điểm di tích"
          className="sticky top-20 overflow-hidden"
        >
          {selectedId === null ? (
            <EmptyStateCard
              icon={MapPin}
              title="Chọn một Địa điểm Di tích để thiết kế"
              description="Quản lý thông tin tọa độ bản đồ, liên kết đa sự kiện lịch sử (PRIMARY / RELATED), điều kiện mở khóa đa bài học (NONE / ANY / ALL) và thư viện Media tư liệu."
              action={
                <Button
                  type="button"
                  className="mt-2"
                  onClick={() => {
                    setSelectedId("new");
                    setActiveTab("metadata");
                  }}
                >
                  <Plus className="size-4" aria-hidden />
                  Tạo địa điểm mới
                </Button>
              }
              className="border-0 shadow-none"
            />
          ) : selectedId !== "new" && !selectedLocation && selectedDetailQuery.isPending ? (
            <div className="space-y-3 p-5">
              <Skeleton className="h-8 w-56" />
              <Skeleton className="h-64 w-full" />
            </div>
          ) : (
            <LocationDetailEditor
              key={selectedId === "new" ? "new" : `${selectedLocation?.id}:${selectedLocation?.rowVersion}`}
              location={selectedId === "new" ? null : selectedLocation}
              allEvents={allEvents}
              allLessons={allLessons}
              activeTab={activeTab}
              onTabChange={setActiveTab}
              onCreated={(created) => {
                qc.setQueryData(qk.mapLocations.standaloneDetail(created.id), created);
                void qc.invalidateQueries({ queryKey: ["map-locations"] });
                setSelectedId(created.id);
                setBannerMessage({
                  type: "success",
                  text: `Đã tạo địa điểm "${created.title}". Bạn có thể tiếp tục gắn Sự kiện, Bài học mở khóa và Media ở các tab bên cạnh.`,
                });
              }}
              onUpdated={(updated, msg) => {
                qc.setQueryData(qk.mapLocations.standaloneDetail(updated.id), updated);
                void qc.invalidateQueries({ queryKey: ["map-locations"] });
                setBannerMessage({ type: "success", text: msg });
              }}
              onClose={() => setSelectedId(null)}
            />
          )}
        </PaperCard>
      </div>
    </div>
  );
}

function LocationDetailEditor({
  location,
  allEvents,
  allLessons,
  activeTab,
  onTabChange,
  onCreated,
  onUpdated,
  onClose,
}: {
  location: StandaloneLocationResponse | null;
  allEvents: AdminEventSummary[];
  allLessons: AdminLessonSummary[];
  activeTab: WorkspaceTab;
  onTabChange: (tab: WorkspaceTab) => void;
  onCreated: (created: StandaloneLocationResponse) => void;
  onUpdated: (updated: StandaloneLocationResponse, message: string) => void;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const isNew = location === null;
  const [error, setError] = useState<string | null>(null);
  const coverFileInputRef = useRef<HTMLInputElement>(null);
  const mapFileInputRef = useRef<HTMLInputElement>(null);

  // Tab 1: Metadata state
  const [title, setTitle] = useState(location?.title ?? "");
  const [slug, setSlug] = useState(location?.slug ?? "");
  const [shortSummary, setShortSummary] = useState(location?.shortSummary ?? "");
  const [description, setDescription] = useState(location?.description ?? "");
  const [keyFigures, setKeyFigures] = useState(location?.keyFigures ?? "");
  const [storyNarrative, setStoryNarrative] = useState(location?.storyNarrative ?? "");
  const [historicalSignificance, setHistoricalSignificance] = useState(
    location?.historicalSignificance ?? "",
  );
  const [kind, setKind] = useState<MapLocationKind>(location?.kind ?? "HERITAGE_SITE");
  const [latitude, setLatitude] = useState(String(location?.latitude ?? 50));
  const [longitude, setLongitude] = useState(String(location?.longitude ?? 50));
  const [coordinatePrecision, setCoordinatePrecision] = useState<CoordinatePrecision>(
    location?.coordinatePrecision ?? "EXACT",
  );
  const [visibility, setVisibility] = useState<MapLocationVisibility>(
    location?.visibility ?? "ALWAYS_VISIBLE",
  );
  const unlockRuleMode: UnlockRuleMode = location?.unlockRuleMode ?? "NONE";
  const [displayOrder, setDisplayOrder] = useState(String(location?.displayOrder ?? 0));
  const [coverAssetId, setCoverAssetId] = useState<string | null>(
    location?.coverAssetId ?? null,
  );
  const [coverPickerOpen, setCoverPickerOpen] = useState(false);
  const [uploadingCover, setUploadingCover] = useState(false);
  const [coverUploadError, setCoverUploadError] = useState<string | null>(null);

  const [mapAssetId, setMapAssetId] = useState<string | null>(
    location?.mapAssetId ?? null,
  );
  const [mapPickerOpen, setMapPickerOpen] = useState(false);
  const [uploadingMap, setUploadingMap] = useState(false);
  const [mapUploadError, setMapUploadError] = useState<string | null>(null);
  const [eventLinks, setEventLinks] = useState<EventLinkInput[]>(() =>
    (location?.events ?? []).map((e) => ({
      eventId: e.eventId,
      role: e.role,
      sortOrder: e.sortOrder,
    })),
  );
  const [addingEventId, setAddingEventId] = useState("");
  const [addingEventRole, setAddingEventRole] = useState<MapLocationEventRole>("PRIMARY");

  // Tab 3: Unlock lessons state
  const [ruleModeTab, setRuleModeTab] = useState<UnlockRuleMode>(
    location?.unlockRuleMode ?? "NONE",
  );
  const [selectedLessonIds, setSelectedLessonIds] = useState<string[]>(() =>
    (location?.unlockLessons ?? []).map((l) => l.lessonId),
  );
  const [lessonSearch, setLessonSearch] = useState("");

  // Tab 4: Media state
  const [mediaItems, setMediaItems] = useState<MediaInput[]>(() =>
    (location?.media ?? []).map((m, idx) => ({
      mediaType: m.mediaType,
      title: m.title ?? "",
      caption: m.caption ?? "",
      assetId: m.assetId,
      assetUrl: m.assetUrl ?? "",
      externalUrl: m.externalUrl ?? "",
      visibility: m.visibility,
      sortOrder: m.sortOrder ?? idx,
      sourceCitation: m.sourceCitation ?? "",
    })),
  );
  const [mediaAssetPickerIdx, setMediaAssetPickerIdx] = useState<number | null>(null);

  const [mediaUploadingIdx, setMediaUploadingIdx] = useState<number | null>(null);
  useEffect(() => {
    setError(null);
  }, [activeTab]);

  const saveMetadataMutation = useMutation({
    mutationFn: async () => {
      const lat = Number(latitude);
      const lng = Number(longitude);
      if (!title.trim()) throw new Error("Vui lòng nhập tên địa điểm di tích.");
      if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
        throw new Error("Vĩ độ / vị trí dọc phải nằm trong khoảng hợp lệ.");
      }
      if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
        throw new Error("Kinh độ / vị trí ngang phải nằm trong khoảng hợp lệ.");
      }
      const payload: StandaloneLocationRequest = {
        slug: slug.trim() || slugifyVi(title),
        title: title.trim(),
        shortSummary: shortSummary.trim() || null,
        description: description.trim() || null,
        kind,
        latitude: lat,
        longitude: lng,
        coordinatePrecision,
        visibility,
        unlockRuleMode,
        coverAssetId,
        mapAssetId,
        displayOrder: Number.isFinite(Number(displayOrder)) ? Number(displayOrder) : 0,
        keyFigures: keyFigures.trim() || null,
        storyNarrative: storyNarrative.trim() || null,
        historicalSignificance: historicalSignificance.trim() || null,
      };
      if (isNew) {
        return apiFetch<StandaloneLocationResponse>(`/admin/map-locations`, {
          method: "POST",
          body: JSON.stringify(payload),
        });
      }
      return apiFetch<StandaloneLocationResponse>(
        `/admin/map-locations/${location.id}${toQuery({
          expectedRowVersion: location.rowVersion,
        })}`,
        {
          method: "PATCH",
          body: JSON.stringify(payload),
        },
      );
    },
    onSuccess: (res) => {
      setError(null);
      if (isNew) onCreated(res);
      else onUpdated(res, `Đã lưu thông tin cơ bản cho "${res.title}".`);
    },
    onError: (err) => setError(toUserMessage(err)),
  });

  const saveEventsMutation = useMutation({
    mutationFn: async () => {
      if (!location) throw new Error("Cần lưu địa điểm trước.");
      return apiFetch<StandaloneLocationResponse>(
        `/admin/map-locations/${location.id}/events`,
        {
          method: "PUT",
          body: JSON.stringify(
            eventLinks.map((e, i) => ({
              eventId: e.eventId,
              role: e.role,
              sortOrder: Number.isFinite(e.sortOrder) ? e.sortOrder : i,
            })),
          ),
        },
      );
    },
    onSuccess: (res) => {
      setError(null);
      onUpdated(res, `Đã cập nhật ${res.events.length} sự kiện liên kết cho "${res.title}".`);
    },
    onError: (err) => setError(toUserMessage(err)),
  });

  const saveUnlockMutation = useMutation({
    mutationFn: async () => {
      if (!location) throw new Error("Cần lưu địa điểm trước.");
      return apiFetch<StandaloneLocationResponse>(
        `/admin/map-locations/${location.id}/unlock-lessons`,
        {
          method: "PUT",
          body: JSON.stringify({
            unlockRuleMode: ruleModeTab,
            lessonIds: ruleModeTab === "NONE" ? [] : selectedLessonIds,
          }),
        },
      );
    },
    onSuccess: (res) => {
      setError(null);
      onUpdated(
        res,
        `Đã lưu quy tắc mở khóa (${res.unlockRuleMode}) với ${res.unlockLessons.length} bài học.`,
      );
    },
    onError: (err) => setError(toUserMessage(err)),
  });

  const saveMediaMutation = useMutation({
    mutationFn: async () => {
      if (!location) throw new Error("Cần lưu địa điểm trước.");
      return apiFetch<StandaloneLocationResponse>(
        `/admin/map-locations/${location.id}/media`,
        {
          method: "PUT",
          body: JSON.stringify(
            mediaItems.map((m, idx) => ({
              mediaType: m.mediaType,
              title: m.title?.trim() || `Tư liệu #${idx + 1}`,
              caption: m.caption?.trim() || null,
              assetId: m.assetId || null,
              externalUrl: m.externalUrl?.trim() || null,
              visibility: m.visibility,
              sortOrder: idx,
              sourceCitation: m.sourceCitation?.trim() || null,
            })),
          ),
        },
      );
    },
    onSuccess: (res) => {
      setError(null);
      onUpdated(res, `Đã lưu ${res.media.length} tư liệu media cho "${res.title}".`);
    },
    onError: (err) => setError(toUserMessage(err)),
  });

  const pickerCoords = useMemo(() => {
    const lat = Number(latitude);
    const lng = Number(longitude);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return { lat, lng };
    }
    return null;
  }, [latitude, longitude]);

  // Resolve active cover image preview
  const presetCover = useMemo(
    () => resolvePresetIllustrationByAssetId(coverAssetId),
    [coverAssetId],
  );
  const customCoverAssetId = coverAssetId && !presetCover ? coverAssetId : null;
  const { src: customCoverObjectUrl, loading: customCoverLoading } = useAssetObjectUrl(
    customCoverAssetId ? `/api/v1/admin/assets/${customCoverAssetId}/content` : null,
  );
  const coverAssetDetailQuery = useQuery({
    queryKey: qk.assets.detail(customCoverAssetId ?? "none"),
    queryFn: customCoverAssetId
      ? () => apiFetch<AdminAsset>(`/admin/assets/${customCoverAssetId}`)
      : skipToken,
  });
  const fallbackCoverUrl = useMemo(
    () =>
      mediaItems.find((m) => m.externalUrl)?.externalUrl ||
      resolveHeritageFallbackIllustration(slug, title),
    [mediaItems, slug, title],
  );
  const activeCoverPreviewSrc =
    customCoverObjectUrl ?? presetCover?.url ?? fallbackCoverUrl;

  // Resolve active map image for LatLngMapPicker & Map Image editor
  const presetMap = useMemo(() => resolvePresetMapByAssetId(mapAssetId), [mapAssetId]);
  const customMapAssetId = mapAssetId && !presetMap ? mapAssetId : null;
  const { src: customMapObjectUrl } = useAssetObjectUrl(
    customMapAssetId ? `/api/v1/admin/assets/${customMapAssetId}/content` : null,
  );
  const mapAssetDetailQuery = useQuery({
    queryKey: qk.assets.detail(customMapAssetId ?? "none"),
    queryFn: customMapAssetId
      ? () => apiFetch<AdminAsset>(`/admin/assets/${customMapAssetId}`)
      : skipToken,
  });
  const eventHints = useMemo(() => {
    const hints: string[] = [];
    for (const link of eventLinks) {
      hints.push(link.eventId);
      const ev = allEvents.find((e) => e.id === link.eventId);
      if (ev) {
        hints.push(ev.slug, ev.title);
      }
    }
    if (location?.eventId) {
      const primaryEv = allEvents.find((e) => e.id === location.eventId);
      if (primaryEv) {
        hints.push(primaryEv.slug, primaryEv.title);
      }
    }
    return hints;
  }, [eventLinks, allEvents, location?.eventId]);

  const resolvedMapPreset = useMemo(
    () =>
      resolveLocationMapPreset({
        mapAssetId,
        slug,
        title,
        eventId: location?.eventId,
        eventHints,
      }),
    [mapAssetId, slug, title, location?.eventId, eventHints],
  );

  const activeMapImageSrc = customMapObjectUrl ?? resolvedMapPreset.url;
  const activeMapImageLabel = customMapAssetId
    ? (mapAssetDetailQuery.data?.originalFilename ?? "Bản đồ tùy chỉnh đã tải lên")
    : resolvedMapPreset.title;

  async function handleDirectCoverUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const invalid = validateAssetFile(file);
    if (invalid) {
      setCoverUploadError(invalid);
      return;
    }
    setUploadingCover(true);
    setCoverUploadError(null);
    try {
      const created = await uploadAsset(file);
      await qc.invalidateQueries({ queryKey: ["assets"] });
      setCoverAssetId(created.id);
    } catch (err) {
      setCoverUploadError(toUserMessage(err));
    } finally {
      setUploadingCover(false);
    }
  }

  async function handleDirectMapUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const invalid = validateAssetFile(file);
    if (invalid) {
      setMapUploadError(invalid);
      return;
    }
    setUploadingMap(true);
    setMapUploadError(null);
    try {
      const created = await uploadAsset(file);
      await qc.invalidateQueries({ queryKey: ["assets"] });
      setMapAssetId(created.id);
    } catch (err) {
      setMapUploadError(toUserMessage(err));
    } finally {
      setUploadingMap(false);
    }
  }

  function moveMediaItem(from: number, to: number) {
    if (to < 0 || to >= mediaItems.length || from === to) return;
    setMediaItems((prev) => {
      const next = [...prev];
      const [moved] = next.splice(from, 1);
      if (moved) next.splice(to, 0, moved);
      return next.map((m, i) => ({ ...m, sortOrder: i }));
    });
  }

  async function handleMediaFileUpload(
    idx: number,
    e: React.ChangeEvent<HTMLInputElement>,
  ) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const invalid = validateAssetFile(file);
    if (invalid) {
      setError(invalid);
      return;
    }
    setMediaUploadingIdx(idx);
    setError(null);
    try {
      const uploaded = await uploadAsset(file);
      await qc.invalidateQueries({ queryKey: ["assets"] });
      setMediaItems((prev) =>
        prev.map((m, i) =>
          i === idx
            ? {
                ...m,
                assetId: uploaded.id,
                assetUrl: `/api/v1/assets/${uploaded.id}/content`,
                title: m.title || uploaded.originalFilename || "Tư liệu hình ảnh",
              }
            : m,
        ),
      );
    } catch (err) {
      setError(toUserMessage(err));
    } finally {
      setMediaUploadingIdx(null);
    }
  }

  const filteredLessons = useMemo(() => {
    const keyword = lessonSearch.trim().toLowerCase();
    if (!keyword) return allLessons;
    return allLessons.filter(
      (l) =>
        l.title.toLowerCase().includes(keyword) ||
        l.id.toLowerCase().includes(keyword),
    );
  }, [allLessons, lessonSearch]);

  const tabs: { key: WorkspaceTab; label: string; icon: typeof MapPin; disabled?: boolean }[] = [
    { key: "metadata", label: "1. Thông tin & Tọa độ", icon: MapPin },
    {
      key: "events",
      label: `2. Sự kiện (${eventLinks.length})`,
      icon: Calendar,
      disabled: isNew,
    },
    {
      key: "unlock",
      label: `3. Mở khóa (${ruleModeTab === "NONE" ? "Luôn mở" : selectedLessonIds.length})`,
      icon: BookOpen,
      disabled: isNew,
    },
    {
      key: "media",
      label: `4. Media (${mediaItems.length})`,
      icon: Layers,
      disabled: isNew,
    },
  ];

  return (
    <div className="flex flex-col">
      {/* Header */}
      <div className="flex items-start justify-between gap-3 border-b-2 border-heading bg-surface px-5 py-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <SectionEyebrow color="brand">
              {isNew ? "Tạo mới địa điểm" : "Không gian thiết kế địa điểm"}
            </SectionEyebrow>
            {location && <StatusChip status={location.status} />}
          </div>
          <h3 className="mt-2 truncate font-display text-lg font-semibold text-ink">
            {isNew ? "Địa điểm di tích lịch sử mới" : location.title}
          </h3>
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label="Đóng bảng thiết kế"
          className="cursor-pointer rounded-md p-1.5 text-ink-muted hover:bg-surface-alt hover:text-ink"
        >
          <X className="size-5" aria-hidden />
        </button>
      </div>

      {/* Tabs */}
      <div
        role="tablist"
        aria-label="Các mục cấu hình địa điểm"
        className="flex flex-wrap border-b border-border bg-surface-alt px-2"
      >
        {tabs.map((t) => {
          const Icon = t.icon;
          const active = activeTab === t.key;
          return (
            <button
              key={t.key}
              type="button"
              role="tab"
              disabled={t.disabled}
              aria-selected={active}
              onClick={() => onTabChange(t.key)}
              className={cn(
                "flex min-h-11 cursor-pointer items-center gap-1.5 border-b-2 px-3 text-xs font-semibold transition-colors duration-150 disabled:cursor-not-allowed disabled:opacity-40",
                active
                  ? "border-brand text-brand"
                  : "border-transparent text-ink-muted hover:text-ink",
              )}
            >
              <Icon className="size-3.5" aria-hidden />
              {t.label}
            </button>
          );
        })}
      </div>

      {error && (
        <div role="alert" className="mx-5 mt-4 rounded-md bg-error/10 px-3 py-2 text-xs text-error">
          {error}
        </div>
      )}

      {/* Nội dung từng Tab */}
      <div className="p-5">
        {activeTab === "metadata" && (
          <div className="space-y-4">
            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <Label htmlFor="loc-title" className="font-medium text-ink-secondary">Tên địa điểm di tích *</Label>
                <Input
                  id="loc-title"
                  value={title}
                  onChange={(e) => {
                    setTitle(e.target.value);
                    if (isNew && !slug) {
                      setSlug(slugifyVi(e.target.value));
                    }
                  }}
                  placeholder="Ví dụ: Bãi cọc Bạch Đằng Giang"
                />
              </div>
              <div>
                <Label htmlFor="loc-slug" className="font-medium text-ink-secondary">Định danh Slug (Duy nhất)</Label>
                <div className="flex gap-1.5">
                  <Input
                    id="loc-slug"
                    value={slug}
                    onChange={(e) => setSlug(e.target.value)}
                    placeholder="bai-coc-bach-dang-938"
                  />
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    onClick={() => setSlug(slugifyVi(title))}
                    title="Tự tạo slug từ tên địa điểm"
                  >
                    Tạo slug
                  </Button>
                </div>
              </div>
            </div>

            <div className="grid gap-3 sm:grid-cols-3">
              <div>
                <Label htmlFor="loc-kind" className="font-medium text-ink-secondary">Loại hình di tích</Label>
                <Select
                  id="loc-kind"
                  value={kind}
                  onChange={(e) => setKind(e.target.value as MapLocationKind)}
                >
                  {(Object.keys(LOCATION_KIND_LABELS) as MapLocationKind[]).map((k) => (
                    <option key={k} value={k}>
                      {LOCATION_KIND_LABELS[k]}
                    </option>
                  ))}
                </Select>
              </div>
              <div>
                <Label htmlFor="loc-precision" className="font-medium text-ink-secondary">Độ chính xác tọa độ</Label>
                <Select
                  id="loc-precision"
                  value={coordinatePrecision}
                  onChange={(e) =>
                    setCoordinatePrecision(e.target.value as CoordinatePrecision)
                  }
                >
                  {(
                    Object.keys(COORDINATE_PRECISION_LABELS) as CoordinatePrecision[]
                  ).map((p) => (
                    <option key={p} value={p}>
                      {COORDINATE_PRECISION_LABELS[p]}
                    </option>
                  ))}
                </Select>
              </div>
              <div>
                <Label htmlFor="loc-order" className="font-medium text-ink-secondary">Thứ tự hiển thị</Label>
                <Input
                  id="loc-order"
                  type="number"
                  value={displayOrder}
                  onChange={(e) => setDisplayOrder(e.target.value)}
                />
              </div>
            </div>

            <div>
              <Label htmlFor="loc-visibility" className="font-medium text-ink-secondary">Chế độ hiển thị trên bản đồ học viên</Label>
              <Select
                id="loc-visibility"
                value={visibility}
                onChange={(e) => setVisibility(e.target.value as MapLocationVisibility)}
              >
                {(Object.keys(LOCATION_VISIBILITY_LABELS) as MapLocationVisibility[]).map(
                  (v) => (
                    <option key={v} value={v}>
                      {LOCATION_VISIBILITY_LABELS[v]}
                    </option>
                  ),
                )}
              </Select>
            </div>

            <div>
              <Label htmlFor="loc-summary" className="font-medium text-ink-secondary">Tóm tắt ngắn (Hiển thị trên thẻ ghim bản đồ)</Label>
              <Input
                id="loc-summary"
                maxLength={500}
                value={shortSummary}
                onChange={(e) => setShortSummary(e.target.value)}
                placeholder="Trận địa cọc gỗ lim bịt sắt trên cửa sông Bạch Đằng năm 938..."
              />
            </div>

            <div>
              <Label htmlFor="loc-desc" className="font-medium text-ink-secondary">Mô tả lịch sử chi tiết</Label>
              <Textarea
                id="loc-desc"
                rows={3}
                maxLength={4000}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Nội dung thuyết minh chi tiết khi học viên mở khóa địa điểm di tích..."
              />
            </div>
            {/* Khối: Nội dung Cuốn Sách Lịch Sử — Bản đồ Di sản */}
            <div className="space-y-3 rounded-xl border border-border bg-surface p-4">
              <div>
                <Label className="flex items-center gap-1.5 text-sm font-semibold text-ink">
                  <BookOpen className="size-4 text-brand" aria-hidden />
                  Nội dung Cuốn Sách Lịch Sử (Hiển thị trên Bản đồ Di sản)
                </Label>
                <p className="mt-0.5 text-xs text-ink-muted">
                  Nội dung này hiển thị trong Sách đọc Lịch sử khi học viên mở hồ sơ địa điểm trên Bản đồ Di sản.
                </p>
              </div>

              <div>
                <Label htmlFor="loc-key-figures" className="font-medium text-ink-secondary">
                  Nhân vật lịch sử tiêu biểu
                </Label>
                <Input
                  id="loc-key-figures"
                  maxLength={500}
                  value={keyFigures}
                  onChange={(e) => setKeyFigures(e.target.value)}
                  placeholder="Ngô Quyền, Dương Tam Kha — Thủy quân Nam Hán"
                />
              </div>

              <div>
                <Label htmlFor="loc-story-narrative" className="font-medium text-ink-secondary">
                  Câu chuyện &amp; Diễn biến lịch sử (Chương II — Sách đọc lịch sử)
                </Label>
                <Textarea
                  id="loc-story-narrative"
                  rows={5}
                  value={storyNarrative}
                  onChange={(e) => setStoryNarrative(e.target.value)}
                  placeholder="Thuật lại diễn biến trận chiến, bối cảnh lịch sử và các tình tiết then chốt..."
                />
              </div>

              <div>
                <Label htmlFor="loc-historical-significance" className="font-medium text-ink-secondary">
                  Ý nghĩa lịch sử &amp; Giá trị di sản
                </Label>
                <Textarea
                  id="loc-historical-significance"
                  rows={3}
                  value={historicalSignificance}
                  onChange={(e) => setHistoricalSignificance(e.target.value)}
                  placeholder="Trận Bạch Đằng 938 chấm dứt một nghìn năm Bắc thuộc, mở ra kỷ nguyên độc lập tự chủ lâu dài..."
                />
              </div>
            </div>

            {/* Khối 1: Hình bản đồ & Chọn vị trí trên Bản đồ */}
            <div className="space-y-3 rounded-xl border border-border bg-surface p-4">
              <input
                ref={mapFileInputRef}
                type="file"
                accept="image/png,image/jpeg,image/webp"
                className="hidden"
                onChange={handleDirectMapUpload}
                aria-label="Tải tệp ảnh bản đồ lên"
              />

              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <Label className="flex items-center gap-1.5 text-sm font-semibold text-ink">
                    <MapIcon className="size-4 text-brand" aria-hidden />
                    Hình bản đồ & Chọn vị trí trên Bản đồ (0–100%)
                  </Label>
                  <p className="mt-0.5 text-xs text-ink-muted">
                    Đang hiển thị: <strong className="text-ink">{activeMapImageLabel}</strong>
                    {mapAssetId ? " (Đã gắn bản đồ riêng)" : " (Tự động theo địa điểm / sự kiện)"}
                  </p>
                </div>

                <div className="flex flex-wrap items-center gap-1.5">
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={uploadingMap}
                    onClick={() => mapFileInputRef.current?.click()}
                  >
                    <Upload className="size-3.5" aria-hidden />
                    {uploadingMap ? "Đang tải..." : "Tải ảnh bản đồ"}
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={uploadingMap}
                    onClick={() => setMapPickerOpen(true)}
                  >
                    <FolderOpen className="size-3.5" aria-hidden />
                    Chọn từ thư viện
                  </Button>
                  {mapAssetId && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() => setMapAssetId(null)}
                    >
                      <Trash2 className="size-3.5 text-error" aria-hidden />
                      Đặt lại tự động
                    </Button>
                  )}
                </div>
              </div>

              {mapUploadError && (
                <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-xs text-error">
                  {mapUploadError}
                </p>
              )}

              {/* Thanh chọn nhanh 6 bản đồ lịch sử mẫu */}
              <div>
                <p className="mb-1.5 text-[11px] font-medium text-ink-muted">
                  Đổi nhanh bản đồ lịch sử cho địa điểm này:
                </p>
                <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-3">
                  {HERITAGE_PRESET_MAPS.map((m) => {
                    const isSelectedMap =
                      !customMapAssetId &&
                      (mapAssetId === m.assetId ||
                        (!mapAssetId && resolvedMapPreset.key === m.key));
                    return (
                      <button
                        key={m.key}
                        type="button"
                        onClick={() => setMapAssetId(m.assetId)}
                        className={cn(
                          "flex cursor-pointer items-center gap-2 rounded-lg border p-1.5 text-left transition-all",
                          isSelectedMap
                            ? "border-brand bg-brand/5 ring-1 ring-brand/40"
                            : "border-border bg-white hover:border-brand/50",
                        )}
                      >
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={m.url}
                          alt={m.title}
                          className="h-8 w-12 shrink-0 rounded object-cover"
                        />
                        <span
                          className={cn(
                            "line-clamp-2 text-[11px] font-medium leading-tight",
                            isSelectedMap ? "text-brand" : "text-ink",
                          )}
                        >
                          {m.shortLabel}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>

              <LatLngMapPicker
                value={pickerCoords}
                imageSrc={activeMapImageSrc}
                imageLabel={activeMapImageLabel}
                onChange={({ lat, lng }) => {
                  setLatitude(String(lat));
                  setLongitude(String(lng));
                }}
              />

              <div className="grid grid-cols-2 gap-3 pt-1">
                <div>
                  <Label htmlFor="loc-lat">Vị trí dọc / Vĩ độ (%) *</Label>
                  <Input
                    id="loc-lat"
                    value={latitude}
                    onChange={(e) => setLatitude(e.target.value)}
                  />
                </div>
                <div>
                  <Label htmlFor="loc-lng">Vị trí ngang / Kinh độ (%) *</Label>
                  <Input
                    id="loc-lng"
                    value={longitude}
                    onChange={(e) => setLongitude(e.target.value)}
                  />
                </div>
              </div>
            </div>

            {/* Khối 2: Hình nền / Ảnh bìa địa điểm di tích */}
            <div className="space-y-3 rounded-xl border border-border bg-surface p-4">
              <input
                ref={coverFileInputRef}
                type="file"
                accept="image/png,image/jpeg,image/webp"
                className="hidden"
                onChange={handleDirectCoverUpload}
                aria-label="Tải tệp hình nền địa điểm lên"
              />

              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <Label className="flex items-center gap-1.5 text-sm font-semibold text-ink">
                    <ImageIcon className="size-4 text-brand" aria-hidden />
                    Hình nền / Ảnh bìa địa điểm di tích
                  </Label>
                  <p className="mt-0.5 text-xs text-ink-muted">
                    Hiển thị trên thẻ danh sách địa điểm và đầu hồ sơ di tích của học viên.
                  </p>
                </div>

                <div className="flex flex-wrap items-center gap-1.5">
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={uploadingCover}
                    onClick={() => coverFileInputRef.current?.click()}
                  >
                    <Upload className="size-3.5" aria-hidden />
                    {uploadingCover ? "Đang tải..." : "Tải ảnh nền"}
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={uploadingCover}
                    onClick={() => setCoverPickerOpen(true)}
                  >
                    <FolderOpen className="size-3.5" aria-hidden />
                    Chọn từ thư viện
                  </Button>
                  {coverAssetId && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() => setCoverAssetId(null)}
                    >
                      <Trash2 className="size-3.5 text-error" aria-hidden />
                      Gỡ ảnh
                    </Button>
                  )}
                </div>
              </div>

              {coverUploadError && (
                <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-xs text-error">
                  {coverUploadError}
                </p>
              )}

              <div className="grid gap-3 sm:grid-cols-[12rem_1fr] sm:items-start">
                <div className="relative aspect-video w-full overflow-hidden rounded-lg border border-border bg-white shadow-xs">
                  {customCoverLoading ? (
                    <div className="flex size-full items-center justify-center bg-surface-alt text-xs text-ink-muted">
                      Đang tải ảnh…
                    </div>
                  ) : (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={activeCoverPreviewSrc}
                      alt={title || "Hình nền địa điểm di tích"}
                      className="size-full object-cover"
                    />
                  )}
                  <span className="absolute bottom-1.5 left-1.5 rounded bg-black/70 px-1.5 py-0.5 text-[10px] font-medium text-white">
                    {coverAssetId ? "Đã gắn ảnh bìa" : "Tự động theo địa điểm"}
                  </span>
                </div>

                <div className="min-w-0 space-y-2 text-xs text-ink-muted">
                  {presetCover ? (
                    <div className="rounded-lg border border-border bg-white p-2.5">
                      <p className="font-medium text-ink">{presetCover.title}</p>
                      <p className="mt-0.5 text-[11px] text-ink-muted">{presetCover.caption}</p>
                      <p className="mt-1 font-mono text-[11px] text-ink-muted">
                        Asset ID: {presetCover.assetId}
                      </p>
                    </div>
                  ) : customCoverAssetId ? (
                    <div className="rounded-lg border border-border bg-white p-2.5">
                      <p className="truncate font-medium text-ink">
                        {coverAssetDetailQuery.data?.originalFilename ?? "Ảnh bìa đã chọn từ thư viện"}
                      </p>
                      {coverAssetDetailQuery.data && (
                        <p className="mt-0.5 text-[11px]">
                          Định dạng: <span className="font-mono text-ink">{coverAssetDetailQuery.data.mimeType}</span> ·{" "}
                          {Math.max(1, Math.round(coverAssetDetailQuery.data.sizeBytes / 1024))} KB
                        </p>
                      )}
                      <p className="mt-1 truncate font-mono text-[11px] text-ink-muted">
                        Asset ID: {customCoverAssetId}
                      </p>
                    </div>
                  ) : (
                    <div className="rounded-lg border border-dashed border-border bg-white/70 p-2.5">
                      <p className="font-medium text-ink">Chưa gắn Asset riêng</p>
                      <p className="mt-0.5 text-[11px]">
                        Hệ thống đang hiển thị tranh minh họa tự động. Bạn có thể tải ảnh mới lên, chọn từ thư viện hoặc bấm vào một tranh mẫu bên dưới.
                      </p>
                    </div>
                  )}

                  <div>
                    <p className="mb-1 text-[11px] font-medium text-ink-muted">
                      Chọn nhanh tranh nền di tích mẫu:
                    </p>
                    <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-3">
                      {HERITAGE_PRESET_ILLUSTRATIONS.map((preset) => {
                        const activePreset = coverAssetId === preset.assetId;
                        return (
                          <button
                            key={preset.key}
                            type="button"
                            onClick={() => setCoverAssetId(preset.assetId)}
                            className={cn(
                              "flex cursor-pointer items-center gap-1.5 rounded-md border p-1 text-left transition-all",
                              activePreset
                                ? "border-brand bg-brand/5 ring-1 ring-brand/40"
                                : "border-border bg-white hover:border-brand/50",
                            )}
                          >
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            <img
                              src={preset.url}
                              alt={preset.title}
                              className="size-7 shrink-0 rounded object-cover"
                            />
                            <span
                              className={cn(
                                "line-clamp-2 text-[10px] font-medium leading-tight",
                                activePreset ? "text-brand" : "text-ink",
                              )}
                            >
                              {preset.title}
                            </span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button
                type="button"
                disabled={saveMetadataMutation.isPending}
                onClick={() => saveMetadataMutation.mutate()}
              >
                {saveMetadataMutation.isPending
                  ? "Đang lưu..."
                  : isNew
                    ? "Tạo địa điểm di tích"
                    : "Lưu thông tin & tọa độ"}
              </Button>
            </div>

            <AssetPickerDialog
              open={coverPickerOpen}
              onOpenChange={setCoverPickerOpen}
              onSelect={(asset: AdminAsset) => setCoverAssetId(asset.id)}
            />
            <AssetPickerDialog
              open={mapPickerOpen}
              onOpenChange={setMapPickerOpen}
              onSelect={(asset: AdminAsset) => setMapAssetId(asset.id)}
            />
          </div>
        )}

        {activeTab === "events" && location && (
          <div className="space-y-4">
            <div className="rounded-lg border border-border bg-surface p-3 text-xs text-ink-muted">
              Một địa điểm di tích (ví dụ: <strong>Sông Bạch Đằng</strong> hoặc{" "}
              <strong>Hoàng thành Thăng Long</strong>) có thể gắn với nhiều Sự kiện lịch sử khác nhau với vai trò{" "}
              <strong>PRIMARY (Sự kiện chính)</strong> hoặc <strong>RELATED (Sự kiện liên quan)</strong>.
            </div>

            <div className="flex flex-wrap items-end gap-2 rounded-lg border border-border p-3">
              <div className="min-w-[14rem] flex-1">
                <Label htmlFor="add-event-select">Chọn sự kiện lịch sử để gắn</Label>
                <Select
                  id="add-event-select"
                  className="mt-1"
                  value={addingEventId}
                  onChange={(e) => setAddingEventId(e.target.value)}
                >
                  <option value="">— Chọn một sự kiện —</option>
                  {allEvents
                    .filter((ev) => !eventLinks.some((link) => link.eventId === ev.id))
                    .map((ev) => (
                      <option key={ev.id} value={ev.id}>
                        {ev.title} (
                        {ev.startYear == null
                          ? "Chưa rõ năm"
                          : ev.startYear < 0
                            ? `${Math.abs(ev.startYear)} TCN`
                            : ev.startYear}
                        )
                      </option>
                    ))}
                </Select>
              </div>
              <div className="w-44">
                <Label htmlFor="add-event-role">Vai trò</Label>
                <Select
                  id="add-event-role"
                  className="mt-1"
                  value={addingEventRole}
                  onChange={(e) =>
                    setAddingEventRole(e.target.value as MapLocationEventRole)
                  }
                >
                  <option value="PRIMARY">PRIMARY (Chính)</option>
                  <option value="RELATED">RELATED (Liên quan)</option>
                </Select>
              </div>
              <Button
                type="button"
                variant="secondary"
                disabled={!addingEventId}
                onClick={() => {
                  if (!addingEventId) return;
                  setEventLinks((prev) => [
                    ...prev,
                    {
                      eventId: addingEventId,
                      role: addingEventRole,
                      sortOrder: prev.length,
                    },
                  ]);
                  setAddingEventId("");
                }}
              >
                <Plus className="size-4" aria-hidden />
                Thêm liên kết
              </Button>
            </div>

            {eventLinks.length === 0 ? (
              <p className="rounded-lg border border-dashed border-border p-6 text-center text-sm text-ink-muted">
                Địa điểm này chưa liên kết với sự kiện nào.
              </p>
            ) : (
              <ul className="space-y-2">
                {eventLinks.map((link, idx) => {
                  const ev = allEvents.find((x) => x.id === link.eventId);
                  return (
                    <li
                      key={link.eventId}
                      className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border bg-white px-3 py-2.5"
                    >
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium text-ink">
                          {ev?.title ?? link.eventId}
                        </p>
                        <p className="text-xs text-ink-muted">
                          Thứ tự hiển thị: #{idx + 1}
                        </p>
                      </div>
                      <div className="flex items-center gap-2">
                        <Select
                          value={link.role}
                          onChange={(e) => {
                            const nextRole = e.target.value as MapLocationEventRole;
                            setEventLinks((prev) =>
                              prev.map((item, i) =>
                                i === idx ? { ...item, role: nextRole } : item,
                              ),
                            );
                          }}
                          className="h-8 w-40 text-xs"
                        >
                          <option value="PRIMARY">PRIMARY (Chính)</option>
                          <option value="RELATED">RELATED (Liên quan)</option>
                        </Select>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          aria-label="Gỡ sự kiện"
                          onClick={() =>
                            setEventLinks((prev) => prev.filter((_, i) => i !== idx))
                          }
                        >
                          <Trash2 className="size-4 text-error" aria-hidden />
                        </Button>
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}

            <div className="flex justify-end">
              <Button
                type="button"
                disabled={saveEventsMutation.isPending}
                onClick={() => saveEventsMutation.mutate()}
              >
                {saveEventsMutation.isPending
                  ? "Đang lưu..."
                  : "Lưu danh sách Sự kiện liên kết"}
              </Button>
            </div>
          </div>
        )}

        {activeTab === "unlock" && location && (
          <div className="space-y-4">
            <div>
              <Label htmlFor="unlock-mode-select">Chế độ mở khóa địa điểm (Unlock Rule Mode)</Label>
              <p className="mt-0.5 text-xs text-ink-muted">
                Tùy chọn — phần thưởng khám phá sau khi học: địa điểm chỉ mở
                khi học viên hoàn thành bài học đã gắn. Địa điểm đã mở hiện
                như ghim vệ tinh cạnh sự kiện trên Bản đồ Dấu Ấn; bài học
                không gắn địa điểm vẫn chạy và mở khóa bài kế bình thường.
              </p>
              <Select
                id="unlock-mode-select"
                className="mt-1"
                value={ruleModeTab}
                onChange={(e) => setRuleModeTab(e.target.value as UnlockRuleMode)}
              >
                {(Object.keys(UNLOCK_RULE_MODE_LABELS) as UnlockRuleMode[]).map((m) => (
                  <option key={m} value={m}>
                    {UNLOCK_RULE_MODE_LABELS[m]}
                  </option>
                ))}
              </Select>
            </div>

            {ruleModeTab === "NONE" ? (
              <div className="rounded-lg border border-success/30 bg-success/10 p-4 text-sm text-ink">
                Địa điểm đang ở chế độ <strong>Luôn mở (NONE)</strong>: mở tự do — không gắn bài học. Học viên khám phá toàn bộ nội dung di tích và thư viện media ngay từ đầu, không cần hoàn thành bài học nào.
              </div>
            ) : (
              <div className="space-y-3">
                {selectedLessonIds.length === 0 && (
                  <div
                    role="alert"
                    className="rounded-lg border border-warning/40 bg-warning/15 p-3 text-xs text-ink"
                  >
                    Bạn đang chọn chế độ mở khóa theo bài học nhưng chưa tích chọn bài học nào. Hãy tích chọn ít nhất 1 bài học bên dưới (hoặc chuyển về Không yêu cầu bài học).
                  </div>
                )}
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <Label htmlFor="lesson-search-input">
                    Chọn các bài học mở khóa ({selectedLessonIds.length} bài đã chọn)
                  </Label>
                  <Input
                    id="lesson-search-input"
                    value={lessonSearch}
                    onChange={(e) => setLessonSearch(e.target.value)}
                    placeholder="Lọc nhanh tên bài học..."
                    className="h-8 w-60 text-xs"
                  />
                </div>

                <div className="max-h-72 space-y-1.5 overflow-y-auto rounded-lg border border-border p-2.5">
                  {filteredLessons.map((lesson) => {
                    const checked = selectedLessonIds.includes(lesson.id);
                    const ev = allEvents.find((e) => e.id === lesson.eventId);
                    return (
                      <label
                        key={lesson.id}
                        className={cn(
                          "flex cursor-pointer items-center justify-between gap-3 rounded-md px-2.5 py-2 text-xs transition-colors",
                          checked ? "bg-surface-alt font-medium" : "hover:bg-surface",
                        )}
                      >
                        <div className="flex min-w-0 items-center gap-2.5">
                          <input
                            type="checkbox"
                            checked={checked}
                            onChange={(e) => {
                              if (e.target.checked) {
                                setSelectedLessonIds((prev) => [...prev, lesson.id]);
                              } else {
                                setSelectedLessonIds((prev) =>
                                  prev.filter((id) => id !== lesson.id),
                                );
                              }
                            }}
                            className="size-4 accent-brand"
                          />
                          <div className="min-w-0">
                            <p className="truncate text-ink">{lesson.title}</p>
                            <p className="truncate text-[11px] text-ink-muted">
                              Sự kiện: {ev?.title ?? lesson.eventId}
                            </p>
                          </div>
                        </div>
                        <StatusChip status={lesson.status} />
                      </label>
                    );
                  })}
                </div>
              </div>
            )}

            <div className="flex justify-end">
              <Button
                type="button"
                disabled={saveUnlockMutation.isPending}
                onClick={() => saveUnlockMutation.mutate()}
              >
                {saveUnlockMutation.isPending
                  ? "Đang lưu..."
                  : "Lưu quy tắc mở khóa"}
              </Button>
            </div>
          </div>
        )}

        {activeTab === "media" && location && (
          <div className="space-y-4">
            {/* Bộ sưu tập Tranh Di tích AI có sẵn để chèn 1 chạm */}
            <div className="rounded-lg border border-warning/50 bg-surface-alt/60 p-3">
              <div className="flex items-center justify-between gap-2">
                <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                  <Sparkles className="size-4 text-brand" aria-hidden />
                  Thư viện Tranh Minh họa Di tích AI (Chèn nhanh 1 chạm)
                </span>
              </div>
              <div className="mt-2.5 grid grid-cols-2 gap-2 sm:grid-cols-3">
                {HERITAGE_PRESET_ILLUSTRATIONS.map((preset) => (
                  <button
                    key={preset.key}
                    type="button"
                    onClick={() =>
                      setMediaItems((prev) => [
                        ...prev,
                        {
                          mediaType: "IMAGE_2D",
                          title: preset.title,
                          caption: preset.caption,
                          assetId: null,
                          externalUrl: preset.url,
                          visibility: "PUBLIC_PREVIEW",
                          sortOrder: prev.length,
                        },
                      ])
                    }
                    className="group flex cursor-pointer items-center gap-2 rounded-md border border-border bg-white p-1.5 text-left transition-colors hover:border-brand"
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={preset.url}
                      alt={preset.title}
                      className="size-10 shrink-0 rounded object-cover"
                    />
                    <span className="line-clamp-2 text-[11px] font-medium text-ink group-hover:text-brand">
                      + {preset.title}
                    </span>
                  </button>
                ))}
              </div>
            </div>

            <div className="flex items-center justify-between">
              <h4 className="text-sm font-semibold text-ink">
                Danh sách tư liệu Media ({mediaItems.length})
              </h4>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={() =>
                  setMediaItems((prev) => [
                    ...prev,
                    {
                      mediaType: "IMAGE_2D",
                      title: "",
                      caption: "",
                      assetId: null,
                      externalUrl: "",
                      visibility: "PUBLIC_PREVIEW",
                      sortOrder: prev.length,
                    },
                  ])
                }
              >
                <Plus className="size-3.5" aria-hidden />
                Thêm mục Media
              </Button>
            </div>

            {mediaItems.length === 0 ? (
              <p className="rounded-lg border border-dashed border-border p-6 text-center text-sm text-ink-muted">
                Chưa có tư liệu media nào. Bấm vào một tranh AI phía trên hoặc bấm &quot;Thêm mục Media&quot;.
              </p>
            ) : (
              <div className="space-y-3">
                {mediaItems.map((item, idx) => (
                  <div
                    key={idx}
                    className="space-y-3 rounded-lg border border-border bg-surface p-3"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex min-w-0 items-center gap-3">
                        <MediaItemThumbnail item={item} />
                        <div className="min-w-0">
                          <span className="text-xs font-semibold text-brand">
                            Media #{idx + 1}
                          </span>
                          {idx === 0 && (
                            <p className="text-[11px] font-medium text-success">
                              ★ Ảnh đầu — hiển thị đầu Carousel
                            </p>
                          )}
                          <p className="truncate text-[11px] text-ink-muted">
                            {item.title?.trim() || "Chưa đặt tiêu đề"}
                          </p>
                        </div>
                      </div>
                      <div className="flex shrink-0 items-center gap-1">
                        <Button
                          type="button"
                          variant="secondary"
                          size="icon"
                          className="size-7"
                          disabled={idx === 0}
                          onClick={() => moveMediaItem(idx, idx - 1)}
                          title="Đưa lên trên"
                          aria-label="Đưa lên trên"
                        >
                          <ArrowUp className="size-3.5" aria-hidden />
                        </Button>
                        <Button
                          type="button"
                          variant="secondary"
                          size="icon"
                          className="size-7"
                          disabled={idx === mediaItems.length - 1}
                          onClick={() => moveMediaItem(idx, idx + 1)}
                          title="Đưa xuống dưới"
                          aria-label="Đưa xuống dưới"
                        >
                          <ArrowDown className="size-3.5" aria-hidden />
                        </Button>
                        <Button
                          type="button"
                          variant="secondary"
                          size="sm"
                          className="h-7 px-2 text-xs"
                          disabled={idx === 0}
                          onClick={() => moveMediaItem(idx, 0)}
                          title="Đặt làm ảnh đầu của Carousel"
                        >
                          <Star className="size-3.5" aria-hidden />
                          Ảnh đầu
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          className="h-7 px-2 text-xs text-error"
                          onClick={() =>
                            setMediaItems((prev) => prev.filter((_, i) => i !== idx))
                          }
                        >
                          <Trash2 className="size-3.5" aria-hidden />
                          Xóa
                        </Button>
                      </div>
                    </div>

                    <div className="grid gap-3 sm:grid-cols-2">
                      <div>
                        <Label>Loại tư liệu</Label>
                        <Select
                          className="mt-1"
                          value={item.mediaType}
                          onChange={(e) => {
                            const val = e.target.value as LocationMediaType;
                            setMediaItems((prev) =>
                              prev.map((m, i) =>
                                i === idx ? { ...m, mediaType: val } : m,
                              ),
                            );
                          }}
                        >
                          {(Object.keys(MEDIA_TYPE_LABELS) as LocationMediaType[]).map(
                            (k) => (
                              <option key={k} value={k}>
                                {MEDIA_TYPE_LABELS[k]}
                              </option>
                            ),
                          )}
                        </Select>
                      </div>

                      <div>
                        <Label>Quyền xem của học viên</Label>
                        <Select
                          className="mt-1"
                          value={item.visibility}
                          onChange={(e) => {
                            const val = e.target.value as LocationMediaVisibility;
                            setMediaItems((prev) =>
                              prev.map((m, i) =>
                                i === idx ? { ...m, visibility: val } : m,
                              ),
                            );
                          }}
                        >
                          {(
                            Object.keys(
                              MEDIA_VISIBILITY_LABELS,
                            ) as LocationMediaVisibility[]
                          ).map((k) => (
                            <option key={k} value={k}>
                              {MEDIA_VISIBILITY_LABELS[k]}
                            </option>
                          ))}
                        </Select>
                      </div>
                    </div>

                    <div className="grid gap-3 sm:grid-cols-2">
                      <div>
                        <Label>Tiêu đề tư liệu *</Label>
                        <Input
                          className="mt-1"
                          value={item.title ?? ""}
                          onChange={(e) => {
                            const val = e.target.value;
                            setMediaItems((prev) =>
                              prev.map((m, i) => (i === idx ? { ...m, title: val } : m)),
                            );
                          }}
                          placeholder="Ví dụ: Toàn cảnh Bãi cọc Bạch Đằng"
                        />
                      </div>

                      <div>
                        <Label>Đường dẫn URL / Ảnh minh họa</Label>
                        <div className="mt-1 flex gap-1.5">
                          <Input
                            value={item.externalUrl ?? ""}
                            onChange={(e) => {
                              const val = e.target.value;
                              setMediaItems((prev) =>
                                prev.map((m, i) =>
                                  i === idx ? { ...m, externalUrl: val } : m,
                                ),
                              );
                            }}
                            placeholder="/heritage/bai-coc-bach-dang.jpg hoặc https://..."
                          />
                          <Button
                            type="button"
                            variant="secondary"
                            size="sm"
                            onClick={() => setMediaAssetPickerIdx(idx)}
                            title="Chọn từ thư viện Asset"
                          >
                            <ImageIcon className="size-3.5" aria-hidden />
                          </Button>
                          <input
                            id={`media-file-${idx}`}
                            type="file"
                            accept="image/*"
                            className="hidden"
                            onChange={(e) => handleMediaFileUpload(idx, e)}
                            aria-label="Tải ảnh từ máy"
                          />
                          <Button
                            type="button"
                            variant="secondary"
                            size="sm"
                            disabled={mediaUploadingIdx === idx}
                            onClick={() =>
                              document.getElementById(`media-file-${idx}`)?.click()
                            }
                            title="Tải ảnh từ máy tính lên Asset Service"
                          >
                            <Upload className="size-3.5" aria-hidden />
                            {mediaUploadingIdx === idx ? "Đang tải..." : "Tải ảnh từ máy"}
                          </Button>
                        </div>
                        {item.assetId && (
                          <p className="mt-1 text-[11px] text-ink-muted">
                            Asset ID đã gắn: <code>{item.assetId}</code>
                          </p>
                        )}
                      </div>
                    </div>

                    <div>
                      <Label>Chú thích tư liệu (Caption)</Label>
                      <Input
                        className="mt-1"
                        value={item.caption ?? ""}
                        onChange={(e) => {
                          const val = e.target.value;
                          setMediaItems((prev) =>
                            prev.map((m, i) => (i === idx ? { ...m, caption: val } : m)),
                          );
                        }}
                        placeholder="Thuyết minh ngắn hiển thị bên dưới ảnh/video..."
                      />
                    </div>

                    <div>
                      <Label>Nguồn tư liệu / Trích dẫn sử liệu</Label>
                      <Input
                        className="mt-1"
                        value={item.sourceCitation ?? ""}
                        onChange={(e) => {
                          const val = e.target.value;
                          setMediaItems((prev) =>
                            prev.map((m, i) =>
                              i === idx ? { ...m, sourceCitation: val } : m,
                            ),
                          );
                        }}
                        placeholder="VD: Đại Việt sử ký toàn thư, Bảo tàng Lịch sử Quốc gia..."
                      />
                    </div>
                  </div>
                ))}
              </div>
            )}

            <div className="flex justify-end">
              <Button
                type="button"
                disabled={saveMediaMutation.isPending}
                onClick={() => saveMediaMutation.mutate()}
              >
                {saveMediaMutation.isPending
                  ? "Đang lưu..."
                  : "Lưu thư viện Media"}
              </Button>
            </div>

            <AssetPickerDialog
              open={mediaAssetPickerIdx !== null}
              onOpenChange={(open) => {
                if (!open) setMediaAssetPickerIdx(null);
              }}
              onSelect={(asset: AdminAsset) => {
                if (mediaAssetPickerIdx === null) return;
                setMediaItems((prev) =>
                  prev.map((m, i) =>
                    i === mediaAssetPickerIdx
                      ? {
                          ...m,
                          assetId: asset.id,
                          title: m.title || asset.originalFilename || "Tư liệu hình ảnh",
                        }
                      : m,
                  ),
                );
                setMediaAssetPickerIdx(null);
              }}
            />
          </div>
        )}
      </div>
    </div>
  );
}
