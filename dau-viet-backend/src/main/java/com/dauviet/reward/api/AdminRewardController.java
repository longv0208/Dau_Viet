package com.dauviet.reward.api;

import java.util.Map;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.reward.application.ItemUnlockService;
import com.dauviet.reward.application.RewardGrantService;

/**
 * Thao tác thưởng phía admin (TASK-0023). Backfill + reconcile là hành
 * động tường minh — KHÔNG chạy tự động lúc startup — để bù dữ liệu cho
 * learner đã có tiến độ trước khi tính năng/rule ra mắt; idempotent nên
 * chạy lại an toàn.
 */
@RestController
@RequestMapping("/api/v1/admin/rewards")
public class AdminRewardController {

    private final RewardGrantService grants;
    private final ItemUnlockService unlocks;

    public AdminRewardController(RewardGrantService grants,
                                 ItemUnlockService unlocks) {
        this.grants = grants;
        this.unlocks = unlocks;
    }

    /** Bổ sung thưởng first-completion cho attempt COMPLETED cũ. */
    @PostMapping("/backfill")
    public Map<String, Object> backfill() {
        int filled = grants.backfillFirstCompletions();
        return Map.of("attemptsGranted", filled);
    }

    /**
     * Bù inventory cho learner đã đạt rule ACTIVE theo tiến độ lịch sử
     * (rule được tạo/sửa SAU khi họ hoàn thành). Chỉ cấp thiếu — không
     * revoke, không cấp EXP/History Points, không đụng trạng thái attempt.
     */
    @PostMapping("/reconcile-unlocks")
    public Map<String, Object> reconcileUnlocks() {
        int granted = unlocks.reconcileUnlocks();
        return Map.of("itemsGranted", granted);
    }
}
