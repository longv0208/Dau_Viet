/**
 * Typed model for the backend `draftJson` document (DraftSchema.java).
 * Round-trip rule: every object keeps unknown keys via `...rest` — the
 * builder never silently drops fields it doesn't model.
 *
 * Verified against DraftSchema.java (see plans/reports/planner-261017-0531-…).
 */

export const STAGE_TYPES = [
  "CONTEXT",
  "DISCOVERY",
  "EVIDENCE",
  "REASONING",
  "HYPOTHESIS",
  "RECONSTRUCTION",
  "VERIFICATION",
  "CONCLUSION",
  "REFLECTION",
] as const;
export type StageType = (typeof STAGE_TYPES)[number];

export const ACTIVITY_TYPES = [
  "READ",
  "VIEW_IMAGE",
  "MULTIPLE_CHOICE",
  "EXPLORE_MAP",
  "EVIDENCE_SELECT",
  "MATCHING",
  "REASONING_CONNECT",
  "HYPOTHESIS_CHOICE",
  "DRAG_ORDER",
  "VERIFICATION",
  "CER",
  "CER_CHOICE",
  "REFLECTION_PROMPT",
] as const;
export type ActivityType = (typeof ACTIVITY_TYPES)[number];

/** Mirrors DraftSchema.STAGE_ALLOWED_ACTIVITIES — READ is universal. */
export const STAGE_ALLOWED_ACTIVITIES: Record<StageType, ActivityType[]> = {
  CONTEXT: ["READ", "VIEW_IMAGE"],
  DISCOVERY: [
    "READ", "VIEW_IMAGE", "MULTIPLE_CHOICE", "MATCHING",
    "DRAG_ORDER", "REASONING_CONNECT", "EXPLORE_MAP", "EVIDENCE_SELECT",
  ],
  EVIDENCE: ["EVIDENCE_SELECT", "MULTIPLE_CHOICE", "VIEW_IMAGE", "READ"],
  REASONING: ["MATCHING", "REASONING_CONNECT", "MULTIPLE_CHOICE", "READ"],
  HYPOTHESIS: ["HYPOTHESIS_CHOICE", "MULTIPLE_CHOICE", "MATCHING", "REASONING_CONNECT", "READ"],
  RECONSTRUCTION: [
    "DRAG_ORDER", "MATCHING", "REASONING_CONNECT", "MULTIPLE_CHOICE",
    "VIEW_IMAGE", "READ", "CER_CHOICE", "CER", "REFLECTION_PROMPT",
  ],
  VERIFICATION: ["VERIFICATION", "EVIDENCE_SELECT", "MULTIPLE_CHOICE", "READ"],
  CONCLUSION: ["CER", "CER_CHOICE", "READ"],
  REFLECTION: ["REFLECTION_PROMPT", "READ"],
};

/** Canonical 4 clue types for Step 1 (DISCOVERY) of the 4-step learning flow. */
export const CLUE_TYPES = ["CONTEXT", "CHARACTERS", "DEVELOPMENT", "SIGNIFICANCE"] as const;
export type ClueType = (typeof CLUE_TYPES)[number];

export const CLUE_LABELS: Record<ClueType, { label: string; description: string; hint: string }> = {
  CONTEXT: {
    label: "Bối cảnh",
    description: "Tìm hiểu hoàn cảnh lịch sử dẫn đến sự kiện",
    hint: "Bối cảnh xã hội, chính trị, kinh tế thời kỳ này",
  },
  CHARACTERS: {
    label: "Nhân vật",
    description: "Khám phá các nhân vật lịch sử và vai trò",
    hint: "Những nhân vật tham gia chính và vai trò của họ",
  },
  DEVELOPMENT: {
    label: "Diễn biến",
    description: "Theo dõi các mốc diễn biến chính của sự kiện",
    hint: "Trình tự diễn biến, mốc thời gian quan trọng",
  },
  SIGNIFICANCE: {
    label: "Ý nghĩa",
    description: "Đúc kết kết quả và ý nghĩa lịch sử",
    hint: "Kết quả, tầm ảnh hưởng và ý nghĩa của sự kiện",
  },
};

/** 4-step flow stage types in canonical order. */
export const FOUR_STEP_STAGE_ORDER: StageType[] = [
  "DISCOVERY", "HYPOTHESIS", "VERIFICATION", "RECONSTRUCTION",
];

/** Detect whether a draft follows the 4-step flow (clue activities in DISCOVERY). */
export function isFourStepDraft(draft: Draft): boolean {
  if (draft.flowModel === "FOUR_STEP") return true;
  return draft.stages.some(
    (s) => s.type === "DISCOVERY" && s.activities.some((a) => a.clueType != null),
  );
}

