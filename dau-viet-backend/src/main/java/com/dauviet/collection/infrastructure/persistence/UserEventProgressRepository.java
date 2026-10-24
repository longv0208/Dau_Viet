package com.dauviet.collection.infrastructure.persistence;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.UserEventProgress;

/**
 * Persistence cho user_event_progress (GAME-04). Ghi duy nhất qua
 * {@link #insertIgnore} — ON CONFLICT (user_id, event_id, milestone)
 * DO NOTHING giữ ledger một-lần dưới retry/concurrent/backfill.
 */
public interface UserEventProgressRepository
        extends JpaRepository<UserEventProgress, UserEventProgress.PK> {

    /**
     * Ghi một milestone; row đã tồn tại → bỏ qua (granted_at/policy_version
     * giữ lần ghi đầu — entitlement không viết lại, EVT-05).
     *
     * @return số row insert thực tế (0 = đã ghi trước đó)
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_event_progress
                (user_id, event_id, milestone, policy_version,
                 required_snapshot, granted_at)
            VALUES (:userId, :eventId, :milestone, :policyVersion,
                    CAST(:requiredSnapshot AS jsonb), now())
            ON CONFLICT (user_id, event_id, milestone) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("eventId") UUID eventId,
                     @Param("milestone") String milestone,
                     @Param("policyVersion") int policyVersion,
                     @Param("requiredSnapshot") String requiredSnapshot);

    /** Milestone đã ghi chưa — check trước khi đánh giá/reconcile. */
    @Query("select count(p) > 0 from UserEventProgress p "
         + "where p.userId = :userId and p.eventId = :eventId "
         + "and p.milestone = :milestone")
    boolean exists(@Param("userId") UUID userId,
                   @Param("eventId") UUID eventId,
                   @Param("milestone") String milestone);

    /**
     * Policy version đã cấp milestone EVENT_COMPLETED của (user,event) —
     * FIX 7: UI cần phân biệt "đã hoàn thành policy cũ" vs "tiến độ theo
     * policy hiện tại" khi admin publish v2.
     */
    @Query("select p.policyVersion from UserEventProgress p "
         + "where p.userId = :userId and p.eventId = :eventId "
         + "and p.milestone = 'EVENT_COMPLETED'")
    Integer earnedPolicyVersion(@Param("userId") UUID userId,
                                @Param("eventId") UUID eventId);

    /**
     * Số dossier đã mở LIÊN QUAN tới event này (đếm cho progress DTO).
     *
     * FIX 2: join event_dossiers (dossier thuộc event) + user_dossier_unlocks
     * (learner đã mở dossier đó, qua bất kỳ event nào). Không đếm theo
     * u.event_id — provenance chỉ ghi event mở LẦN ĐẦU; dossier dùng chung
     * nhiều event phải được đếm ở cả các event nó thuộc về.
     */
    @Query(value = """
            SELECT COUNT(DISTINCT ed.dossier_id)
              FROM event_dossiers ed
              JOIN user_dossier_unlocks u
                ON u.dossier_id = ed.dossier_id AND u.user_id = :userId
             WHERE ed.event_id = :eventId
            """, nativeQuery = true)
    long countUnlockedDossiersForEvent(@Param("userId") UUID userId,
                                       @Param("eventId") UUID eventId);

    /**
     * GAME-05 TOTAL_EVENTS_*: số event KHÁC NHAU learner đã ghi một
     * milestone (ví dụ EVENT_COMPLETED) trên ledger — một event nhiều lần
     * ghi cùng milestone vẫn tính một.
     */
    @Query("select count(distinct p.eventId) from UserEventProgress p "
         + "where p.userId = :userId and p.milestone = :milestone")
    long countDistinctEventsByMilestone(@Param("userId") UUID userId,
                                        @Param("milestone") String milestone);
}
