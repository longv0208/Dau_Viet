import { PathBuilder } from "@/features/learning-path/path-builder";

export const metadata = { title: "Thiết kế lộ trình — Dấu Việt CMS" };

export default async function LearningPathEditPage({ params }: { params: Promise<{ versionId: string }> }) {
  const { versionId } = await params;
  return <PathBuilder versionId={versionId} />;
}
