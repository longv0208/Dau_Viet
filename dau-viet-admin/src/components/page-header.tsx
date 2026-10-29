import type { ReactNode } from "react";

import { SectionEyebrow } from "@/components/atoms/section-eyebrow";

/** A-C02 — page title + optional action slot. Breadcrumbs live in the shell. */
export function PageHeader({
  title,
  description,
  eyebrow,
  actions,
}: {
  title: string;
  description?: string;
  eyebrow?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-start justify-between gap-3">
      <div>
        {eyebrow && (
          <div className="mb-2">
            <SectionEyebrow>{eyebrow}</SectionEyebrow>
          </div>
        )}
        <h1 className="font-display text-2xl font-semibold text-ink">{title}</h1>
        {description && <p className="mt-1 text-sm text-ink-muted">{description}</p>}
      </div>
      {actions}
    </div>
  );
}
