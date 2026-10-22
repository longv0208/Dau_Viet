import { PageHeader } from "@/components/page-header";
import { ItemDetail } from "@/features/items/item-detail";

export const metadata = { title: "Vật phẩm thưởng — Dấu Việt CMS" };

export default async function ItemDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader
        title="Vật phẩm thưởng"
        description="Thông tin hiển thị và điều kiện mở khóa phía server."
      />
      <ItemDetail itemId={id} />
    </div>
  );
}
