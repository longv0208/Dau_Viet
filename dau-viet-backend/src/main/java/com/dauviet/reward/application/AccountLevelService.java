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
 * Dịch vụ tính Level tài khoản từ tổng EXP tích lũy (ISLAND-01, ISLAND-02).
 *
 * <p>Level được suy ra từ bảng account_level_thresholds đang active (cao nhất
 * config_version) — không hard-code ngưỡng trong code. EXP là giá trị tích
 * lũy và KHÔNG bị tiêu hao; Level chỉ phản ánh tổng EXP đã kiếm được.
 *
 * <p>Cấu hình hợp lệ phải thỏa mãn (ISLAND-03 stricter):
 * <ul>
 *   <li>Có ít nhất một row.</li>
 *   <li>Row đầu tiên phải có level=1 và min_exp=0.</li>
 *   <li>min_exp tăng nghiêm ngặt (không có hai level cùng ngưỡng).</li>
 *   <li>Số level liên tục 1, 2, 3, … — không khoảng trống hay trùng.</li>
 * </ul>
 *
 * <p>Khi cấu hình thiếu hoặc không hợp lệ: log cảnh báo và trả 1 (safe
 * default). Caller quan trọng (IslandService) phải kiểm tra cấu hình riêng
 * — không được dùng level 1 mặc định để suy ra quyền nâng đảo.
 *
 * <p>Edge cases được xử lý:
 * <ul>
 *   <li>User chưa có reward → EXP = 0 → Level 1 (threshold min_exp=0).</li>
 *   <li>EXP đúng bằng ngưỡng → đủ điều kiện level đó.</li>
 *   <li>EXP nằm giữa hai ngưỡng → lấy level thấp hơn.</li>
 *   <li>EXP lớn hơn ngưỡng level cao nhất → giữ level cao nhất có cấu hình.</li>
 *   <li>Không có cấu hình active → trả FALLBACK_LEVEL = 1, log warn.</li>
 * </ul>
 */
@Service
public class AccountLevelService {

    private static final org.slf4j.Logger log =
            org.slf4j.LoggerFactory.getLogger(AccountLevelService.class);

    /** Trả về khi không có cấu hình hợp lệ — an toàn nhưng không grant quyền. */
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
     * Tính level từ một giá trị EXP đã biết. Không truy vấn thêm DB.
     * Gọi {@link #findValidatedThresholds()} để lấy cấu hình đã validate.
     *
     * @param exp EXP tích lũy (≥ 0)
     * @return level (≥ 1)
     */
    public int levelForExp(long exp) {
        List<AccountLevelThreshold> active = findValidatedThresholds();
        if (active.isEmpty()) {
            // Đã log trong findValidatedThresholds
            return FALLBACK_LEVEL;
        }
        // Thresholds đã sort theo min_exp ASC từ repository.
        // Duyệt: lấy level cao nhất có min_exp ≤ exp.
        AccountLevelThreshold result = active.get(0);
        for (AccountLevelThreshold t : active) {
            if (exp >= t.getMinExp()) {
                result = t;
            } else {
                break; // đã sort ASC
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
        return findValidatedThresholds().stream()
                .filter(t -> t.getLevel() == targetLevel)
                .mapToLong(AccountLevelThreshold::getMinExp)
                .findFirst()
                .orElse(-1L);
    }

    /**
     * Kiểm tra cấu hình hợp lệ: có thể tính level hay không.
     * Trả {@code true} nếu cấu hình active đủ điều kiện dùng.
     */
    public boolean hasValidConfiguration() {
        return !findValidatedThresholds().isEmpty();
    }

    /**
     * Lấy danh sách ngưỡng active đã được validate. Empty = cấu hình không
     * hợp lệ; caller không được dùng FALLBACK để suy ra quyền nghiệp vụ.
     *
     * <p>Các điều kiện hợp lệ (ISLAND-03 stricter checks):
     * <ul>
     *   <li>Có ít nhất một row.</li>
     *   <li>Row đầu tiên (sort theo min_exp ASC) phải có level=1 và min_exp=0.</li>
     *   <li>min_exp tăng nghiêm ngặt (không có hai level cùng ngưỡng).</li>
     *   <li>Các số level liên tục (1, 2, 3, …) — không có khoảng trống hay trùng.</li>
     * </ul>
     */
    public List<AccountLevelThreshold> findValidatedThresholds() {
        List<AccountLevelThreshold> active = thresholds.findActiveLevels();
        if (active.isEmpty()) {
            log.warn("account_level_thresholds: no active configuration found");
            return List.of();
        }
        // Bước 1: min_exp đầu tiên phải là 0 (Level 1 luôn bắt đầu từ 0 EXP)
        if (active.get(0).getMinExp() != 0) {
            log.warn("account_level_thresholds: active config invalid — "
                    + "first threshold must have min_exp=0, found {}",
                    active.get(0).getMinExp());
            return List.of();
        }
        // Bước 2: Level đầu tiên phải là 1 (không bắt đầu từ 0 hoặc 2)
        if (active.get(0).getLevel() != 1) {
            log.warn("account_level_thresholds: active config invalid — "
                    + "first level must be 1, found {}",
                    active.get(0).getLevel());
            return List.of();
        }
        // Bước 3: min_exp tăng nghiêm ngặt + level liên tục (1, 2, 3, …)
        for (int i = 1; i < active.size(); i++) {
            AccountLevelThreshold prev = active.get(i - 1);
            AccountLevelThreshold curr = active.get(i);
            if (curr.getMinExp() <= prev.getMinExp()) {
                log.warn("account_level_thresholds: active config invalid — "
                        + "min_exp not strictly increasing at index {} "
                        + "(prev={}, curr={})", i, prev.getMinExp(), curr.getMinExp());
                return List.of();
            }
            if (curr.getLevel() != prev.getLevel() + 1) {
                log.warn("account_level_thresholds: active config invalid — "
                        + "level numbers not contiguous at index {} "
                        + "(prev level={}, curr level={})",
                        i, prev.getLevel(), curr.getLevel());
                return List.of();
            }
        }
        return active;
    }
}
