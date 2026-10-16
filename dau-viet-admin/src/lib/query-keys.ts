/** Single source of TanStack Query key builders — prevents key drift. */

export const qk = {
  admin: {
    ping: () => ["admin", "ping"] as const,
  },
  me: () => ["me"] as const,
  events: {
    list: (params?: { page?: number; size?: number; q?: string }) =>
      ["events", "list", params ?? {}] as const,
  },
  lessons: {
    list: (params?: { page?: number; size?: number; status?: string; sort?: string }) =>
      ["lessons", "list", params ?? {}] as const,
  },
  templates: {
    list: () => ["templates", "list"] as const,
  },
};
