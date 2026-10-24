package com.dauviet.animation.infrastructure.persistence;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.animation.domain.AnimationSceneHtml;

public interface AnimationSceneHtmlRepository
        extends JpaRepository<AnimationSceneHtml, UUID> {
}
