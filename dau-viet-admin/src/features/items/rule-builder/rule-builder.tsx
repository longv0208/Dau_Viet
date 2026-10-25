"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { AdminItem, AdminRuleRequest } from "@/lib/dto/item";
import type { AdminRuleValidation } from "@/lib/dto/gamification";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";

import { ConditionLibrary } from "./condition-library";
import { RuleTree } from "./rule-tree";
import {
  EMPTY_STATE,
  astToForm,
  formToAst,
  isLeafComplete,
  leafUsesEvent,
  type BuilderState,
  type LeafType,
} from "./rule-ast";

/**
 * Rule Builder V2 (GAME-06 Module C) — 2 panel: thư viện điều kiện trái,
 * AST editor phải. "Kiểm tra" = POST /rule/validate (dry-run);
 * "Lưu điều kiện" = PUT /rule với `{ruleType:"RULE_V2", condition}`.
 */
export function RuleBuilder({ item }: { item: AdminItem }) {
  const qc = useQueryClient();
  const [state, setState] = useState<BuilderState>(EMPTY_STATE);
  const [parseError, setParseError] = useState<string | null>(null);
  const [validation, setValidation] = useState<AdminRuleValidation | null>(null);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);

  // Nạp AST đã publish vào form — fallback cảnh báo nếu không parse được.
  const rule = item.rule;
  useEffect(() => {
    const cond = rule?.conditionJson;
    if (!cond) {
      setState(EMPTY_STATE);
      setParseError(rule ? "Rule V1 hiện tại — thiết lập lại bằng builder để chuyển sang V2." : null);
      return;
    }
    const parsed = astToForm(cond);
    if (parsed) {
      setState(parsed);
      setParseError(null);
    } else {
      setState(EMPTY_STATE);
      setParseError("Không đọc được điều kiện hiện tại — hãy thiết lập lại.");
    }
  }, [rule]);

  const addLeaf = (type: LeafType) =>
    setState((s) => ({
      ...s,
      children: [
        ...s.children,
        {
          localId: crypto.randomUUID(),
          type,
          threshold: undefined,
          evidenceIds: [],
        },
      ],
    }));

  const allComplete =
    state.children.length > 0 && state.children.every(isLeafComplete);

  const validate = useMutation({
    mutationFn: (body: AdminRuleRequest) =>
      apiFetch<AdminRuleValidation>(`/admin/items/${item.id}/rule/validate`, {
        method: "POST",
        body: JSON.stringify(body),
      }),
    onSuccess: setValidation,
  });

  const save = useMutation({
    mutationFn: (body: AdminRuleRequest) =>
      apiFetch<AdminItem>(`/admin/items/${item.id}/rule`, {
        method: "PUT",
        body: JSON.stringify(body),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.items.detail(item.id) });
      qc.invalidateQueries({ queryKey: qk.ruleHistory(item.id) });
      setSaveMsg("Đã lưu điều kiện — học viên đã sở hữu vật phẩm không bị ảnh hưởng.");
      setValidation(null);
    },
  });

  const buildBody = (): AdminRuleRequest | null => {
    const condition = formToAst(state);
    if (!condition) return null;
    return { ruleType: "RULE_V2", condition, active: true };
  };

  const runValidate = () => {
    setSaveMsg(null);
    const body = buildBody();
    if (!body) {
      setValidation(null);
      return;
    }
    validate.mutate(body);
  };

  const runSave = () => {
    setSaveMsg(null);
    const body = buildBody();
    if (!body) return;
    save.mutate(body);
  };

  const eventScopedLeaf = state.children.some((c) => leafUsesEvent(c.type));
  const needsEventLeaf =
    item.scope === "EVENT_SCOPED" || item.scope === "UNRESOLVED";

  const actionError = validate.error ?? save.error;

  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-[260px_1fr]">
      <div className="rounded-md border border-border bg-surface-subtle p-3">
        <h3 className="mb-2 text-sm font-semibold text-ink">Thư viện điều kiện</h3>
        <ConditionLibrary onAdd={addLeaf} />
      </div>

      <div className="flex flex-col gap-3">
        {parseError && (
          <p className="rounded-md bg-warning/25 px-3 py-2 text-sm text-ink">
            {parseError}
          </p>
        )}

        <RuleTree state={state} onChange={setState} />

        {needsEventLeaf && state.children.length > 0 && !eventScopedLeaf && (
          <p role="alert" className="rounded-md bg-warning/25 px-3 py-2 text-sm text-ink">
            Vật phẩm gắn phạm vi sự kiện — cần ít nhất một điều kiện thuộc
            nhóm Sự kiện / Bộ bằng chứng chỉ định.
          </p>
        )}

        {validation && (
          <div className="flex flex-col gap-2 rounded-md border border-border p-3">
            <p className="text-sm font-medium text-ink">
              {validation.valid
                ? "Điều kiện hợp lệ — có thể lưu."
                : "Điều kiện chưa hợp lệ:"}
            </p>
            {validation.errors.map((e, i) => (
              <p key={i} role="alert" className="text-sm text-error">
                {e.field ? `[${e.field}] ` : ""}
                {e.message}
              </p>
            ))}
            {validation.warnings.map((w, i) => (
              <p key={i} className="text-sm text-ink-muted">
                Cảnh báo: {w}
              </p>
            ))}
            {!validation.acceptsRule && (
              <p role="alert" className="text-sm text-error">
                Scope vật phẩm ({validation.scope}) không chấp nhận điều kiện này.
              </p>
            )}
          </div>
        )}

        {actionError && (
          <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
            {toUserMessage(actionError)}
          </p>
        )}
        {saveMsg && (
          <p className="rounded-md bg-success/15 px-3 py-2 text-sm text-ink">
            {saveMsg}
          </p>
        )}

        <div className="flex items-center gap-3">
          <Button
            type="button"
            variant="secondary"
            disabled={!allComplete || validate.isPending}
            onClick={runValidate}
          >
            {validate.isPending ? "Đang kiểm tra…" : "Kiểm tra"}
          </Button>
          <Button
            type="button"
            disabled={!allComplete || save.isPending}
            onClick={runSave}
          >
            {save.isPending ? "Đang lưu…" : "Lưu điều kiện"}
          </Button>
          {item.rule && (
            <p className="text-xs text-ink-muted">
              Đang dùng: revision #{item.rule.id.slice(0, 8)}… — lưu mới sẽ
              tạo revision tiếp theo.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
