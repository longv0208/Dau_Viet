import { SceneEditRouter } from "@/features/animations/scene-edit-router";

export const metadata = { title: "Soạn hoạt họa — Dấu Việt CMS" };

export default async function AnimationEditPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <SceneEditRouter sceneId={id} />;
}
