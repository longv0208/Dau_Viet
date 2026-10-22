package com.dauviet.collection.application;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.api.dto.CollectionItemResponse;
import com.dauviet.collection.domain.CollectedEvidenceNotFoundException;
import com.dauviet.collection.domain.UserEvidence;
import com.dauviet.collection.infrastructure.persistence.UserEvidenceRepository;
import com.dauviet.common.api.PageResponse;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.SnapshotCorruptException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Read-only Collection của learner hiện tại (TASK-0022). Identity luôn lấy
 * từ JWT — không bao giờ tin userId client gửi. Nội dung đọc từ
 * snapshot_json đã lưu lúc collect: evidence gốc bị sửa/archive hay lesson
 * republish không ảnh hưởng mục đã sưu tầm.
 */
@Service
public class CollectionService {

    private final UserEvidenceRepository userEvidence;
    private final HistoricalEventRepository events;
    private final ObjectMapper mapper;

    public CollectionService(UserEvidenceRepository userEvidence,
                             HistoricalEventRepository events,
                             ObjectMapper mapper) {
        this.userEvidence = userEvidence;
        this.events = events;
        this.mapper = mapper;
    }

    /**
     * Danh sách phân trang, mới nhất trước; filter theo evidence_type khi
     * client truyền. Mỗi evidence chỉ xuất hiện một lần — UNIQUE
     * (user_id, evidence_id) đã dedup ở tầng DB.
     */
    @Transactional(readOnly = true)
    public PageResponse<CollectionItemResponse> list(UUID userId,
                                                     String evidenceType,
                                                     UUID eventId,
                                                     Pageable pageable) {
        // eventId lọc theo snapshot_json.eventId (jsonb path) — tham chiếu
        // structure-level, không đổi khi evidence bị archive.
        String type = evidenceType == null || evidenceType.isBlank()
                ? null : evidenceType;
        Page<UserEvidence> page = userEvidence.search(userId, type, eventId,
                pageable);
        // Batch event titles — tránh N+1 findById mỗi item.
        List<UserEvidence> rows = page.getContent();
        Set<UUID> eventIds = rows.stream().map(UserEvidence::getEventId)
                .filter(java.util.Objects::nonNull).collect(Collectors.toSet());
        Map<UUID, String> titles = eventIds.isEmpty() ? Map.of()
                : events.findAllById(eventIds).stream().collect(Collectors.toMap(
                        HistoricalEvent::getId, HistoricalEvent::getTitle));
        return PageResponse.from(page.map(r -> toResponse(r, titles)));
    }

    /** Chi tiết một mục đã collect — 404 nếu không thuộc learner này. */
    @Transactional(readOnly = true)
    public CollectionItemResponse detail(UUID userId, UUID evidenceId) {
        UserEvidence row = userEvidence.findByUserIdAndEvidenceId(userId, evidenceId)
                .orElseThrow(() -> new CollectedEvidenceNotFoundException(
                        "no collected evidence " + evidenceId + " for user"));
        UUID eventId = row.getEventId();
        Map<UUID, String> titles = eventId == null ? Map.of()
                : events.findById(eventId).map(HistoricalEvent::getTitle)
                        .map(t -> Map.of(eventId, t)).orElse(Map.of());
        return toResponse(row, titles);
    }

    /* ---------- internals ---------- */

    private CollectionItemResponse toResponse(UserEvidence row,
                                              Map<UUID, String> eventTitles) {
        JsonNode env = parse(row.getSnapshotJson());
        JsonNode ev = env == null ? null : env.get("evidence");
        UUID eventId = row.getEventId();
        String eventTitle = eventId == null ? null : eventTitles.get(eventId);
        return new CollectionItemResponse(
                row.getEvidenceId(),
                row.getEvidenceType() != null
                        ? row.getEvidenceType() : text(ev, "evidenceType"),
                row.getCollectedAt(),
                eventId,
                eventTitle,
                uuid(text(env, "lessonId")),
                text(env, "lessonTitle"),
                snapshotOf(ev));
    }

    private CollectionItemResponse.EvidenceSnapshot snapshotOf(JsonNode ev) {
        if (ev == null) return null;
        JsonNode src = ev.get("source");
        return new CollectionItemResponse.EvidenceSnapshot(
                text(ev, "title"),
                text(ev, "description"),
                text(ev, "assetId"),
                src == null ? null : new CollectionItemResponse.SourceDto(
                        text(src, "title"), text(src, "author"),
                        text(src, "url"), text(src, "citation"),
                        text(src, "publishedAt")));
    }

    private JsonNode parse(String json) {
        if (json == null || json.isBlank()) return null;
        try {
            return mapper.readTree(json);
        } catch (Exception e) {
            throw new SnapshotCorruptException(
                    "unparseable user_evidence.snapshot_json: " + e.getMessage());
        }
    }

    private static String text(JsonNode node, String field) {
        JsonNode v = node == null ? null : node.get(field);
        return v != null && v.isTextual() ? v.asText() : null;
    }

    private static UUID uuid(String raw) {
        if (raw == null) return null;
        try {
            return UUID.fromString(raw);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
