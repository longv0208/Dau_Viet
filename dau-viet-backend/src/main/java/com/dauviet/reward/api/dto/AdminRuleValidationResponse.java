package com.dauviet.reward.api.dto;

import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Ket qua dry-run validate rule (GAME-06 Module C) — khong ghi DB.
 * errors mang code on dinh de UI map tieng Viet; normalizedCondition la
 * AST canonical sau parse (admin xem truoc dung thu se luu).
 */
public record AdminRuleValidationResponse(
        boolean valid,
        List<Issue> errors,
        List<String> warnings,
        JsonNode normalizedCondition,
        /** UNRESOLVED | EVENT_SCOPED | GLOBAL — scope da duyet cua item. */
        String scope,
        /** false = item (event-scoped/unresolved) khong chap nhan rule nay. */
        boolean acceptsRule
) {
    public record Issue(String code, String message, String field) {
    }
}
