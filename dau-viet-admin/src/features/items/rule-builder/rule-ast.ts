/**
 * GAME-06 Module C — AST <-> form mapping cho Rule Builder.
 * Pure functions, không phụ thuộc React — unit test bằng Vitest.
 *
 * Contract backend (ItemConditionParser):
 *  - leaf: { type: LeafType, ...params } — chỉ trường thuộc shape của type
 *    (vd COLLECTION_COUNT chỉ được có threshold);
 *  - operator: { all: [leaf…] } | { any: [leaf…] } — depth ≤ 2, con phải
 *    là leaf (không lồng operator);
 *  - 1 leaf duy nhất → KHÔNG wrap operator (canonical của backend).
 */

export type LeafType =
  | "LESSON_COMPLETED"
  | "LESSON_MASTERED"
  | "COLLECTION_COUNT"
  | "LESSON_COUNT"
  | "EVENT_COMPLETED"
  | "EVENT_MASTERED"
  | "EVENT_EVIDENCE_COUNT"
  | "SPECIFIC_EVIDENCE_SET"
  | "TOTAL_EVENTS_COMPLETED"
  | "TOTAL_EVENTS_MASTERED"
  | "LEVEL_AT_LEAST";

export const ALL_LEAF_TYPES: LeafType[] = [
  "LESSON_COMPLETED",
  "LESSON_MASTERED",
  "COLLECTION_COUNT",
  "LESSON_COUNT",
  "EVENT_COMPLETED",
  "EVENT_MASTERED",
  "EVENT_EVIDENCE_COUNT",
  "SPECIFIC_EVIDENCE_SET",
  "TOTAL_EVENTS_COMPLETED",
  "TOTAL_EVENTS_MASTERED",
  "LEVEL_AT_LEAST",
];

const LEAF_TYPES = new Set<string>(ALL_LEAF_TYPES);

export interface LeafForm {
  /** React key — không đưa vào AST. */
  localId: string;
  type: LeafType;
  eventId?: string;
  lessonId?: string;
  evidenceIds?: string[];
  threshold?: number;
  level?: number;
}

export interface BuilderState {
  root: "all" | "any";
  children: LeafForm[];
}

export type ConditionAst = Record<string, unknown>;

export const EMPTY_STATE: BuilderState = { root: "all", children: [] };

/** Leaf -> JSON theo đúng allowed-field contract của từng type. */
export function leafToJson(leaf: LeafForm): ConditionAst {
  switch (leaf.type) {
    case "LESSON_COMPLETED":
      return { type: leaf.type, lessonId: leaf.lessonId };
    case "LESSON_MASTERED":
      return {
        type: leaf.type,
        lessonId: leaf.lessonId,
        threshold: leaf.threshold,
      };
    case "COLLECTION_COUNT":
    case "LESSON_COUNT":
    case "TOTAL_EVENTS_COMPLETED":
    case "TOTAL_EVENTS_MASTERED":
      return { type: leaf.type, threshold: leaf.threshold };
    case "EVENT_COMPLETED":
    case "EVENT_MASTERED":
      return { type: leaf.type, eventId: leaf.eventId };
    case "EVENT_EVIDENCE_COUNT":
      return {
        type: leaf.type,
        eventId: leaf.eventId,
        threshold: leaf.threshold,
      };
    case "SPECIFIC_EVIDENCE_SET":
      return {
        type: leaf.type,
        eventId: leaf.eventId,
        evidenceIds: leaf.evidenceIds ?? [],
      };
    case "LEVEL_AT_LEAST":
      return { type: leaf.type, level: leaf.level };
  }
}

/**
 * Form -> AST canonical: 0 leaf → null; 1 leaf → unwrap (backend cũng
 * normalize về dạng này); ≥2 → bọc operator root.
 */
export function formToAst(state: BuilderState): ConditionAst | null {
  const leaves = state.children.map(leafToJson);
  if (leaves.length === 0) return null;
  if (leaves.length === 1) return leaves[0] as ConditionAst;
  return { [state.root]: leaves };
}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function jsonToLeaf(node: Record<string, unknown>): LeafForm {
  const type =
    typeof node.type === "string" && LEAF_TYPES.has(node.type)
      ? (node.type as LeafType)
      : "COLLECTION_COUNT";
  const str = (v: unknown) => (typeof v === "string" ? v : undefined);
  const num = (v: unknown) => (typeof v === "number" ? v : undefined);
  const leaf: LeafForm = {
    localId: crypto.randomUUID(),
    type,
    eventId: str(node.eventId),
    lessonId: str(node.lessonId),
    threshold: num(node.threshold),
    level: num(node.level),
  };
  if (Array.isArray(node.evidenceIds)) {
    leaf.evidenceIds = node.evidenceIds.filter(
      (x): x is string => typeof x === "string",
    );
  }
  return leaf;
}

