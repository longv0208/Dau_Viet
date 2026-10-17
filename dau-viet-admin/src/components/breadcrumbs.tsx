"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronRight } from "lucide-react";
import { Fragment } from "react";

/** Route segment → Vietnamese crumb label. */
const CRUMB_LABELS: Record<string, string> = {
  dashboard: "Tổng quan",
  events: "Sự kiện",
  lessons: "Bài học",
  evidence: "Bằng chứng",
  templates: "Mẫu bài học",
  assets: "Thư viện media",
  versions: "Phiên bản",
  builder: "Trình soạn",
  preview: "Xem trước",
  publish: "Xuất bản",
};

/** Derives breadcrumbs from the pathname; unknown segments render verbatim. */
export function Breadcrumbs() {
  const pathname = usePathname() ?? "/";
  const segments = pathname.split("/").filter(Boolean);
  if (segments.length === 0) return null;

  let acc = "";
  return (
    <nav aria-label="Breadcrumb">
      <ol className="flex items-center gap-1 text-sm text-ink-muted">
        {segments.map((seg, i) => {
          acc += `/${seg}`;
          const isIdLike =
            /^[0-9a-f]{8}-[0-9a-f-]{20,}$/i.test(seg) || seg.length > 24;
          const label = CRUMB_LABELS[seg] ?? (isIdLike ? "Chi tiết" : seg);
          const isLast = i === segments.length - 1;
          return (
            <Fragment key={acc}>
              {i > 0 && <ChevronRight className="size-3.5" aria-hidden />}
              <li aria-current={isLast ? "page" : undefined}>
                {isLast ? (
                  <span className="font-medium text-ink">{label}</span>
                ) : (
                  <Link href={acc} className="hover:text-brand hover:underline">
                    {label}
                  </Link>
                )}
              </li>
            </Fragment>
          );
        })}
      </ol>
    </nav>
  );
}
