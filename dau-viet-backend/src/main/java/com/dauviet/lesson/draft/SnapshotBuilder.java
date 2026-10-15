package com.dauviet.lesson.draft;

import java.util.LinkedHashSet;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.dauviet.lesson.domain.Asset;
import com.dauviet.lesson.domain.Evidence;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonTemplate;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.dauviet.lesson.infrastructure.persistence.EvidenceRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Builds the immutable lesson_versions.snapshot_json payload.
 * The snapshot is the single published source of truth: stages/completion are
 * copied verbatim from the draft (server-only keys retained for future
 * server-side evaluation), while referenced evidence and assets are embedded
 * denormalized so later admin edits cannot retroactively change a published
 * version — and the EVIDENCE_IN_USE id LIKE-scan keeps working.
 */
@Component
public class SnapshotBuilder {

    /** config field names that hold evidence-id references inside activities. */
    private static final Set<String> EVIDENCE_REF_FIELDS =
            Set.of("visibleEvidenceIds", "requiredEvidenceIds", "visibleSourceIds");

    private final EvidenceRepository evidences;
    private final AssetRepository assets;
    private final ObjectMapper mapper;

    public SnapshotBuilder(EvidenceRepository evidences, AssetRepository assets,
                           ObjectMapper mapper) {
        this.evidences = evidences;
        this.assets = assets;
        this.mapper = mapper;
    }

    /**
     * Build the snapshot document for `lesson` from its parsed draft.
     * Call after PUBLISH validation so every referenced id resolves.
     */
    public ObjectNode build(Lesson lesson, JsonNode draft, LessonTemplate template) {
        ObjectNode snapshot = mapper.createObjectNode();
        snapshot.put("schemaVersion", DraftSchema.CURRENT_VERSION);
        snapshot.put("lessonId", lesson.getId().toString());
        snapshot.put("title", lesson.getTitle());
        snapshot.put("centralQuestion", lesson.getCentralQuestion());
        snapshot.set("objectives", parse(lesson.getObjectivesJson()));
        snapshot.put("templateCode", template.getCode());
        snapshot.set("stages", draft.path("stages"));
        if (draft.has("completion")) {
            snapshot.set("completion", draft.get("completion"));
        }
        snapshot.set("evidence", embedEvidence(collectEvidenceIds(draft)));
        snapshot.set("assets", embedAssets(collectAssetIds(draft, snapshot)));
        return snapshot;
    }

    /* ---------- reference collection ---------- */

    /** Every evidence id the draft references: stage-level + activity-level + config. */
    private Set<UUID> collectEvidenceIds(JsonNode draft) {
        Set<UUID> ids = new LinkedHashSet<>();
        JsonNode stages = draft.get("stages");
        if (stages == null || !stages.isArray()) return ids;
        for (JsonNode stage : stages) {
            addIds(ids, stage.get("requiredEvidenceIds"));
            JsonNode acts = stage.get("activities");
            if (acts == null || !acts.isArray()) continue;
            for (JsonNode act : acts) {
                addIds(ids, act.get("evidenceRefs"));
                JsonNode config = act.get("config");
                if (config == null || !config.isObject()) continue;
                for (String field : EVIDENCE_REF_FIELDS) {
                    addIds(ids, config.get(field));
                }
            }
        }
        return ids;
    }

    /** Asset ids: evidence.assetId + config.imageAssetId. */
    private Set<UUID> collectAssetIds(JsonNode draft, ObjectNode snapshot) {
        Set<UUID> ids = new LinkedHashSet<>();
        JsonNode evArray = snapshot.get("evidence");
        if (evArray != null && evArray.isArray()) {
            for (JsonNode ev : evArray) {
                if (ev.hasNonNull("assetId")) {
                    UUID id = parseUuid(ev.get("assetId").asText());
                    if (id != null) ids.add(id);
                }
            }
        }
        JsonNode stages = draft.get("stages");
        if (stages == null || !stages.isArray()) return ids;
        for (JsonNode stage : stages) {
            JsonNode acts = stage.get("activities");
            if (acts == null || !acts.isArray()) continue;
            for (JsonNode act : acts) {
                JsonNode config = act.get("config");
                if (config != null && config.hasNonNull("imageAssetId")) {
                    UUID id = parseUuid(config.get("imageAssetId").asText());
                    if (id != null) ids.add(id);
                }
            }
        }
        return ids;
    }

    /* ---------- embedding ---------- */

    private ArrayNode embedEvidence(Set<UUID> ids) {
        ArrayNode out = mapper.createArrayNode();
        if (ids.isEmpty()) return out;
        for (Evidence e : evidences.findAllById(ids)) {
            ObjectNode node = mapper.createObjectNode();
            node.put("id", e.getId().toString());
            node.put("title", e.getTitle());
            node.put("evidenceType", e.getEvidenceType());
            putIfNotNull(node, "description", e.getDescription());
            ObjectNode source = node.putObject("source");
            source.put("title", e.getSourceTitle());
            putIfNotNull(source, "author", e.getSourceAuthor());
            putIfNotNull(source, "url", e.getSourceUrl());
            putIfNotNull(source, "citation", e.getSourceCitation());
            if (e.getSourcePublishedAt() != null) {
                source.put("publishedAt", e.getSourcePublishedAt().toString());
            }
            putIfNotNull(node, "reliability", e.getReliability());
            putIfNotNull(node, "relevance", e.getRelevance());
            if (e.getAssetId() != null) {
                node.put("assetId", e.getAssetId().toString());
            }
            out.add(node);
        }
        return out;
    }

    private ArrayNode embedAssets(Set<UUID> ids) {
        ArrayNode out = mapper.createArrayNode();
        if (ids.isEmpty()) return out;
        for (Asset a : assets.findAllById(ids)) {
            ObjectNode node = mapper.createObjectNode();
            node.put("id", a.getId().toString());
            node.put("storageKey", a.getStorageKey());
            node.put("mimeType", a.getMimeType());
            node.put("sizeBytes", a.getSizeBytes());
            putIfNotNull(node, "originalFilename", a.getOriginalFilename());
            putIfNotNull(node, "altText", a.getAltText());
            out.add(node);
        }
        return out;
    }

    /* ---------- helpers ---------- */

    private void addIds(Set<UUID> ids, JsonNode array) {
        if (array == null || !array.isArray()) return;
        for (JsonNode item : array) {
            if (item.isTextual()) {
                UUID id = parseUuid(item.asText());
                if (id != null) ids.add(id);
            }
        }
    }

    private static UUID parseUuid(String text) {
        try {
            return UUID.fromString(text);
        } catch (RuntimeException e) {
            return null;
        }
    }

    private static void putIfNotNull(ObjectNode node, String field, String value) {
        if (value != null) node.put(field, value);
    }

    private JsonNode parse(String json) {
        try {
            JsonNode node = mapper.readTree(json == null ? "[]" : json);
            return node == null ? mapper.createArrayNode() : node;
        } catch (Exception e) {
            return mapper.createArrayNode();
        }
    }
}