/**
 * Issue #47: Bộ câu phản hồi học viên mặc định chuẩn văn phong Dấu Việt
 * theo từng loại hoạt động. Đảm bảo vượt qua đầy đủ rule kiểm tra của
 * `draft-local-validator.ts` và các `ActivityHandler` phía Backend.
 */
export const DEFAULT_FEEDBACK_BY_TYPE: Record<ActivityType, Record<string, string>> = {
  READ: {
    COMPLETED: "Bạn đã nắm được bối cảnh và tư liệu lịch sử ở bước này.",
    INCORRECT: "Hãy đọc kỹ lại đoạn tư liệu lịch sử để nắm rõ thông tin nhé!",
  },
  VIEW_IMAGE: {
    COMPLETED: "Bạn đã quan sát và ghi nhận xong tư liệu hình ảnh lịch sử.",
    INCORRECT: "Hãy quan sát kỹ lại hình ảnh tư liệu để không bỏ sót chi tiết nhé!",
  },
  EXPLORE_MAP: {
    COMPLETED: "Tuyệt vời! Bạn đã khám phá đầy đủ các điểm dấu tích trên bản đồ.",
    INCORRECT: "Hãy mở hết các điểm đánh dấu trên bản đồ để thu thập đủ thông tin nhé!",
  },
  REFLECTION_PROMPT: {
    COMPLETED: "Cảm ơn bạn đã chia sẻ góc nhìn và suy ngẫm lịch sử của mình!",
    INCORRECT: "Hãy viết thêm suy nghĩ của bạn về bài học lịch sử này nhé!",
  },
  MULTIPLE_CHOICE: {
    COMPLETED: "Chính xác! Bạn đã nắm vững dữ kiện lịch sử ở bước này.",
    INCORRECT: "Chưa chính xác. Hãy quan sát kỹ lại các tư liệu và dấu vết lịch sử để thử lại nhé!",
    EXHAUSTED: "Bạn đã dùng hết số lượt thử ở bước này. Hãy ghi nhớ đáp án đúng để tiếp tục hành trình khám phá nhé!",
  },
  EVIDENCE_SELECT: {
    COMPLETED: "Chính xác! Bạn đã thu thập đúng các bằng chứng lịch sử quan trọng.",
    PARTIAL: "Gần chính xác! Bạn đã chọn đúng một phần bằng chứng, hãy rà soát lại các tư liệu còn thiếu nhé.",
    INCORRECT: "Chưa chính xác. Hãy đối chiếu kỹ nguồn tư liệu để chọn đúng bằng chứng liên quan nhé!",
    EXHAUSTED: "Bạn đã dùng hết số lượt thử ở bước này. Hãy ghi nhớ các bằng chứng chuẩn xác để tiếp tục điều tra nhé!",
  },
  MATCHING: {
    COMPLETED: "Chính xác! Bạn đã ghép nối đúng các mối liên hệ lịch sử.",
    PARTIAL: "Gần chính xác! Một số cặp ghép đã đúng, hãy kiểm tra lại các cặp còn lại nhé.",
    INCORRECT: "Chưa chính xác. Hãy suy luận lại mối liên hệ giữa các dữ kiện để ghép cho đúng nhé!",
    EXHAUSTED: "Bạn đã dùng hết số lượt thử ở bước này. Hãy ghi nhớ các cặp ghép đúng để tiếp tục hành trình nhé!",
  },
  REASONING_CONNECT: {
    COMPLETED: "Chính xác! Sơ đồ suy luận của bạn phản ánh đúng mạch liên kết lịch sử.",
    PARTIAL: "Gần chính xác! Bạn đã nối đúng một phần quan hệ, hãy rà soát lại các mắt xích còn thiếu nhé.",
    INCORRECT: "Chưa chính xác. Hãy phân tích lại quan hệ nhân quả giữa các dữ kiện lịch sử nhé!",
    EXHAUSTED: "Bạn đã dùng hết số lượt thử ở bước này. Hãy ghi nhớ mạch suy luận chuẩn để đi tiếp nhé!",
  },
  HYPOTHESIS_CHOICE: {
    COMPLETED: "Bạn đã lựa chọn giả thuyết lịch sử để chuẩn bị bước vào giai đoạn kiểm chứng.",
    INCORRECT: "Hãy chọn một giả thuyết phù hợp kèm bằng chứng dẫn chiếu để tiếp tục nhé!",
    EXHAUSTED: "Bạn đã hoàn tất lượt chọn giả thuyết. Hãy tiếp tục đối chiếu với bằng chứng ở bước tiếp theo nhé!",
  },
  DRAG_ORDER: {
    COMPLETED: "Chính xác! Bạn đã tái dựng đúng trình tự diễn biến của sự kiện lịch sử.",
    PARTIAL: "Gần chính xác! Một số mốc đã đúng vị trí, hãy sắp xếp lại các bước còn lệch nhé.",
    INCORRECT: "Chưa chính xác. Hãy đối chiếu lại trình tự thời gian và diễn biến tư liệu để sắp xếp lại nhé!",
    EXHAUSTED: "Bạn đã dùng hết số lượt thử ở bước này. Hãy ghi nhớ trình tự diễn biến đúng của sự kiện nhé!",
  },
  VERIFICATION: {
    COMPLETED: "Kiểm chứng hoàn tất! Bạn đã đối chiếu thành công giả thuyết với hệ thống bằng chứng.",
    SUPPORTED: "Bằng chứng lịch sử hoàn toàn củng cố cho giả thuyết bạn đã chọn!",
    PARTIAL: "Bằng chứng hiện có mới củng cố một phần giả thuyết. Hãy bổ sung hoặc rà soát lại tư liệu nhé!",
    CONTRADICTED: "Các bằng chứng thu thập được đã bác bỏ giả thuyết này. Hãy đối chiếu lại tư liệu nhé!",
    INCORRECT: "Chưa chính xác. Hãy kiểm tra lại mối liên hệ giữa giả thuyết và các bằng chứng đã thu thập nhé!",
    EXHAUSTED: "Bạn đã dùng hết số lượt kiểm chứng ở bước này. Hãy xem kỹ phân tích bằng chứng để rút ra kết luận nhé!",
  },
  CER: {
    COMPLETED: "Tuyệt vời! Lập luận Kết luận – Bằng chứng – Suy luận (CER) của bạn rất chặt chẽ và thuyết phục.",
    INCORRECT: "Lập luận chưa đầy đủ. Hãy đảm bảo nêu rõ Nhận định, trích dẫn Bằng chứng và giải thích Suy luận nhé!",
    EXHAUSTED: "Bạn đã hoàn thành bước xây dựng kết luận lịch sử. Hãy xem lại gợi ý chuẩn để củng cố kiến thức nhé!",
  },
  CER_CHOICE: {
    COMPLETED: "Chính xác! Bạn đã kết hợp hoàn hảo Nhận định (Claim), Bằng chứng (Evidence) và Lập luận (Reasoning).",
    PARTIAL: "Gần chính xác! Bạn đã chọn đúng một phần trong bộ Kết luận – Bằng chứng – Lập luận, hãy chỉnh lại phần còn chưa khớp nhé.",
    INCORRECT: "Chưa chính xác. Hãy kiểm tra lại sự ăn khớp giữa Nhận định, Bằng chứng và Lập luận lịch sử nhé!",
    EXHAUSTED: "Bạn đã dùng hết số lượt thử ở bước này. Hãy ghi nhớ tổ hợp Kết luận – Bằng chứng – Lập luận chuẩn xác nhé!",
  },
};

