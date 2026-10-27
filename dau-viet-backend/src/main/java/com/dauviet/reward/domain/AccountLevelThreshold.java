package com.dauviet.reward.domain;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ngưỡng EXP tích lũy tương ứng với Level tài khoản (V38). Cơ chế
 * copy-on-write giống island_tier_policies: thay đổi ngưỡng = config_version+1
 * (row mới), KHÔNG update ngược. active=true đánh dấu version đang hiệu lực.
 *
 * <p>Level được TÍNH từ tổng EXP; EXP KHÔNG bị tiêu hao khi level lên.
 * Không hard-code ngưỡng trong logic — đọc từ bảng này.
 */
@Entity
@Table(name = "account_level_thresholds")
public class AccountLevelThreshold {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "config_version", nullable = false, updatable = false)
    private int configVersion;

    /** Level tài khoản (1-based). */
    @Column(name = "level", nullable = false, updatable = false)
    private int level;

    /** EXP tích lũy tối thiểu để đạt level này. */
    @Column(name = "min_exp", nullable = false, updatable = false)
    private long minExp;

    @Column(name = "active", nullable = false, updatable = false)
    private boolean active;

    public AccountLevelThreshold() {
    }

    public UUID getId()           { return id; }
    public int getConfigVersion() { return configVersion; }
    public int getLevel()         { return level; }
    public long getMinExp()       { return minExp; }
    public boolean isActive()     { return active; }
}
