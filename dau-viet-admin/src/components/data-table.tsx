import type { ReactNode } from "react";

import { Skeleton } from "@/components/ui/skeleton";

import { EmptyState } from "./empty-state";
import { ErrorState } from "./error-state";

export interface Column<T> {
  key: string;
  header: string;
  cell: (row: T) => ReactNode;
}

/**
 * A-C03 minimal data table — plain <table> with loading skeleton, empty and
 * error slots. No sorting library (YAGNI for the foundation task).
 */
export function DataTable<T>({
  columns,
  rows,
  rowKey,
  loading = false,
  error,
  onRetry,
  emptyTitle = "Chưa có dữ liệu",
  emptyDescription,
}: {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  loading?: boolean;
  error?: unknown;
  onRetry?: () => void;
  emptyTitle?: string;
  emptyDescription?: string;
}) {
  if (error) return <ErrorState error={error} onRetry={onRetry} />;
  if (!loading && rows.length === 0) {
    return <EmptyState title={emptyTitle} description={emptyDescription} />;
  }
  return (
    <div className="overflow-x-auto rounded-lg border border-border bg-white">
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-border bg-surface-alt">
            {columns.map((c) => (
              <th key={c.key} scope="col" className="px-4 py-3 font-medium text-ink">
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading
            ? Array.from({ length: 5 }).map((_, i) => (
                <tr key={i} className="border-b border-border last:border-0">
                  {columns.map((c) => (
                    <td key={c.key} className="px-4 py-3">
                      <Skeleton className="h-4 w-full max-w-40" />
                    </td>
                  ))}
                </tr>
              ))
            : rows.map((row) => (
                <tr key={rowKey(row)} className="border-b border-border last:border-0 hover:bg-surface/60">
                  {columns.map((c) => (
                    <td key={c.key} className="px-4 py-3 text-ink">
                      {c.cell(row)}
                    </td>
                  ))}
                </tr>
              ))}
        </tbody>
      </table>
    </div>
  );
}
