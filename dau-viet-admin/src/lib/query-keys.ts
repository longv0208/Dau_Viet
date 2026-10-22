/** Single source of TanStack Query key builders — prevents key drift. */

export const qk = {
  admin: {
    ping: () => ["admin", "ping"] as const,
  },
  me: () => ["me"] as const,
  events: {
    list: (params?: { page?: number; size?: number; q?: string; status?: string }) =>
      ["events", "list", params ?? {}] as const,
    detail: (id: string) => ["events", "detail", id] as const,
  },
  lessons: {
    list: (params?: {
      page?: number;
      size?: number;
      status?: string;
      sort?: string;
      eventId?: string;
      q?: string;
    }) => ["lessons", "list", params ?? {}] as const,
    detail: (id: string) => ["lessons", "detail", id] as const,
  },
  templates: {
    list: () => ["templates", "list"] as const,
  },
  evidences: {
    list: (params?: {
      page?: number;
      size?: number;
      eventId?: string;
      status?: string;
      q?: string;
    }) => ["evidences", "list", params ?? {}] as const,
    detail: (id: string) => ["evidences", "detail", id] as const,
  },
  assets: {
    list: (params?: { page?: number; size?: number }) =>
      ["assets", "list", params ?? {}] as const,
    detail: (id: string) => ["assets", "detail", id] as const,
  },
  mapLocations: {
    list: (eventId: string) => ["map-locations", "list", eventId] as const,
  },
  learner: {
    content: (id: string) => ["learner", "content", id] as const,
  },
  items: {
    list: (params?: { page?: number; size?: number; active?: boolean }) =>
      ["items", "list", params ?? {}] as const,
    detail: (id: string) => ["items", "detail", id] as const,
  },
  versions: {
    list: (lessonId: string, params?: { page?: number; size?: number }) =>
      ["versions", "list", lessonId, params ?? {}] as const,
    detail: (lessonId: string, versionId: string) =>
      ["versions", "detail", lessonId, versionId] as const,
  },
};
