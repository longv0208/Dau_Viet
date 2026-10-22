package com.dauviet.collection.application;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.dauviet.collection.infrastructure.persistence.UserEvidenceRepository;
import com.dauviet.learning.snapshot.SnapshotModel;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Ghi user_evidence từ submission EVIDENCE_SELECT đã được chấp nhận
 * (TASK-0022). Chỉ collect các evidenceId handler đã validate nằm trong
 * pinned snapshot — coi là tư liệu "đã khám phá", KHÔNG phải đáp án đúng.
 * Mỗi row giữ bản embedded evidence immutable từ snapshot cùng tham chiếu
 * lesson/event để Collection API đọc được kể cả khi evidence gốc bị
 * sửa/lưu trữ về sau. Chạy trong transaction của submit.
 */
@Component
public class EvidenceCollectionRecorder {

    private static final Logger log =
            LoggerFactory.getLogger(EvidenceCollectionRecorder.class);

    private final UserEvidenceRepository userEvidence;
    private final LessonRepository lessons;
    private final ObjectMapper mapper;

    public EvidenceCollectionRecorder(UserEvidenceRepository userEvidence,
                                      LessonRepository lessons,
                                      ObjectMapper mapper) {
        this.userEvidence = userEvidence;
        this.lessons = lessons;
        this.mapper = mapper;
    }

    /**
     * Upsert (user_id, evidence_id) — idempotent: repeat submit, replay
     * Idempotency-Key, hay attempt mới của cùng bài đều không tạo trùng.
     * Gọi SAU KHI handler trả result.completed(); `lessonId` là lesson đang
     * pin bởi attempt (resolve từ lesson_versions).
     */
    public void record(UUID userId, UUID attemptId, JsonNode selectedIds,
                       SnapshotModel model, UUID lessonId) {
        if (selectedIds == null || !selectedIds.isArray()) return;
        UUID eventId = lessonId == null ? null
                : lessons.findById(lessonId).map(l -> l.getEventId()).orElse(null);
        for (JsonNode idNode : selectedIds) {
            if (!idNode.isTextual()) continue;
            UUID evidenceId;
            try {
                evidenceId = UUID.fromString(idNode.asText());
            } catch (IllegalArgumentException malformed) {
                // Handler đã chặn id ngoài snapshot; id không-parse được thì
                // cũng không thể là row evidences hợp lệ → bỏ qua thay vì 500.
                continue;
            }
            JsonNode embedded = model.evidenceById(idNode.asText());
            if (embedded == null) continue; // không trong snapshot → không collect
            userEvidence.insertIgnore(userId, attemptId, evidenceId,
                    embedded.path("evidenceType").asText(null), eventId,
                    envelopeJson(embedded, model, lessonId));
        }
    }

    /**
     * Bọc evidence node nhúng với tham chiếu lesson/event tại thời điểm
     * collect — snapshot root chứa lessonId/title; eventId tra từ lesson
     * (cấu trúc, không đổi khi evidence bị archive).
     */
    private String envelopeJson(JsonNode embedded, SnapshotModel model,
                                UUID lessonId) {
        try {
            ObjectNode env = mapper.createObjectNode();
            env.set("evidence", embedded);
            JsonNode root = model.root();
            if (root.hasNonNull("lessonId")) {
                env.put("lessonId", root.get("lessonId").asText());
            } else if (lessonId != null) {
                env.put("lessonId", lessonId.toString());
            }
            if (root.hasNonNull("title")) {
                env.put("lessonTitle", root.get("title").asText());
            }
            return env.toString();
        } catch (RuntimeException e) {
            // Envelope chỉ phục vụ hiển thị; evidence node vẫn đủ giá trị.
            log.warn("collection envelope build failed: {}", e.getMessage());
            return "{\"evidence\":" + embedded.toString() + "}";
        }
    }
}
