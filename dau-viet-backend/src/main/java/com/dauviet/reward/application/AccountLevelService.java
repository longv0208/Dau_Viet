package com.dauviet.reward.application;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.reward.domain.AccountLevelThreshold;
import com.dauviet.reward.domain.RewardTransaction;
import com.dauviet.reward.infrastructure.persistence.AccountLevelThresholdRepository;
import com.dauviet.reward.infrastructure.persistence.RewardTransactionRepository;

/**
 * Dịch vụ tính Level tài khoản từ tổng EXP tích lũy (ISLAND-01).
 *
 * <p>Level được suy ra từ bảng account_level_thresholds đang active —
 * không hard-code ngưỡng trong code. EXP là giá trị tích lũy và KHÔNG
 * bị tiêu hao; Level chỉ phản ánh tổng EXP đã kiếm được.
 *
 * <p>Edge cases được xử lý:
 * <ul>
 *   <li>User chưa có reward → EXP = 0 → Level 1 (threshold min_exp=0).</li>
 *   <li>EXP đúng bằng ngưỡng → đủ điều kiện level đó.</li>
 *   <li>EXP nằm giữa hai ngưỡng → lấy level thấp hơn.</li>
 *   <li>EXP lớn hơn ngưỡng level cao nhất → giữ level cao nhất có cấu hình.</li>
 *   <li>Không có cấu hình active → trả level 1 an toàn, log cảnh báo.</li>
 *   <li>Cấu hình không liên tục hoặc trùng ngưỡng → sort theo min_exp ASC,
 *       lấy row có min_exp lớn nhất ≤ EXP (hành vi ổn định).</li>
 * </ul>
 */
@Service
public class AccountLevelService {

    private static final org.slf4j.Logger log =
            org.slf4j.LoggerFactory.getLogger(AccountLevelService.class);

    /** Level tối thiểu trả về khi không có cấu hình hợp lệ. */
    private static final int FALLBACK_LEVEL = 1;

    private final RewardTransactionRepository rewards;
    private final AccountLevelThresholdRepository thresholds;

    public AccountLevelService(RewardTransactionRepository rewards,
                               AccountLevelThresholdRepository thresholds) {
        this.rewards = rewards;
        this.thresholds = thresholds;
    }

    /**
     * Tổng EXP tích lũy của user (không tiêu hao).
     *
     * @param userId id user
     * @return tổng EXP, 0 nếu chưa có reward
     */
    @Transactional(readOnly = true)
    public long totalExp(UUID userId) {
        return rewards.sumAmount(userId, RewardTransaction.TYPE_EXP);
    }

    /**
     * Level tài khoản hiện tại tính từ tổng EXP.
     *
     * @param userId id user
     * @return level (≥ 1)
     */
    @Transactional(readOnly = true)
    public int currentLevel(UUID userId) {
        long exp = totalExp(userId);
        return levelForExp(exp);
    }

    /**
     * Tính level từ một giá trị EXP đã biết (tái dùng khi đã có EXP sẵn).
     * Không truy vấn thêm DB.
     *
     * @param exp EXP tích lũy (≥ 0)
     * @return level (≥ 1)
     */
    public int levelForExp(long exp) {
        List<AccountLevelThreshold> active = thresholds.findActiveLevels();
        if (active.isEmpty()) {
            log.warn("account_level_thresholds: no active configuration found; "
                    + "defaulting to level {}", FALLBACK_LEVEL);
            return FALLBACK_LEVEL;
        }
        // Thresholds đã sort theo min_exp ASC từ repository.
        // Duyệt từ cuối về đầu: lấy level cao nhất có min_exp ≤ exp.
        AccountLevelThreshold result = active.get(0); // ít nhất level 1
        for (AccountLevelThreshold t : active) {
            if (exp >= t.getMinExp()) {
                result = t;
            } else {
                break; // đã sort ASC, không cần đọc thêm
            }
        }
        return result.getLevel();
    }

    /**
     * EXP tối thiểu để đạt {@code targetLevel} theo cấu hình active.
     * Trả -1 nếu level không tồn tại trong cấu hình.
     *
     * @param targetLevel level cần tìm ngưỡng
     * @return min_exp của level đó, hoặc -1 nếu không có trong cấu hình
     */
    public long minExpForLevel(int targetLevel) {
        return thresholds.findActiveLevels().stream()
                .filter(t -> t.getLevel() == targetLevel)
                .mapToLong(AccountLevelThreshold::getMinExp)
                .findFirst()
                .orElse(-1L);
    }
}
