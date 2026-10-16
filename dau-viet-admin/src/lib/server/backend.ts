import { env } from "@/env";

/**
 * Server-side fetch to the Spring Boot backend. Used only by BFF route
 * handlers — the browser never calls the backend directly. No retry on 4xx;
 * the upstream body is streamed back verbatim so error codes/traceId survive.
 */
export async function backendFetch(path: string, init?: RequestInit): Promise<Response> {
  return fetch(`${env.BACKEND_URL}${path}`, {
    ...init,
    cache: "no-store",
    headers: {
      "content-type": "application/json",
      ...init?.headers,
    },
  });
}
