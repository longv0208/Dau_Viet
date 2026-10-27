import type { PathChapter, PathDetail, PathNodeType } from "@/lib/dto/learning-path";

export type PathChange = (
  suffix: string,
  method: "POST" | "PATCH" | "DELETE" | "PUT",
  body?: Record<string, unknown>,
) => Promise<PathDetail | null>;

export function historicalYear(year: number | null | undefined): string {
  if (year == null) return "Chưa rõ năm";
  return year < 0 ? `${Math.abs(year)} TCN` : `${year}`;
}

export const CONTENT_LABELS: Record<string, string> = {
  PLAYABLE: "Sẵn sàng học",
  NO_PUBLISHED_LESSON: "Chưa có bài đã xuất bản",
  NO_COMPLETION_POLICY: "Chưa có chính sách hoàn thành",
  CONTENT_REVIEW_REQUIRED: "Cần kiểm tra nội dung",
};

export const NODE_TYPE_META: Record<
  PathNodeType,
  {
    label: string;
    shortLabel: string;
    description: string;
    canAttachEvents: boolean;
    badgeClass: string;
  }
> = {
  ERA: {
    label: "Đại thời kỳ (ERA)",
    shortLabel: "Đại thời kỳ",
    description: "Nhóm cấp cao nhất ở gốc lộ trình, chứa các Thời kỳ (PERIOD). Không gắn sự kiện trực tiếp.",
    canAttachEvents: false,
    badgeClass: "bg-brand text-white",
  },
  PERIOD: {
    label: "Thời kỳ (PERIOD)",
    shortLabel: "Thời kỳ",
    description: "Đơn vị mở khóa tuần tự của học viên, trực thuộc một Đại thời kỳ (ERA) hoặc ở gốc.",
    canAttachEvents: true,
    badgeClass: "border border-warning/60 bg-warning/20 text-ink",
  },
  PHASE: {
    label: "Giai đoạn con (PHASE)",
    shortLabel: "Giai đoạn",
    description: "Nhánh con trực thuộc một Thời kỳ (PERIOD) để chia nhỏ chuỗi sự kiện dài.",
    canAttachEvents: true,
    badgeClass: "border border-border bg-surface-alt text-ink-muted",
  },
};

export function resolveNodeType(row: PathChapter): PathNodeType {
  const raw = row.chapter.nodeType;
  if (raw === "ERA" || raw === "PERIOD" || raw === "PHASE") return raw;
  return "PERIOD";
}

export function canAttachEventsToChapter(row: PathChapter | undefined): boolean {
  if (!row) return false;
  return NODE_TYPE_META[resolveNodeType(row)].canAttachEvents;
}

export interface ChapterTreeNode {
  row: PathChapter;
  nodeType: PathNodeType;
  depth: number;
  children: ChapterTreeNode[];
  totalSubtreeEvents: number;
}

/**
 * Xây dựng cây phân cấp ERA -> PERIOD -> PHASE từ danh sách phẳng `detail.chapters`,
 * bảo toàn thứ tự `sortOrder` trong từng nhóm cùng `parentId`.
 */
export function buildChapterTree(chapters: PathChapter[]): ChapterTreeNode[] {
  const byId = new Map<string, ChapterTreeNode>();
  for (const row of chapters) {
    byId.set(row.chapter.id, {
      row,
      nodeType: resolveNodeType(row),
      depth: 0,
      children: [],
      totalSubtreeEvents: row.events.length,
    });
  }

  const roots: ChapterTreeNode[] = [];
  for (const row of chapters) {
    const node = byId.get(row.chapter.id)!;
    const parentId = row.chapter.parentId;
    if (parentId && byId.has(parentId) && parentId !== row.chapter.id) {
      const parent = byId.get(parentId)!;
      parent.children.push(node);
    } else {
      roots.push(node);
    }
  }

  const sortGroup = (nodes: ChapterTreeNode[], depth: number) => {
    nodes.sort((a, b) => a.row.chapter.sortOrder - b.row.chapter.sortOrder);
    for (const n of nodes) {
      n.depth = depth;
      sortGroup(n.children, depth + 1);
      n.totalSubtreeEvents =
        n.row.events.length +
        n.children.reduce((acc, child) => acc + child.totalSubtreeEvents, 0);
    }
  };

  sortGroup(roots, 0);
  return roots;
}

/**
 * Lọc danh sách các node cha hợp lệ theo quy tắc PathHierarchyValidator:
 * - ERA: chỉ ở gốc (parentId = null)
 * - PERIOD: ở gốc (parentId = null) hoặc con của ERA
 * - PHASE: bắt buộc là con của PERIOD
 */
export function getAllowedParentChapters(
  chapters: PathChapter[],
  targetNodeType: PathNodeType,
  editingChapterId?: string,
): PathChapter[] {
  if (targetNodeType === "ERA") {
    return [];
  }
  if (targetNodeType === "PERIOD") {
    return chapters.filter(
      (c) => c.chapter.id !== editingChapterId && resolveNodeType(c) === "ERA",
    );
  }
  return chapters.filter(
    (c) => c.chapter.id !== editingChapterId && resolveNodeType(c) === "PERIOD",
  );
}