/** Trả về bản sao bộ phản hồi mặc định cho loại hoạt động tương ứng. */
export function defaultFeedbackForActivity(type: ActivityType): Record<string, string> {
  return { ...(DEFAULT_FEEDBACK_BY_TYPE[type] ?? DEFAULT_FEEDBACK_BY_TYPE.MULTIPLE_CHOICE) };
}

/**
 * Hợp nhất phản hồi hiện có với bộ mặc định của loại hoạt động:
 * giữ nguyên mọi câu phản hồi quản trị viên đã nhập (khác rỗng),
 * tự động điền giá trị mặc định cho các trường còn thiếu hoặc đang trống.
 */
export function withDefaultFeedback(
  type: ActivityType,
  feedback?: Record<string, unknown>,
): Record<string, unknown> {
  const defaults = defaultFeedbackForActivity(type);
  const merged: Record<string, unknown> = { ...defaults };
  if (feedback && typeof feedback === "object" && !Array.isArray(feedback)) {
    for (const [k, v] of Object.entries(feedback)) {
      if (typeof v === "string") {
        if (v.trim().length > 0) {
          merged[k] = v;
        } else if (!(k in defaults)) {
          delete merged[k];
        }
      } else if (v !== undefined && v !== null) {
        merged[k] = v;
      }
    }
  }
  return merged;
}

