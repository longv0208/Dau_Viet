package com.dauviet.energy.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.energy.domain.UserEnergy;

import jakarta.persistence.LockModeType;

/**
 * Truy cập user_energy (V21). Lazy-create đi qua {@link #insertIgnore} —
 * PK (user_id) + ON CONFLICT DO NOTHING chặn duplicate khi hai request đầu
 * tiên chạy đồng thời. Mọi đường ghi serialize trên {@link #findForUpdate}
 * (FOR UPDATE) nên không lost update giữa hai thiết bị cùng user.
 */
public interface UserEnergyRepository extends JpaRepository<UserEnergy, UUID> {

    /**
     * Tạo dòng energy 100% cho user mới; đã tồn tại → bỏ qua.
     * @return 1 nếu vừa insert, 0 nếu đã có (đối thủ thắng race).
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_energy (user_id, current_energy, last_recovery_at,
                                     row_version)
            VALUES (:userId, :maxEnergy, :now, 0)
            ON CONFLICT (user_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("maxEnergy") int maxEnergy,
                     @Param("now") java.time.Instant now);

    /** Pessimistic lock — bắt buộc cho mọi thao tác đọc-sửa-ghi energy. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT e FROM UserEnergy e WHERE e.userId = :userId")
    Optional<UserEnergy> findForUpdate(@Param("userId") UUID userId);
}
