package com.dauviet.animation.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import com.dauviet.animation.domain.AnimationTemplate;

@Repository
public interface AnimationTemplateRepository
        extends JpaRepository<AnimationTemplate, UUID>,
        JpaSpecificationExecutor<AnimationTemplate> {

    Optional<AnimationTemplate> findByCode(String code);

    boolean existsByCode(String code);
}
