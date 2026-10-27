export type PathStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";
export type ParticipationType = "REQUIRED" | "EXPLORATION_ONLY";
export type ContentStatus = "PLAYABLE" | "NO_PUBLISHED_LESSON" | "NO_COMPLETION_POLICY" | "CONTENT_REVIEW_REQUIRED";
export type PathNodeType = "ERA" | "PERIOD" | "PHASE";

export interface PathVersion {
  id: string;
  pathCode: string;
  versionNo: number;
  title: string;
  description: string | null;
  status: PathStatus;
  revision: number;
  publishedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ChapterInput {
  code: string;
  title: string;
  description: string;
  startYear: number;
  endYear: number;
  periodLabel: string;
  themeKey: string;
  parentId?: string | null;
  nodeType?: PathNodeType;
}

export interface PathChapter {
  chapter: Omit<ChapterInput, "description"> & {
    id: string;
    pathVersionId: string;
    parentId: string | null;
    nodeType: PathNodeType;
    description: string | null;
    sortOrder: number;
  };
  events: PathEvent[];
}

export interface PathEvent {
  node: {
    id: string;
    chapterId: string;
    pathVersionId: string;
    eventId: string;
    sortOrder: number;
    participationType: ParticipationType;
  };
  title: string | null;
  startYear: number | null;
  endYear?: number | null;
  datePrecision?: string | null;
  eventStatus: PathStatus | null;
  canonicalEventId: string;
  alias: boolean;
  contentStatus: ContentStatus;
  publishedPolicyId: string | null;
  publishedPolicyVersion: number | null;
  requiredLessonIds: string[] | null;
  optionalLessonIds: string[] | null;
  lessons: PathLesson[];
}

export interface PathLesson {
  node: { id: string; eventNodeId: string; eventId: string; lessonId: string; sortOrder: number };
  title: string | null;
  status: PathStatus | "MISSING";
  coverAssetId?: string | null;
}

export interface PathDetail { version: PathVersion; chapters: PathChapter[] }
export interface PathAuditIssue {
  level: "ERROR" | "WARNING" | "INFO";
  code: string;
  message: string;
  targetId: string | null;
}
export interface PathAudit {
  pathCode: string;
  pathVersion: number;
  status: PathStatus;
  totalChapters: number;
  totalEvents: number;
  totalLessons: number;
  contentStatusCounts: Record<string, number>;
  issues: PathAuditIssue[];
  duplicateAliases: unknown[];
  emptyChapters: string[];
}
