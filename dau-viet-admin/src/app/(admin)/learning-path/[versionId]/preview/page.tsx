import { PathPreviewPage } from "@/features/learning-path/path-preview-page";

export const metadata = { title: "Xem trước lộ trình — Dấu Việt CMS" };

export default async function LearningPathPreviewRoute({ params }: { params: Promise<{ versionId: string }> }) {
  const { versionId } = await params;
  return <PathPreviewPage versionId={versionId} />;
}