export interface Activity {
  id: string;
  type: ActivityType;
  required?: boolean;
  instruction?: string;
  config?: Record<string, unknown>;
  validation?: Record<string, unknown>;
  feedback?: Record<string, unknown>;
  evidenceRefs?: string[];
  clueType?: ClueType;
  title?: string;
  description?: string;
  coverAssetId?: string;
  [key: string]: unknown;
}

export interface Stage {
  id: string;
  type: StageType;
  title?: string;
  description?: string;
  required?: boolean;
  allowFreeOrder?: boolean;
  activities: Activity[];
  nextStageIds?: string[];
  requiredEvidenceIds?: string[];
  [key: string]: unknown;
}

export interface Completion {
  requireAllRequiredStages?: boolean;
  requiredStageIds?: string[];
  minScore?: number;
  [key: string]: unknown;
}

export interface Draft {
  schemaVersion?: number;
  flowModel?: string;
  keyTakeaways?: string[];
  stages: Stage[];
  completion?: Completion;
  objectives?: unknown;
  [key: string]: unknown;
}

export class DraftParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DraftParseError";
  }
}

function normalizeActivity(raw: Record<string, unknown>): Activity {
  const type = raw.type as ActivityType;
  const isKnownType = typeof type === "string" && type in DEFAULT_FEEDBACK_BY_TYPE;
  const rawCfg =
    raw.config && typeof raw.config === "object" && !Array.isArray(raw.config)
      ? (raw.config as Record<string, unknown>)
      : undefined;
  const config =
    type === "EVIDENCE_SELECT"
      ? { ...(rawCfg ?? {}), graded: typeof rawCfg?.graded === "boolean" ? rawCfg.graded : true }
      : rawCfg;
  const rawFb =
    raw.feedback && typeof raw.feedback === "object" && !Array.isArray(raw.feedback)
      ? (raw.feedback as Record<string, unknown>)
      : undefined;
  const feedback = isKnownType ? withDefaultFeedback(type, rawFb) : rawFb;

  return {
    ...raw,
    ...(raw.id !== undefined ? { id: String(raw.id) } : {}),
    ...(raw.type !== undefined ? { type } : {}),
    required: true,
    ...(config !== undefined ? { config } : {}),
    ...(feedback !== undefined ? { feedback } : {}),
  } as Activity;
}

/** Tolerant parse: "{}" / "" / missing → empty draft; non-object → throws. */
export function parseDraft(json: string | null | undefined): Draft {
  const raw = (json ?? "").trim() || "{}";
  let obj: unknown;
  try {
    obj = JSON.parse(raw);
  } catch {
    throw new DraftParseError("Bản nháp không phải JSON hợp lệ");
  }
  if (typeof obj !== "object" || obj === null || Array.isArray(obj)) {
    throw new DraftParseError("Bản nháp phải là một JSON object");
  }
  const src = obj as Record<string, unknown>;
  const stages: Stage[] = Array.isArray(src.stages)
    ? src.stages
        .filter((s) => s && typeof s === "object")
        .map((s) => {
          const st = s as Record<string, unknown>;
          return {
            ...st,
            id: String(st.id ?? ""),
            type: st.type as StageType,
            required: true,
            activities: Array.isArray(st.activities)
              ? st.activities
                  .filter((a) => a && typeof a === "object")
                  .map((a) => normalizeActivity(a as Record<string, unknown>))
              : [],
          } as Stage;
        })
    : [];
  const completion =
    src.completion && typeof src.completion === "object" && !Array.isArray(src.completion)
      ? ({
          ...(src.completion as Record<string, unknown>),
          requireAllRequiredStages: true,
        } as Completion)
      : undefined;
  const draft: Draft = {
    ...src,
    stages,
    ...(completion !== undefined ? { completion } : {}),
  };
  if (draft.schemaVersion === undefined) draft.schemaVersion = 1;
  return draft;
}

/** Serialize back — preserves every key parseDraft kept while enforcing defaults. */
export function serializeDraft(draft: Draft): string {
  const normalized: Draft = {
    ...draft,
    stages: draft.stages.map((s) => ({
      ...s,
      required: true,
      activities: s.activities.map((a) =>
        normalizeActivity(a as unknown as Record<string, unknown>),
      ),
    })),
    ...(draft.completion && typeof draft.completion === "object"
      ? {
          completion: {
            ...draft.completion,
            requireAllRequiredStages: true,
          },
        }
      : {}),
  };
  return JSON.stringify(normalized);
}

/** Every id in the document — used by genSlugId uniqueness checks. */
export function allIds(draft: Draft): string[] {
  const ids: string[] = [];
  for (const s of draft.stages) {
    ids.push(s.id);
    for (const a of s.activities) ids.push(a.id);
  }
  return ids;
}
