package com.dauviet.island.infrastructure.persistence;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.island.domain.IslandLayoutDefinition;

/**
 * Layout definition catalog (V43) — read-only reference data sau publish.
 */
public interface IslandLayoutDefinitionRepository
        extends JpaRepository<IslandLayoutDefinition, UUID> {

    /** Tìm definition theo layout_key (e.g. 'heritage-village'). */
    java.util.Optional<IslandLayoutDefinition> findByLayoutKey(String layoutKey);
}
