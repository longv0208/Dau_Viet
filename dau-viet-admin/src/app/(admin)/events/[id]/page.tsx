import { PageHeader } from "@/components/page-header";
import { EventEditorPage } from "@/features/events/event-editor-page";

export const metadata = { title: "Chỉnh sửa sự kiện — Dấu Việt CMS" };

export default async function EventDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader
        title="Sự kiện"
        description="Xem và chỉnh sửa thông tin sự kiện lịch sử."
      />
      <EventEditorPage eventId={id} />
    </div>
  );
}
