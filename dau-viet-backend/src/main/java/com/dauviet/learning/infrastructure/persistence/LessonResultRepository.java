package com.dauviet.learning.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.learning.domain.LessonResult;

@Repository
public interface LessonResultRepository extends JpaRepository<LessonResult, UUID> {

    Optional<LessonResult> findByLearnerAttemptId(UUID learnerAttemptId);

    /**
     * TASK-0023 reward backfill: (attempt_id, user_id, lesson_id) của mọi
     * attempt COMPLETED theo thứ tự thời gian — service lọc lần hoàn
     * thành đầu tiên mỗi (user, lesson) rồi grant qua cause_key idempotent.
     * Native query vì cần join learner_attempts + lesson_versions mà
     * LessonResult không giữ quan hệ entity.
     */
    @Query(value = """
            SELECT a.id, a.user_id, v.lesson_id
            FROM learner_attempts a
            JOIN lesson_versions v ON v.id = a.lesson_version_id
            WHERE a.status = 'COMPLETED'
            ORDER BY a.completed_at ASC
            """, nativeQuery = true)
    List<Object[]> findCompletedAttemptsForBackfill();

    /**
     * GAME-04 EVENT_MASTERED: best knowledgeScore của learner trên tập
     * lesson logic (mọi pinned version) — học lại được cải thiện mastery
     * (best-valid-result), không bao giờ làm mất grant. Trả (lesson_id,
     * best_knowledge_score) với score lấy từ result_json.knowledgeScore của
     * mỗi attempt COMPLETED; null/0 coi như chưa đo được.
     */
    @Query(value = """
            SELECT v.lesson_id, MAX(COALESCE((r.result_json->>'knowledgeScore')::numeric, 0))
            FROM lesson_results r
            JOIN learner_attempts a ON a.id = r.learner_attempt_id
            JOIN lesson_versions v ON v.id = a.lesson_version_id
            WHERE a.user_id = :userId AND a.status = 'COMPLETED'
              AND v.lesson_id IN (:lessonIds)
            GROUP BY v.lesson_id
            """, nativeQuery = true)
    List<Object[]> bestKnowledgeScoresByLesson(@Param("userId") UUID userId,
                                               @Param("lessonIds")
                                               java.util.List<UUID> lessonIds);

    /**
     * GAME-04 NOT_ASSESSED (FIX 6 — sync với GradedActivityClassifier):
     * lesson "có graded activity" = có attempt COMPLETED mà pinned snapshot
     * chứa ≥1 REQUIRED activity trong REQUIRED stage thuộc loại chấm điểm.
     *
     * Đồng bộ classifier Java (không duy trì bảng song song):
     *  - contract-graded: MULTIPLE_CHOICE/MATCHING/DRAG_ORDER/CER_CHOICE;
     *  - EVIDENCE_SELECT: config.graded:true AND acceptedEvidenceIds non-empty;
     *  - REASONING_CONNECT: config.graded:true AND (expectedRelations non-empty
     *    OR acceptedRelationSets[] có ≥1 set có phần tử hợp lệ — mirror
     *    acceptedSets của handler).
     *  - stage.required=true bắt buộc: activity required trong OPTIONAL stage
     *    không tính (Learning Engine chỉ score required-in-required).
     */
    @Query(value = """
            SELECT DISTINCT v.lesson_id
            FROM learner_attempts a
            JOIN lesson_versions v ON v.id = a.lesson_version_id
            WHERE a.user_id = :userId AND a.status = 'COMPLETED'
              AND v.lesson_id IN (:lessonIds)
              AND EXISTS (
                SELECT 1
                FROM jsonb_array_elements(v.snapshot_json->'stages') st,
                     jsonb_array_elements(st->'activities') act
                WHERE (st->>'required')::boolean = true
                  AND act->>'required' = 'true'
                  AND (
                    act->>'type' IN
                      ('MULTIPLE_CHOICE','MATCHING','DRAG_ORDER','CER_CHOICE')
                    OR (act->>'type' = 'EVIDENCE_SELECT'
                        AND (act->'config'->>'graded')::boolean = true
                        AND jsonb_array_length(
                            COALESCE(act->'config'->'acceptedEvidenceIds',
                                     '[]'::jsonb)) > 0)
                    OR (act->>'type' = 'REASONING_CONNECT'
                        AND (act->'config'->>'graded')::boolean = true
                        AND (
                          jsonb_array_length(
                            COALESCE(act->'config'->'expectedRelations',
                                     '[]'::jsonb)) > 0
                          OR EXISTS (
                            SELECT 1
                            FROM jsonb_array_elements(
                                COALESCE(act->'config'
                                         ->'acceptedRelationSets',
                                         '[]'::jsonb)) alt
                            WHERE jsonb_array_length(alt) > 0
                          )
                        )
                      )
                  )
              )
            """, nativeQuery = true)
    java.util.Set<UUID> lessonsWithGradedActivity(@Param("userId") UUID userId,
                                                  @Param("lessonIds")
                                                  java.util.List<UUID> lessonIds);
}
