package com.dauviet.lesson.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.lesson.domain.LessonTemplate;

@Repository
public interface LessonTemplateRepository extends JpaRepository<LessonTemplate, UUID> {

    Optional<LessonTemplate> findByCode(String code);

    List<LessonTemplate> findAllByEnabledTrue();

    @Query("""
            SELECT t FROM LessonTemplate t
            WHERE (:enabled IS NULL OR t.enabled = :enabled)
              AND (:qPattern IS NULL
                   OR LOWER(t.name) LIKE :qPattern
                   OR LOWER(t.code) LIKE :qPattern
                   OR LOWER(COALESCE(t.description, '')) LIKE :qPattern)
            ORDER BY t.code ASC
            """)
    Page<LessonTemplate> search(
            @Param("enabled") Boolean enabled,
            @Param("qPattern") String qPattern,
            Pageable pageable);
}
