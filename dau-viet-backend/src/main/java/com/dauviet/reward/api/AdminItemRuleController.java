package com.dauviet.reward.api;

import java.util.List;
import java.util.UUID;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.reward.api.dto.AdminRuleHistoryEntry;
import com.dauviet.reward.api.dto.AdminRuleRequest;
import com.dauviet.reward.api.dto.AdminRuleValidationResponse;
import com.dauviet.reward.application.AdminItemService;

import jakarta.validation.Valid;

/**
 * Rule dry-run validate + revision history (GAME-06 Module C).
 * PUT /rule van nam o AdminItemController (backward compat); controller
 * nay tach phan doc/validate de giu file nho.
 */
@RestController
@RequestMapping("/api/v1/admin/items/{itemId}/rule")
@Validated
public class AdminItemRuleController {

    private final AdminItemService service;

    public AdminItemRuleController(AdminItemService service) {
        this.service = service;
    }

    /**
     * Dry-run: parse + validate + scope-check giong het buildRule nhung
     * khong ghi DB — UI goi truoc khi admin bam Save.
     */
    @PostMapping("/validate")
    public AdminRuleValidationResponse validate(@PathVariable UUID itemId,
            @Valid @RequestBody AdminRuleRequest req) {
        return service.validateRule(itemId, req);
    }

    /**
     * Moi revision da publish (active + inactive), kem grantCount
     * provenance — audit trail cho rule builder.
     */
    @GetMapping("/history")
    public List<AdminRuleHistoryEntry> history(@PathVariable UUID itemId) {
        return service.ruleHistory(itemId);
    }
}
