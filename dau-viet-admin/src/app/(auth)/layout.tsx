/** Minimal chrome for auth pages — no AdminShell, no sidebar. */
export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen bg-surface">{children}</div>;
}
