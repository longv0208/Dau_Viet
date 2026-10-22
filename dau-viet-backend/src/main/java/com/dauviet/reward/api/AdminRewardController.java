package com.dauviet.reward.api;

import java.util.Map;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.reward.application.RewardGrantService;

/**
 * Thao tác thưởng phía admin (TASK-0023). Backfill là hành động tường
 * minh — KHÔNG chạy tự động lúc startup — để grant cho các attempt đã
 * COMPLETED trước khi tính năng ra mắt; idempotent nên chạy lại an toàn.
 */
@RestController
@RequestMapping("/api/v1/admin/rewards")
public class AdminRewardController {

    private final RewardGrantService grants;

    public AdminRewardController(RewardGrantService grants) {
        this.grants = grants;
    }

    /** Bổ sung thưởng first-completion cho attempt COMPLETED cũ. */
    @PostMapping("/backfill")
    public Map<String, Object> backfill() {
        int filled = grants.backfillFirstCompletions();
        return Map.of("attemptsGranted", filled);
    }
}
