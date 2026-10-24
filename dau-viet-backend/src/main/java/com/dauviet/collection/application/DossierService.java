package com.dauviet.collection.application;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.api.dto.DossierDtos.DossierDetailResponse;
import com.dauviet.collection.api.dto.DossierDtos.DossierSourceDto;
import com.dauviet.collection.api.dto.DossierDtos.DossierSummaryResponse;
import com.dauviet.collection.domain.DossierNotFoundException;
import com.dauviet.collection.infrastructure.persistence.DossierQueryRepository;
import com.dauviet.common.api.PageResponse;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Read-side dossier (GAME-04 §11). Visibility:
 *  - DRAFT      → invisible (404 cả detail, loại khỏi list).
 *  - PUBLISHED  → list mọi learner; detail: unlocked = full, locked = preview.
 *  - ARCHIVED   → chỉ learner đã unlock mới thấy; detail full.
 * Preview chỉ lộ metadata title-level — description + source giữ cho owner.
 */
@Service
public class DossierService {

    private final DossierQueryRepository queries;
    private final ObjectMapper mapper;

    public DossierService(DossierQueryRepository queries, ObjectMapper mapper) {
        this.queries = queries;
        this.mapper = mapper;
    }

    /**
     * List phân trang, sort (title,id) ổn định. `unlocked` null = cả hai;
     * true = chỉ đã mở; false = chỉ preview.
     */
    @Transactional(readOnly = true)
    public PageResponse<DossierSummaryResponse> list(UUID userId, String type,
            UUID eventId, Boolean unlocked, Pageable pageable) {
        String normalizedType = normalizeType(type);
        List<DossierQueryRepository.Row> rows = queries.list(
                userId, normalizedType, eventId, unlocked, pageable);
        long total = queries.count(userId, normalizedType, eventId, unlocked);
        Map<UUID, List<UUID>> eventIds = queries.eventIdsOf(
                rows.stream().map(DossierQueryRepository.Row::id)
                        .collect(Collectors.toSet()));
        List<DossierSummaryResponse> items = rows.stream()
                .map(r -> toSummary(r, eventIds)).toList();
        int totalPages = pageable.getPageSize() == 0 ? 0
                : (int) Math.ceil((double) total / pageable.getPageSize());
        return new PageResponse<>(items, pageable.getPageNumber(),
                pageable.getPageSize(), total, totalPages);
    }

    /**
     * Detail theo visibility rule trên. DRAFT → 404 như không tồn tại.
     * ARCHIVED + chưa unlock → 404 (không mở mới dossier archive, §11.4).
     */
    @Transactional(readOnly = true)
    public DossierDetailResponse detail(UUID userId, UUID dossierId) {
        DossierQueryRepository.Row r = queries.detail(userId, dossierId);
        if (r == null || "DRAFT".equals(r.status())) {
            throw new DossierNotFoundException("dossier not found: " + dossierId);
        }
        boolean unlocked = r.grantedAt() != null;
        if (!unlocked && "ARCHIVED".equals(r.status())) {
            throw new DossierNotFoundException("dossier not found: " + dossierId);
        }
        List<UUID> eventIds = queries.eventIdsOf(Set.of(r.id()))
                .getOrDefault(r.id(), List.of());
        boolean preview = !unlocked;
        return new DossierDetailResponse(
                r.id(), r.canonicalCode(), r.dossierType(), r.title(),
                r.summary(),
                preview ? null : r.description(),
                r.assetId(),
                preview ? null : sourceOf(r.sourceJson()),
                eventIds,
                unlocked, r.grantedAt(), r.unlockEventId(),
                unlocked ? r.dossierVersion() : null,
                preview);
    }

    private DossierSummaryResponse toSummary(DossierQueryRepository.Row r,
                                             Map<UUID, List<UUID>> eventIds) {
        boolean unlocked = r.grantedAt() != null;
        return new DossierSummaryResponse(
                r.id(), r.canonicalCode(), r.dossierType(), r.title(),
                r.summary(), r.assetId(),
                eventIds.getOrDefault(r.id(), List.of()),
                unlocked, r.grantedAt(), r.unlockEventId(), !unlocked);
    }

    /** source_json → DTO citation; lỗi parse → null (không lộ raw). */
    private DossierSourceDto sourceOf(String json) {
        if (json == null || json.isBlank()) {
            return null;
        }
        try {
            JsonNode src = mapper.readTree(json).get("source");
            if (src == null) {
                return null;
            }
            return new DossierSourceDto(
                    text(src, "title"), text(src, "author"),
                    text(src, "citation"), text(src, "url"),
                    text(src, "reliability"));
        } catch (Exception e) {
            return null;
        }
    }

    private static String normalizeType(String type) {
        return type == null || type.isBlank() ? null : type.trim().toUpperCase();
    }

    private static String text(JsonNode node, String field) {
        JsonNode v = node == null ? null : node.get(field);
        return v != null && v.isTextual() ? v.asText() : null;
    }
}
