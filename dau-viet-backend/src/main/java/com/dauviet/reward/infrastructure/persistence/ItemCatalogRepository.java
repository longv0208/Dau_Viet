package com.dauviet.reward.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.reward.domain.ItemCatalog;

import jakarta.persistence.LockModeType;

public interface ItemCatalogRepository
        extends JpaRepository<ItemCatalog, UUID> {

    Optional<ItemCatalog> findByCode(String code);

    /** Pessimistic lock khi đổi rule/metadata — serialize concurrent edit. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT i FROM ItemCatalog i WHERE i.id = :id")
    Optional<ItemCatalog> findByIdForUpdate(@Param("id") UUID id);

    /** Catalog phía learner: chỉ item đang active, sort ổn định theo code. */
    List<ItemCatalog> findByActiveTrueOrderByCodeAsc();

    /** Admin list — xem cả item đã ẩn; filter khi truyền. */
    @Query("""
            SELECT i FROM ItemCatalog i
            WHERE (:active IS NULL OR i.active = :active)
            ORDER BY i.code ASC
            """)
    Page<ItemCatalog> search(@Param("active") Boolean active, Pageable pageable);
}
