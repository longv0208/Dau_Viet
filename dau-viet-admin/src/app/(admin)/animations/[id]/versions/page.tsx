import { PageHeader } from "@/components/page-header";
import { SceneVersionsTable } from "@/features/animations/scene-versions";

export const metadata = { title: "Phiên bản hoạt họa — Dấu Việt CMS" };

export default async function AnimationVersionsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader
        title="Phiên bản đã xuất bản"
        description="Mỗi lần xuất bản tạo một phiên bản bất biến — bài học đang dùng phiên bản nào sẽ giữ nguyên phiên bản đó."
      />
      <SceneVersionsTable sceneId={id} />
    </div>
  );
}
