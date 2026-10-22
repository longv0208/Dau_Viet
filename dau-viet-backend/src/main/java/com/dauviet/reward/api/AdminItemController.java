package com.dauviet.reward.api;

import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.api.PageResponse;
import com.dauviet.reward.api.dto.AdminItemRequest;
import com.dauviet.reward.api.dto.AdminItemResponse;
import com.dauviet.reward.api.dto.AdminRuleRequest;
import com.dauviet.reward.application.AdminItemService;

import jakarta.validation.Valid;

/**
 * Cấu hình tối thiểu item catalog + unlock rules (TASK-0023) — guard
 * ROLE_CONTENT_ADMIN qua /api/v1/admin/** trong SecurityConfig.
 */
@RestController
@RequestMapping("/api/v1/admin/items")
public class AdminItemController {

    private static final int MAX_PAGE_SIZE = 100;

    private final AdminItemService service;

    public AdminItemController(AdminItemService service) {
        this.service = service;
    }

    @GetMapping
    public PageResponse<AdminItemResponse> list(
            @RequestParam(required = false) Boolean active,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        Pageable pageable = PageRequest.of(Math.max(0, page),
                Math.min(Math.max(1, size), MAX_PAGE_SIZE));
        return service.list(active, pageable);
    }

    @GetMapping("/{itemId}")
    public AdminItemResponse get(@PathVariable UUID itemId) {
        return service.get(itemId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AdminItemResponse create(@Valid @RequestBody AdminItemRequest req) {
        return service.create(req);
    }

    @PutMapping("/{itemId}")
    public AdminItemResponse update(@PathVariable UUID itemId,
                                    @Valid @RequestBody AdminItemRequest req) {
        return service.update(itemId, req);
    }

    /** Gán/thay unlock rule của item — tắt rule cũ, không sửa lịch sử. */
    @PutMapping("/{itemId}/rule")
    public AdminItemResponse setRule(@PathVariable UUID itemId,
                                     @Valid @RequestBody AdminRuleRequest req) {
        return service.setRule(itemId, req);
    }
}
