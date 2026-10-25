package com.dauviet.collection.domain;

import java.util.List;

/**
 * Ném khi publish policy fail validation (GAME-06). Mang danh sach loi
 * co cau truc de admin UI hien thi tung field — khac ItemRuleException
 * (chi 1 message) vi policy co nhieu rule doc lap.
 */
public class PolicyValidationException extends RuntimeException {

    private final List<String> errors;

    public PolicyValidationException(List<String> errors) {
        super("Policy validation failed: " + String.join("; ", errors));
        this.errors = List.copyOf(errors);
    }

    public List<String> getErrors() {
        return errors;
    }
}
