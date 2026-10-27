package com.dauviet.reward.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.dauviet.reward.domain.AccountLevelThreshold;

/**
 * Truy cập account_level_thresholds (V38). Chỉ đọc; ghi qua migration/CMS sau.
 * findActiveLevels trả toàn bộ config active, sort theo min_exp ASC — caller
 * dùng để tính level tuyến tính từ EXP.
 */
public interface AccountLevelThresholdRepository
        extends JpaRepository<AccountLevelThreshold, UUID> {

    /**
     * Tất cả bản ghi của config_version đang active, sort theo min_exp ASC.
     * Đảm bảo repository tải một bộ cấu hình duy nhất (partial unique index
     * ux_acct_level_active ngăn nhiều config_version active đồng thời).
     */
    @Query("SELECT t FROM AccountLevelThreshold t WHERE t.active = true "
         + "ORDER BY t.minExp ASC")
    List<AccountLevelThreshold> findActiveLevels();
}
