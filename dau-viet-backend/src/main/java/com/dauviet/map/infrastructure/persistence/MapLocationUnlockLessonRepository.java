package com.dauviet.map.infrastructure.persistence;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.map.domain.MapLocationUnlockLesson;

@Repository
public interface MapLocationUnlockLessonRepository extends JpaRepository<MapLocationUnlockLesson, MapLocationUnlockLesson.Id> {

    List<MapLocationUnlockLesson> findByIdLocationIdIn(Collection<UUID> locationIds);

    List<MapLocationUnlockLesson> findByIdLocationId(UUID locationId);

    List<MapLocationUnlockLesson> findByIdLessonId(UUID lessonId);

    @Modifying
    @Query("delete from MapLocationUnlockLesson u where u.id.locationId = :locationId")
    void deleteByLocationId(@Param("locationId") UUID locationId);
}
