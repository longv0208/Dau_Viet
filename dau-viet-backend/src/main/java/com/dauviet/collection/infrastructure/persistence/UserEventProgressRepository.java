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

    /** Số dossier đã mở của learner gắn event này (đếm cho progress DTO). */
    @Query("select count(u) from UserDossierUnlock u "
         + "where u.userId = :userId and u.eventId = :eventId")
    long countUnlockedDossiersForEvent(@Param("userId") UUID userId,
                                       @Param("eventId") UUID eventId);
}
