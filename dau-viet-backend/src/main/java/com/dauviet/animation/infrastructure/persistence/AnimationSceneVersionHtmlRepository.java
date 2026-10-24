package com.dauviet.animation.infrastructure.persistence;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.animation.domain.AnimationSceneVersionHtml;

public interface AnimationSceneVersionHtmlRepository
        extends JpaRepository<AnimationSceneVersionHtml, UUID> {
}
