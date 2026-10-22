package com.dauviet.reward.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.reward.domain.ItemUnlockRule;

public interface ItemUnlockRuleRepository
        extends JpaRepository<ItemUnlockRule, UUID> {

    /** Rule đang active của một item (MVP: tối đa một — ux partial index). */
    Optional<ItemUnlockRule> findByItemIdAndActiveTrue(UUID itemId);

    /** Mọi rule của item kể cả đã tắt — cho admin detail. */
    List<ItemUnlockRule> findByItemIdOrderByCreatedAtAsc(UUID itemId);

    /** Rule đếm: COLLECTION_COUNT + LESSON_COUNT đang active. */
    @Query("""
            SELECT r FROM ItemUnlockRule r
            WHERE r.active = true AND r.ruleType IN
                  ('COLLECTION_COUNT','LESSON_COUNT')
            """)
    List<ItemUnlockRule> findActiveCountedRules();

    /** Rule LESSON_COMPLETED active cho một lesson cụ thể. */
    @Query("""
            SELECT r FROM ItemUnlockRule r
            WHERE r.active = true AND r.ruleType = 'LESSON_COMPLETED'
              AND r.lessonId = :lessonId
            """)
    List<ItemUnlockRule> findActiveLessonCompletedRules(
            @Param("lessonId") UUID lessonId);
}
