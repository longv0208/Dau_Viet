package com.dauviet.reward.api;

import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.api.PageResponse;
import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.reward.api.dto.CatalogItemResponse;
import com.dauviet.reward.api.dto.InventoryItemResponse;
import com.dauviet.reward.api.dto.RewardSummaryResponse;
import com.dauviet.reward.api.dto.RewardTransactionResponse;
import com.dauviet.reward.application.RewardService;

/**
 * Bề mặt đọc thưởng + vật phẩm của learner hiện tại (TASK-0023) —
 * read-only, ghi chỉ từ runtime complete()/collect. Identity luôn lấy
 * từ JWT, không nhận userId từ client.
 */
@RestController
@RequestMapping("/api/v1/me")
public class RewardController {

    private static final int MAX_PAGE_SIZE = 50;

    private final RewardService service;
    private final JwtSubjectExtractor subjects;

    public RewardController(RewardService service,
                            JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /** Tổng EXP + Điểm Lịch sử + số bài hoàn thành + số vật phẩm. */
    @GetMapping("/rewards/summary")
    public RewardSummaryResponse summary(@AuthenticationPrincipal Jwt jwt) {
        return service.summary(subjects.userId(jwt));
    }

    /** Lịch sử bút toán thưởng — phân trang, mới nhất trước. */
    @GetMapping("/rewards/transactions")
    public PageResponse<RewardTransactionResponse> transactions(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal Jwt jwt) {
        Pageable pageable = PageRequest.of(Math.max(0, page),
                Math.min(Math.max(1, size), MAX_PAGE_SIZE));
        return service.transactions(subjects.userId(jwt), pageable);
    }

    /** Vật phẩm đã sở hữu — mới nhất trước. */
    @GetMapping("/inventory")
    public List<InventoryItemResponse> inventory(
            @AuthenticationPrincipal Jwt jwt) {
        return service.inventoryList(subjects.userId(jwt));
    }

    /** Catalog đầy đủ kèm owned + requirement + progress. */
    @GetMapping("/inventory/catalog")
    public List<CatalogItemResponse> catalog(
            @AuthenticationPrincipal Jwt jwt) {
        return service.catalog(subjects.userId(jwt));
    }
}
