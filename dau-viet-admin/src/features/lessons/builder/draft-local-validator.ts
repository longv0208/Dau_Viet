import type { Activity, Draft, Stage } from "./draft-model";

/**
 * Lỗi client-side giống backend FieldError — đủ để chặn submit sớm và
 * hiển thị vị trí cụ thể. Không thay thế validate server (evidence/asset
 * existence vẫn cần DB) nhưng bắt được các lỗi cấu hình phổ biến trước khi
 * PUT /draft.
 */
export interface LocalFieldError {
  /** Path dạng backend: `stages[id=X].activities[N].config.<field>` */
  path: string;
  /** Mã lỗi — dùng chung key với CODE_MESSAGES trong validation-panel. */
  code: string;
  /** Mô tả tiếng Việt cụ thể cho lỗi này (ghi đè CODE_MESSAGES khi có). */
  detail?: string;
}

/** Tra cứu tên bằng chứng/asset để message không phải UUID trần. */
export interface ValidationCatalog {
  /** id → title; missing id = bằng chứng đã xoá / không thuộc event. */
  evidenceTitle?: (id: string) => string | undefined;
  /** id → filename/label; missing = asset không còn. */
  assetLabel?: (id: string) => string | undefined;
}

interface Ctx {
  stage: Stage;
  stageIdx: number;
  act: Activity;
  actIdx: number;
  out: LocalFieldError[];
  cat?: ValidationCatalog;
}

function evidenceLabel(cat: ValidationCatalog | undefined, id: string): string {
  const t = cat?.evidenceTitle?.(id);
  if (t) return `«${t.length > 50 ? t.slice(0, 50) + "…" : t}»`;
  return `'${id.slice(0, 8)}…'`;
}

const REQUIRED_FEEDBACK_TYPES = new Set([
  "MULTIPLE_CHOICE",
  "EVIDENCE_SELECT",
  "MATCHING",
  "REASONING_CONNECT",
  "HYPOTHESIS_CHOICE",
  "DRAG_ORDER",
  "VERIFICATION",
  "CER",
  "CER_CHOICE",
]);

function apath(c: Ctx, field?: string): string {
  const base = `stages[id=${c.stage.id}].activities[${c.actIdx}]`;
  return field ? `${base}.config.${field}` : `${base}.config`;
}

function push(c: Ctx, field: string | undefined, code: string, detail?: string) {
  c.out.push({ path: apath(c, field), code, detail });
}

function getArray(v: unknown): unknown[] | null {
  return Array.isArray(v) ? v : null;
}

