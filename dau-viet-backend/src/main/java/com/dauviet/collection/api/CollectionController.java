package com.dauviet.collection.api;

import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.collection.api.dto.CollectionItemResponse;
import com.dauviet.collection.application.CollectionService;
import com.dauviet.common.api.PageResponse;
import com.dauviet.common.security.JwtSubjectExtractor;

/**
 * Bộ sưu tập Dấu Việt của learner hiện tại (TASK-0022) — read-only, chỉ
 * ghi từ submission runtime. Learner identity lấy từ JWT, không nhận
 * userId từ client.
 */
@RestController
@RequestMapping("/api/v1/me/collection")
public class CollectionController {

    private static final int MAX_PAGE_SIZE = 50;

    private final CollectionService service;
    private final JwtSubjectExtractor subjects;

    public CollectionController(CollectionService service,
                                JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /** Danh sách đã collect — mới nhất trước; filter `type`, `eventId`. */
    @GetMapping
    public PageResponse<CollectionItemResponse> list(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) UUID eventId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal Jwt jwt) {
        Pageable pageable = PageRequest.of(Math.max(0, page),
                Math.min(Math.max(1, size), MAX_PAGE_SIZE));
        return service.list(subjects.userId(jwt), type, eventId, pageable);
    }

    /** Chi tiết một mục đã collect (owner only — 404 nếu không phải của mình). */
    @GetMapping("/{evidenceId}")
    public CollectionItemResponse detail(@PathVariable UUID evidenceId,
                                         @AuthenticationPrincipal Jwt jwt) {
        return service.detail(subjects.userId(jwt), evidenceId);
    }
}
