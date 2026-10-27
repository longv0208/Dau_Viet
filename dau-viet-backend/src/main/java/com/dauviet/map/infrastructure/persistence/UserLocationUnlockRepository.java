package com.dauviet.map.infrastructure.persistence;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.map.domain.UserLocationUnlock;

@Repository
public interface UserLocationUnlockRepository extends JpaRepository<UserLocationUnlock, UserLocationUnlock.Id> {

    List<UserLocationUnlock> findByIdUserIdAndIdLocationIdIn(UUID userId, Collection<UUID> locationIds);

    List<UserLocationUnlock> findByIdUserId(UUID userId);

    @Modifying
    @Query(value = "INSERT INTO user_location_unlocks (user_id, location_id, source_lesson_id, source_attempt_id, unlocked_at) "
            + "VALUES (:userId, :locationId, :sourceLessonId, :sourceAttemptId, now()) "
            + "ON CONFLICT (user_id, location_id) DO NOTHING", nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("locationId") UUID locationId,
                     @Param("sourceLessonId") UUID sourceLessonId,
                     @Param("sourceAttemptId") UUID sourceAttemptId);
}