function getStr(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

/* ---- Per-type rules (mirror backend validators, PUBLISH level) ---- */

function validateViewImage(c: Ctx) {
  const cfg = c.act.config ?? {};
  const id = cfg.imageAssetId;
  if (id == null || id === "") {
    push(c, "imageAssetId", "MISSING_FIELD", "Chưa chọn ảnh minh hoạ.");
  }
}

function validateEvidenceSelect(c: Ctx) {
  const cfg = c.act.config ?? {};
  const vis = getArray(cfg.visibleEvidenceIds) ?? [];
  if (vis.length < 1) {
    push(c, "visibleEvidenceIds", "INVALID_CONFIG",
      "Cần ít nhất 1 bằng chứng hiển thị cho học viên.");
    return;
  }
  const min = typeof cfg.minRequired === "number" ? cfg.minRequired : 1;
  if (min > vis.length) {
    push(c, "minRequired", "INVALID_CONFIG",
      `Yêu cầu chọn tối thiểu ${min} nhưng chỉ có ${vis.length} bằng chứng — hạ số tối thiểu hoặc thêm bằng chứng.`);
  }
  if (cfg.graded === true) {
    const accepted = getArray(cfg.acceptedEvidenceIds);
    if (!accepted || accepted.length === 0) {
      push(c, "acceptedEvidenceIds", "MISSING_FIELD",
        "Chế độ chấm điểm cần ít nhất 1 bằng chứng đúng.");
    } else {
      const visSet = new Set(vis.filter((x): x is string => typeof x === "string"));
      const extra = accepted.filter((x) => typeof x === "string" && !visSet.has(x));
      if (extra.length > 0) {
        push(c, "acceptedEvidenceIds", "INVALID_CONFIG",
          `Bằng chứng đúng ${extra.map((x) => evidenceLabel(c.cat, String(x))).join(", ")} chưa nằm trong danh sách hiển thị.`);
      }
    }
  }
}

function validateDragOrder(c: Ctx) {
  const cfg = c.act.config ?? {};
  const items = getArray(cfg.items) ?? [];
  if (items.length < 2) {
    push(c, "items", "INVALID_CONFIG", "Cần ít nhất 2 mục để sắp xếp.");
    return;
  }
  const itemIds = new Set(
    items.map((it) => (it && typeof it === "object" ? (it as { id?: unknown }).id : it))
      .filter((x): x is string => typeof x === "string"),
  );
  const expected = getArray(cfg.expectedOrder);
  if (!expected) {
    push(c, "expectedOrder", "MISSING_FIELD", "Chưa khai báo thứ tự đúng.");
    return;
  }
  const expSet = new Set(expected.filter((x): x is string => typeof x === "string"));
  if (expSet.size !== itemIds.size || ![...expSet].every((x) => itemIds.has(x))) {
    push(c, "expectedOrder", "INVALID_CONFIG",
      "Thứ tự đúng phải là hoán vị của các mục — kiểm tra lại id mục.");
  }
}

function validateCerChoice(c: Ctx) {
  const cfg = c.act.config ?? {};
  const claims = getArray(cfg.claims) ?? [];
  const evidOpts = getArray(cfg.evidenceOptions) ?? [];
  const reasoningOpts = getArray(cfg.reasoningOptions) ?? [];
  const combos = getArray(cfg.acceptedCombos) ?? [];

  if (claims.length === 0) {
    push(c, "claims", "INVALID_CONFIG", "Cần ít nhất 1 nhận định để học viên chọn.");
  }
  if (evidOpts.length === 0) {
    push(c, "evidenceOptions", "INVALID_CONFIG",
      "Cần ít nhất 1 bằng chứng trong tuỳ chọn.");
  }
  if (reasoningOpts.length === 0) {
    push(c, "reasoningOptions", "INVALID_CONFIG",
      "Cần ít nhất 1 lập luận trong tuỳ chọn.");
  }
  if (combos.length === 0) {
    push(c, "acceptedCombos", "MISSING_FIELD",
      "Cần ít nhất 1 tổ hợp đúng (claim + bằng chứng + lập luận).");
    return;
  }

  const claimIds = new Set(
    claims.map((x) => (x && typeof x === "object" ? (x as { id?: unknown }).id : null))
      .filter((x): x is string => typeof x === "string"),
  );
  const evidIds = new Set(
    evidOpts.map((x) => (x && typeof x === "object" ? (x as { id?: unknown }).id : null))
      .filter((x): x is string => typeof x === "string"),
  );
  const reasoningIds = new Set(
    reasoningOpts.map((x) => (x && typeof x === "object" ? (x as { id?: unknown }).id : null))
      .filter((x): x is string => typeof x === "string"),
  );

  for (let i = 0; i < combos.length; i++) {
    const combo = combos[i];
    if (!combo || typeof combo !== "object") continue;
    const cb = combo as { claimId?: unknown; evidenceIds?: unknown; reasoningId?: unknown };
    const claimId = getStr(cb.claimId);
    if (claimId == null || !claimIds.has(claimId)) {
      push(c, `acceptedCombos[${i}].claimId`, "INVALID_CONFIG",
        `Tổ hợp ${i + 1}: claim không khớp nhận định nào.`);
    }
    const evIds = getArray(cb.evidenceIds) ?? [];
    for (const e of evIds) {
      const s = getStr(e);
      if (s != null && !evidIds.has(s)) {
        push(c, `acceptedCombos[${i}].evidenceIds`, "INVALID_CONFIG",
          `Tổ hợp ${i + 1}: bằng chứng ${evidenceLabel(c.cat, s)} chưa có trong danh sách tuỳ chọn bằng chứng.`);
        break;
      }
    }
    const rid = getStr(cb.reasoningId);
    if (rid == null || !reasoningIds.has(rid)) {
      push(c, `acceptedCombos[${i}].reasoningId`, "INVALID_CONFIG",
        `Tổ hợp ${i + 1}: lập luận không khớp tuỳ chọn nào.`);
    }
  }
}

function validateFeedback(c: Ctx) {
  if (!REQUIRED_FEEDBACK_TYPES.has(c.act.type)) return;
  const fb = c.act.feedback ?? {};
  const missing: string[] = [];
  if (typeof fb.COMPLETED !== "string" || !fb.COMPLETED.trim()) missing.push("COMPLETED");
  if (typeof fb.INCORRECT !== "string" || !fb.INCORRECT.trim()) missing.push("INCORRECT");
  if (missing.length > 0) {
    c.out.push({
      path: `stages[id=${c.stage.id}].activities[${c.actIdx}].feedback`,
      code: "MISSING_FIELD",
      detail: `Thiếu phản hồi ${missing.join(" + ")} — điền đủ để học viên biết đúng/sai.`,
    });
  }
}

/* ---- Public API ---- */

/**
 * Chạy toàn bộ rule client-side trên draft hiện tại. Trả về [] nếu OK để
 * submit. Cùng thứ tự duyệt với backend để error ordering quen thuộc.
 */
export function validateDraftLocally(
  draft: Draft,
  catalog?: ValidationCatalog,
): LocalFieldError[] {
  const out: LocalFieldError[] = [];
  for (let s = 0; s < draft.stages.length; s++) {
    const stage = draft.stages[s];
    if (!stage) continue;
    for (let a = 0; a < stage.activities.length; a++) {
      const act = stage.activities[a];
      if (!act) continue;
      const ctx: Ctx = { stage, stageIdx: s, act, actIdx: a, out, cat: catalog };
      switch (act.type) {
        case "VIEW_IMAGE": validateViewImage(ctx); break;
        case "EVIDENCE_SELECT": validateEvidenceSelect(ctx); break;
        case "DRAG_ORDER": validateDragOrder(ctx); break;
        case "CER_CHOICE": validateCerChoice(ctx); break;
      }
      validateFeedback(ctx);
    }
  }
  return out;
}
