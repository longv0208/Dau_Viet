package com.dauviet.reward.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.reward.domain.UserInventoryItem;

/**
 * user_inventory — append-only, non-stackable. Ghi duy nhất qua
 * {@link #insertIgnore} (ON CONFLICT (user_id, item_id) DO NOTHING):
 * vật phẩm đã cấp không bao giờ cấp lại hay bị thu hồi.
 */
public interface UserInventoryRepository
        extends JpaRepository<UserInventoryItem, UUID> {

    /**
     * Cấp vật phẩm cho learner; đã sở hữu → bỏ qua.
     * @return số row insert thực tế (0 = đã có từ trước)
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_inventory
                (id, user_id, item_id, acquired_at, acquisition_source,
                 source_lesson_id, source_attempt_id)
            VALUES (gen_random_uuid(), :userId, :itemId, now(),
                    :acquisitionSource, :sourceLessonId, :sourceAttemptId)
            ON CONFLICT (user_id, item_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("itemId") UUID itemId,
                     @Param("acquisitionSource") String acquisitionSource,
                     @Param("sourceLessonId") UUID sourceLessonId,
                     @Param("sourceAttemptId") UUID sourceAttemptId);

    /**
     * GAME-05 V24: ghi kèm provenance đầy đủ (rule đã cấp + version, event
     * nguồn, cause_key idempotent). Hai ON CONFLICT phối hợp: (user_id,
     * item_id) chặn cấp lại; ux_user_inventory_cause_key chặn cùng nguyên
     * nhân ghi hai lần kể cả khi caller thay đổi item.
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_inventory
                (id, user_id, item_id, acquired_at, acquisition_source,
                 source_lesson_id, source_attempt_id, unlock_rule_id,
                 unlock_rule_version, source_event_id, cause_key)
            VALUES (gen_random_uuid(), :userId, :itemId, now(),
                    :acquisitionSource, :sourceLessonId, :sourceAttemptId,
                    :unlockRuleId, :unlockRuleVersion, :sourceEventId,
                    :causeKey)
            ON CONFLICT (user_id, item_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnoreV2(@Param("userId") UUID userId,
                       @Param("itemId") UUID itemId,
                       @Param("acquisitionSource") String acquisitionSource,
                       @Param("sourceLessonId") UUID sourceLessonId,
                       @Param("sourceAttemptId") UUID sourceAttemptId,
                       @Param("unlockRuleId") UUID unlockRuleId,
                       @Param("unlockRuleVersion") Integer unlockRuleVersion,
                       @Param("sourceEventId") UUID sourceEventId,
                       @Param("causeKey") String causeKey);

    /** Inventory của learner — mới nhất trước. */
    List<UserInventoryItem> findByUserIdOrderByAcquiredAtDesc(UUID userId);

    /**
     * Vật phẩm một attempt đã kích hoạt — enrich result screen. Loại
     * ADMIN_GRANT: reconciliation ghi source_attempt_id của attempt đã
     * hoàn thành TRƯỚC đó (metadata truy vết), nhưng đó không phải
     * "vừa mở khóa trong lượt học" — không được hiển thị tại đây.
     */
    @Query("SELECT i FROM UserInventoryItem i WHERE i.sourceAttemptId = :attemptId "
         + "AND i.acquisitionSource <> 'ADMIN_GRANT'")
    List<UserInventoryItem> findRealtimeUnlocksByAttempt(
            @Param("attemptId") UUID attemptId);

    /** Kiểm tra sở hữu — unlock evaluator bỏ qua item đã cấp. */
    boolean existsByUserIdAndItemId(UUID userId, UUID itemId);
}
