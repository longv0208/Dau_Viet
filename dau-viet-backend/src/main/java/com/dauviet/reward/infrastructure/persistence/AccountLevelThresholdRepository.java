package com.dauviet.reward.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.dauviet.reward.domain.AccountLevelThreshold;

/**
 * Truy cập account_level_thresholds (V38). Chỉ đọc; ghi qua migration/CMS.
 *
 * <p>Cơ chế active version: config_version cao nhất trong số các version có
 * ít nhất một row active là version đang hiệu lực. Điều này đảm bảo chỉ một
 * bộ ngưỡng duy nhất được sử dụng — không trộn row từ nhiều config_version.
 * Khi migrate lên cấu hình mới, deactivate toàn bộ rows version cũ và insert
 * rows version mới với active=true.
 */
public interface AccountLevelThresholdRepository
        extends JpaRepository<AccountLevelThreshold, UUID> {

    /**
     * Tất cả ngưỡng của config_version đang active cao nhất, sort theo
     * min_exp ASC. Subquery chọn MAX(config_version) trong các version có ít
     * nhất một row active — không trộn rows của nhiều version khác nhau.
     */
    @Query("""
            SELECT t FROM AccountLevelThreshold t
            WHERE t.active = true
              AND t.configVersion = (
                  SELECT MAX(t2.configVersion)
                  FROM AccountLevelThreshold t2
                  WHERE t2.active = true
              )
            ORDER BY t.minExp ASC
            """)
    List<AccountLevelThreshold> findActiveLevels();
}
