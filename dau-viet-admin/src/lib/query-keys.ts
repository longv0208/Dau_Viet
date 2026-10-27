/** Single source of TanStack Query key builders — prevents key drift. */

export const qk = {
  learningPath: {
    all: ["learning-path"] as const,
    lists: ["learning-path", "versions"] as const,
    list: (code: string) => ["learning-path", "versions", code] as const,
    detail: (id: string) => ["learning-path", "detail", id] as const,
  },
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
    list: (params?: { page?: number; size?: number; enabled?: boolean; q?: string }) =>
      params ? (["templates", "list", params] as const) : (["templates", "list"] as const),
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
    list: (params?: { page?: number; size?: number; q?: string }) =>
      ["assets", "list", params ?? {}] as const,
    detail: (id: string) => ["assets", "detail", id] as const,
  },
  mapLocations: {
    list: (eventId: string) => ["map-locations", "list", eventId] as const,
    standaloneList: (params?: {
      page?: number;
      size?: number;
      q?: string;
      kind?: string;
      status?: string;
      eventId?: string;
    }) => ["map-locations", "standalone", params ?? {}] as const,
    standaloneDetail: (id: string) => ["map-locations", "standalone", "detail", id] as const,
  },
  learner: {
    content: (id: string) => ["learner", "content", id] as const,
  },
  items: {
    list: (params?: { page?: number; size?: number; active?: boolean; itemType?: string; q?: string }) =>
      ["items", "list", params ?? {}] as const,
    detail: (id: string) => ["items", "detail", id] as const,
  },
  versions: {
    list: (lessonId: string, params?: { page?: number; size?: number; q?: string }) =>
      ["versions", "list", lessonId, params ?? {}] as const,
    detail: (lessonId: string, versionId: string) =>
      ["versions", "detail", lessonId, versionId] as const,
  },
  animationTemplates: {
    list: (params?: { rendererCode?: string; enabled?: boolean }) =>
      ["animation-templates", "list", params ?? {}] as const,
  },
  animationScenes: {
    list: (params?: {
      page?: number;
      size?: number;
      status?: string;
      q?: string;
      templateId?: string;
      eventId?: string;
    }) => ["animation-scenes", "list", params ?? {}] as const,
    detail: (id: string) => ["animation-scenes", "detail", id] as const,
    versions: (id: string) => ["animation-scenes", "versions", id] as const,
  },
  policies: {
    list: (eventId: string) => ["policies", "list", eventId] as const,
  },
  eventDossiers: (eventId: string) =>
    ["event-dossiers", eventId] as const,
  dossiers: {
    list: (params?: {
      page?: number;
      size?: number;
      type?: string;
      status?: string;
      q?: string;
    }) => ["dossiers", "list", params ?? {}] as const,
    detail: (id: string) => ["dossiers", "detail", id] as const,
  },
  ruleHistory: (itemId: string) => ["rule-history", itemId] as const,
};
