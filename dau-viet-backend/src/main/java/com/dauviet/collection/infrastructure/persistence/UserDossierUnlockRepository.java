package com.dauviet.collection.infrastructure.persistence;

import java.util.Set;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.UserDossierUnlock;

/**
 * Persistence cho user_dossier_unlocks (GAME-04). Ghi duy nhất qua
 * {@link #insertIgnore} — ON CONFLICT (user_id, dossier_id) DO NOTHING giữ
 * entitlement unique theo canonical dossier dưới retry/concurrent fan-out.
 */
public interface UserDossierUnlockRepository
        extends JpaRepository<UserDossierUnlock, UserDossierUnlock.PK> {

    /**
     * Ghi một quyền mở hồ sơ; row đã tồn tại cho (user, dossier) → bỏ qua
     * (granted_at + provenance giữ lần mở đầu tiên — ITEM-03).
     *
     * @return số row insert thực tế (0 = đã mở trước đó)
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_dossier_unlocks
                (user_id, dossier_id, event_id, dossier_version, granted_at)
            VALUES (:userId, :dossierId, :eventId, :dossierVersion, now())
            ON CONFLICT (user_id, dossier_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("dossierId") UUID dossierId,
                     @Param("eventId") UUID eventId,
                     @Param("dossierVersion") int dossierVersion);

    /** Dossier ids learner đã mở — join-side cho list/detail check. */
    @Query("select u.dossierId from UserDossierUnlock u "
         + "where u.userId = :userId")
    Set<UUID> unlockedDossierIds(@Param("userId") UUID userId);

    /** Unlock row cụ thể — provenance khi đọc chi tiết. */
    @Query("select u from UserDossierUnlock u "
         + "where u.userId = :userId and u.dossierId = :dossierId")
    java.util.Optional<UserDossierUnlock> findByUserIdAndDossierId(
            @Param("userId") UUID userId, @Param("dossierId") UUID dossierId);
}
