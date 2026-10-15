package com.dauviet.lesson.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.dauviet.lesson.domain.LessonTemplate;

@Repository
public interface LessonTemplateRepository extends JpaRepository<LessonTemplate, UUID> {

    Optional<LessonTemplate> findByCode(String code);

    java.util.List<LessonTemplate> findAllByEnabledTrue();
}
