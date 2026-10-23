import { SceneEditor } from "@/features/animations/scene-editor";

export const metadata = { title: "Soạn hoạt họa — Dấu Việt CMS" };

export default async function AnimationEditPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <SceneEditor sceneId={id} />;
}
