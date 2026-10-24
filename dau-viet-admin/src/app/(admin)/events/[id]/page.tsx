import { EventWorkspacePage } from "@/features/events/workspace/event-workspace-page";
import { parseEventTab } from "@/features/events/workspace/types";

export const metadata = { title: "Sự kiện — Dấu Việt CMS" };

/**
 * Event Workspace — hub quản lý toàn bộ nội dung của một sự kiện.
 * Tab điều khiển bởi `?tab=` search param: overview (default) / lessons /
 * hoc-lieu / info. Giữ URL `/events/[id]` làm điểm vào duy nhất — mọi tab
 * đều deep-link được và F5 giữ nguyên tab.
 */
export default async function EventDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const { id } = await params;
  const { tab } = await searchParams;
  return <EventWorkspacePage eventId={id} tab={parseEventTab(tab)} />;
}