/**
 * AST -> form. JSON lạ/sai shape → null (caller fallback EMPTY_STATE và
 * cảnh báo admin chỉnh tay). Không throw — đây là đường đọc đa dạng.
 */
export function astToForm(ast: unknown): BuilderState | null {
  if (!isRecord(ast)) return null;
  if (Array.isArray(ast.all)) {
    return {
      root: "all",
      children: (ast.all as unknown[]).filter(isRecord).map(jsonToLeaf),
    };
  }
  if (Array.isArray(ast.any)) {
    return {
      root: "any",
      children: (ast.any as unknown[]).filter(isRecord).map(jsonToLeaf),
    };
  }
  if (typeof ast.type === "string") {
    return { root: "all", children: [jsonToLeaf(ast)] };
  }
  return null;
}

/**
 * Leaf có mang eventId không — dùng cho scope gating (item EVENT_SCOPED/
 * UNRESOLVED bắt buộc ≥1 leaf event-scoped) và warning UI.
 */
export function leafUsesEvent(type: LeafType): boolean {
  return (
    type === "EVENT_COMPLETED" ||
    type === "EVENT_MASTERED" ||
    type === "EVENT_EVIDENCE_COUNT" ||
    type === "SPECIFIC_EVIDENCE_SET"
  );
}

/** Leaf đã điền đủ trường bắt buộc chưa (client-side, không gọi server). */
export function isLeafComplete(leaf: LeafForm): boolean {
  switch (leaf.type) {
    case "LESSON_COMPLETED":
      return Boolean(leaf.lessonId);
    case "LESSON_MASTERED":
      return Boolean(leaf.lessonId) && positive(leaf.threshold);
    case "COLLECTION_COUNT":
    case "LESSON_COUNT":
    case "TOTAL_EVENTS_COMPLETED":
    case "TOTAL_EVENTS_MASTERED":
      return positive(leaf.threshold);
    case "EVENT_COMPLETED":
    case "EVENT_MASTERED":
      return Boolean(leaf.eventId);
    case "EVENT_EVIDENCE_COUNT":
      return Boolean(leaf.eventId) && positive(leaf.threshold);
    case "SPECIFIC_EVIDENCE_SET":
      return Boolean(leaf.eventId) && (leaf.evidenceIds?.length ?? 0) > 0;
    case "LEVEL_AT_LEAST":
      return positive(leaf.level);
  }
}

function positive(n: number | undefined): n is number {
  return typeof n === "number" && Number.isInteger(n) && n > 0;
}

/* ---------- mô tả tiếng Việt ---------- */

export interface LeafLookups {
  lessonTitle?: (id: string) => string | undefined;
  eventTitle?: (id: string) => string | undefined;
}

const lessonName = (id: string | undefined, l?: LeafLookups) =>
  (id && l?.lessonTitle?.(id)) ?? "bài học đã chọn";
const eventName = (id: string | undefined, l?: LeafLookups) =>
  (id && l?.eventTitle?.(id)) ?? "sự kiện đã chọn";

/** Mô tả tự nhiên của leaf — hiển thị dưới mỗi row cho admin đọc lại. */
export function describeLeaf(leaf: LeafForm, lookups?: LeafLookups): string {
  switch (leaf.type) {
    case "LESSON_COMPLETED":
      return `Hoàn thành bài học "${lessonName(leaf.lessonId, lookups)}"`;
    case "LESSON_MASTERED":
      return `Đạt thành thạo bài "${lessonName(leaf.lessonId, lookups)}" (≥ ${leaf.threshold ?? "?"}%)`;
    case "COLLECTION_COUNT":
      return `Sưu tầm đủ ${leaf.threshold ?? "?"} bằng chứng`;
    case "LESSON_COUNT":
      return `Hoàn thành đủ ${leaf.threshold ?? "?"} bài học`;
    case "EVENT_COMPLETED":
      return `Hoàn thành sự kiện "${eventName(leaf.eventId, lookups)}"`;
    case "EVENT_MASTERED":
      return `Đạt thành thạo sự kiện "${eventName(leaf.eventId, lookups)}"`;
    case "EVENT_EVIDENCE_COUNT":
      return `Sưu tầm ≥ ${leaf.threshold ?? "?"} bằng chứng của sự kiện "${eventName(leaf.eventId, lookups)}"`;
    case "SPECIFIC_EVIDENCE_SET":
      return `Sưu tầm ${leaf.evidenceIds?.length ?? 0} bằng chứng chỉ định của sự kiện "${eventName(leaf.eventId, lookups)}"`;
    case "TOTAL_EVENTS_COMPLETED":
      return `Hoàn thành tổng ${leaf.threshold ?? "?"} sự kiện`;
    case "TOTAL_EVENTS_MASTERED":
      return `Đạt thành thạo tổng ${leaf.threshold ?? "?"} sự kiện`;
    case "LEVEL_AT_LEAST":
      return `Đạt cấp độ ≥ ${leaf.level ?? "?"}`;
  }
}
