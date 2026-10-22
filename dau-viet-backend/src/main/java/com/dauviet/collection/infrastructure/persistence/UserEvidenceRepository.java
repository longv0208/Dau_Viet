package com.dauviet.collection.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.UserEvidence;

/**
 * Persistence cho user_evidence (TASK-0022). Ghi duy nhất qua
 * {@link #insertIgnore} — upsert ON CONFLICT (user_id, evidence_id) DO
 * NOTHING giữ collection idempotent dưới retry/replay/re-publish; UNIQUE
 * (learner_attempt_id, evidence_id) của V4 vẫn là backstop trong-attempt.
 */
public interface UserEvidenceRepository extends JpaRepository<UserEvidence, UUID> {

    /**
     * Ghi một mục collection; row đã tồn tại cho (user, evidence) → bỏ qua
     * (collected_at giữ lần collect đầu tiên). Chạy trong transaction của
     * submission — rollback cùng activity_attempt/attempt nếu submit lỗi.
     *
     * @return số row insert thực tế (0 = đã collect trước đó)
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_evidence
                (id, user_id, learner_attempt_id, evidence_id,
                 evidence_type, event_id, snapshot_json, collected_at)
            VALUES (gen_random_uuid(), :userId, :attemptId, :evidenceId,
                    :evidenceType, :eventId, CAST(:snapshotJson AS jsonb), now())
            ON CONFLICT (user_id, evidence_id) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("attemptId") UUID attemptId,
                     @Param("evidenceId") UUID evidenceId,
                     @Param("evidenceType") String evidenceType,
                     @Param("eventId") UUID eventId,
                     @Param("snapshotJson") String snapshotJson);

    /**
     * List phân trang mới nhất trước; filter evidence_type + event_id khi có
     * (event_id là cột riêng, có index idx_user_evidence_user_event).
     */
    @Query("""
            SELECT ue FROM UserEvidence ue
            WHERE ue.userId = :userId
              AND (:type IS NULL OR ue.evidenceType = :type)
              AND (:eventId IS NULL OR ue.eventId = :eventId)
            ORDER BY ue.collectedAt DESC, ue.evidenceId ASC
            """)
    Page<UserEvidence> search(@Param("userId") UUID userId,
                              @Param("type") String type,
                              @Param("eventId") UUID eventId,
                              Pageable pageable);

    Optional<UserEvidence> findByUserIdAndEvidenceId(UUID userId,
                                                     UUID evidenceId);

    /**
     * Toàn bộ evidence_type learner đã collect (P2-D — filter chips lấy
     * đủ loại trên mọi trang, không cần tải hết items). DISTINCT + sort
     * để response ổn định; bỏ null/blank phòng row cũ thiếu cột V10.
     */
    @Query("""
            SELECT DISTINCT ue.evidenceType FROM UserEvidence ue
            WHERE ue.userId = :userId
              AND ue.evidenceType IS NOT NULL
            ORDER BY ue.evidenceType ASC
            """)
    List<String> distinctEvidenceTypes(@Param("userId") UUID userId);
}
