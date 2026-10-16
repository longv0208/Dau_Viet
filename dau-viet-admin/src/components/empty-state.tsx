import { Inbox } from "lucide-react";
import type { ReactNode } from "react";

import { Card, CardContent } from "@/components/ui/card";

/** Honest empty state — used when a list has no data or a feature is stub. */
export function EmptyState({
  title = "Chưa có dữ liệu",
  description,
  action,
}: {
  title?: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-3 py-12 text-center">
        <Inbox className="size-10 text-ink-muted" aria-hidden />
        <p className="font-medium text-ink">{title}</p>
        {description && <p className="max-w-md text-sm text-ink-muted">{description}</p>}
        {action}
      </CardContent>
    </Card>
  );
}
