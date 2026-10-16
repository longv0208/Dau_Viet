import { AdminShell } from "@/components/admin-shell";

/**
 * (admin) layout — middleware.ts already bounced cookie-less requests. The
 * session bootstrap inside AdminShell does refresh + role check client-side
 * so the rotated `dv_refresh` Set-Cookie lands in the browser (a server-side
 * fetch here would swallow it and break the rotation chain — P0 review fix).
 */
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return <AdminShell>{children}</AdminShell>;
}
