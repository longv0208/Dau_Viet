package com.dauviet.streak.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.streak.domain.UserLearningStreak;

import jakarta.persistence.LockModeType;

/**
 * Truy cập user_learning_streaks (V31). Mọi đường ghi serialize trên
 * {@link #findForUpdate} — hai request complete cùng lúc của cùng một user
 * không thể lost-update hay tạo 2 chuỗi khác nhau.
 */
public interface UserLearningStreakRepository
        extends JpaRepository<UserLearningStreak, UUID> {

    /** Lazy-create row streak 0 cho user mới; đã tồn tại → bỏ qua. */
    @Modifying
    @Query(value = """
            INSERT INTO user_learning_streaks
                (user_id, current_streak, longest_streak,
                 last_qualified_date, created_at, updated_at, row_version)
            VALUES (:userId, 0, 0, NULL, :now, :now, 0)
            ON CONFLICT (user_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("now") java.time.Instant now);

    /** Pessimistic lock — bắt buộc cho mọi đọc-sửa-ghi streak. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM UserLearningStreak s WHERE s.userId = :userId")
    Optional<UserLearningStreak> findForUpdate(@Param("userId") UUID userId);
}
