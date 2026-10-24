import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

import { REFRESH_COOKIE } from "@/lib/server/refresh-cookie";

/**
 * Presence-only guard: without the dv_refresh cookie there is no session at
 * all, so protected paths bounce to /login. Role enforcement happens
 * server-side in the backend and in (admin)/layout.tsx â€” never decode JWT here.
 */
export function middleware(req: NextRequest) {
  if (req.cookies.has(REFRESH_COOKIE)) return NextResponse.next();

  const url = req.nextUrl.clone();
  const next = req.nextUrl.pathname;
  url.pathname = "/login";
  url.search = next && next !== "/" ? `?next=${encodeURIComponent(next)}` : "";
  return NextResponse.redirect(url);
}

export const config = {
  matcher: ["/dashboard/:path*", "/events/:path*", "/lessons/:path*", "/templates/:path*", "/assets/:path*", "/versions/:path*", "/animations/:path*"],
};
