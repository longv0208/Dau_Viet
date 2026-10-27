import { IslandBuilderWorkspace } from "@/features/island-builder/island-builder-workspace";

export const metadata = { title: "Thiết kế Đảo Di Sản — Dấu Việt CMS" };

export default async function IslandBuilderVersionPage({
  params,
}: {
  params: Promise<{ versionId: string }>;
}) {
  const { versionId } = await params;
  return <IslandBuilderWorkspace versionId={versionId} />;
}
