package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.IslandLayoutDefinition;

import jakarta.persistence.LockModeType;

/**
 * Layout definition catalog (V44).
 */
public interface IslandLayoutDefinitionRepository
        extends JpaRepository<IslandLayoutDefinition, UUID> {

    Optional<IslandLayoutDefinition> findByLayoutKey(String layoutKey);

    Optional<IslandLayoutDefinition> findFirstByDefaultLayoutTrue();

    List<IslandLayoutDefinition> findAllByOrderByCreatedAtDesc();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT d FROM IslandLayoutDefinition d WHERE d.id = :id")
    Optional<IslandLayoutDefinition> findLockedById(@Param("id") UUID id);

    @Modifying
    @Query("UPDATE IslandLayoutDefinition d SET d.defaultLayout = false WHERE d.defaultLayout = true AND d.id <> :keepId")
    void clearOtherDefaults(@Param("keepId") UUID keepId);
}
