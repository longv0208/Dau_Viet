import { DashboardPage } from "@/features/dashboard/dashboard-page";

export const metadata = { title: "Tổng quan — Dấu Việt CMS" };

/**
 * A-02 — the (admin) layout already verified the session + role server-side;
 * the page is a client component that fetches /users/me via the proxy
 * (single refresh-flight handles reload-token-rehydration).
 */
export default function Dashboard() {
  return <DashboardPage />;
}
