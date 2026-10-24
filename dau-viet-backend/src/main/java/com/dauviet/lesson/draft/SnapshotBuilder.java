package com.dauviet.lesson.draft;

import java.util.LinkedHashSet;
import java.util.Set;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private static final Logger log = LoggerFactory.getLogger(SnapshotBuilder.class);

    /** config field names that hold evidence-id references inside activities. */
    private static final Set<String> EVIDENCE_REF_FIELDS =
            Set.of("visibleEvidenceIds", "requiredEvidenceIds", "visibleSourceIds",
                    "acceptedEvidenceIds");

    /** config fields that hold arrays of {id:<evidence-uuid>} objects. */
    private static final Set<String> EVIDENCE_OBJECT_REF_FIELDS =
            Set.of("evidenceOptions");

    private final EvidenceRepository evidences;
    private final AssetRepository assets;
    private final ObjectMapper mapper;
    private final com.dauviet.animation.infrastructure.persistence
            .AnimationSceneVersionRepository sceneVersions;

    public SnapshotBuilder(EvidenceRepository evidences, AssetRepository assets,
                           ObjectMapper mapper,
                           com.dauviet.animation.infrastructure.persistence
                                   .AnimationSceneVersionRepository sceneVersions) {
        this.evidences = evidences;
        this.assets = assets;
        this.mapper = mapper;
        this.sceneVersions = sceneVersions;
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
        JsonNode stagesNode = draft.path("stages");
        if (!stagesNode.isArray()) {
            // Contract: draft.stages phải là JSON array — DraftValidator đã
            // chặn publish khi sai, nhưng builder cũng phải fail-fast với
            // lỗi có kiểm soát thay vì ClassCastException khi ép về
            // ObjectNode (stagesCopy là ArrayNode, không phải ObjectNode).
            throw new DraftValidationException(java.util.List.of(
                    new FieldError("stages", "STAGES_NOT_ARRAY",
                            "draft.stages must be a JSON array, got: "
                                    + stagesNode.getNodeType())));
        }
        ArrayNode stagesCopy = stagesNode.deepCopy();
        embedAnimationScenes(stagesCopy);
        snapshot.set("stages", stagesCopy);
        if (draft.has("completion")) {
            snapshot.set("completion", draft.get("completion"));
        }
        snapshot.set("evidence", embedEvidence(collectEvidenceIds(draft)));
        snapshot.set("assets", embedAssets(collectAssetIds(draft, snapshot)));
        return snapshot;
    }

    /**
     * Resolve each activity's animationSceneVersionId → embed the immutable
     * published manifest into the activity config as `animationManifest`
     * (manifest + renderer + version metadata). The lesson snapshot then
     * carries everything the runtime needs — no unpinned references.
     */
    private void embedAnimationScenes(JsonNode stages) {
        if (stages == null || !stages.isArray()) return;
        for (JsonNode stage : stages) {
            JsonNode acts = stage.get("activities");
            if (acts == null || !acts.isArray()) continue;
            for (JsonNode act : acts) {
                JsonNode config = act.get("config");
                if (config == null || !config.isObject()) continue;
                JsonNode ref = config.get("animationSceneVersionId");
                UUID versionId = ref != null && ref.isTextual()
                        ? parseUuid(ref.asText()) : null;
                if (versionId == null) {
                    // animationSceneId without explicit version: resolve the
                    // scene's CURRENT published version at publish time and
                    // pin it — the snapshot must never follow a moving pointer.
                    JsonNode sceneRef = config.get("animationSceneId");
                    UUID sceneId = sceneRef != null && sceneRef.isTextual()
                            ? parseUuid(sceneRef.asText()) : null;
                    if (sceneId == null) continue;
                    var latest = sceneVersions
                            .findTopBySceneIdOrderByVersionNoDesc(sceneId);
                    if (latest.isEmpty()) continue;
                    versionId = latest.get().getId();
                }
                sceneVersions.findById(versionId).ifPresent(v -> {
                    try {
                        JsonNode manifest = mapper.readTree(v.getSnapshotJson());
                        ObjectNode anim = ((ObjectNode) config).putObject("animationManifest");
                        anim.set("manifest", manifest);
                        anim.put("sceneVersionId", v.getId().toString());
                        anim.put("versionNo", v.getVersionNo());
                        anim.put("rendererCode", v.getRendererCode());
                        anim.put("rendererVersion", v.getRendererVersion());
                    } catch (Exception e) {
                        // Publish-level validation guarantees parseable JSON;
                        // a corrupt stored row must not pass silently — the
                        // lesson would publish without its animation.
                        log.warn("animation scene embed skipped: version={} err={}",
                                v.getId(), e.toString());
                    }
                });
            }
        }
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
                for (String field : EVIDENCE_OBJECT_REF_FIELDS) {
                    JsonNode arr = config.get(field);
                    if (arr != null && arr.isArray()) {
                        for (JsonNode item : arr) {
                            UUID id = parseUuid(item.path("id").asText(null));
                            if (id != null) ids.add(id);
                        }
                    }
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
                if (config == null || !config.isObject()) continue;
                if (config.hasNonNull("imageAssetId")) {
                    UUID id = parseUuid(config.get("imageAssetId").asText());
                    if (id != null) ids.add(id);
                }
                // Animation manifest assets — pinned into the snapshot so a
                // published lesson keeps working even if the asset is later
                // renamed (and ASSET_IN_USE LIKE-scan still sees the ids).
                collectManifestAssetIds(config.get("animationManifest"), ids);
            }
        }
        return ids;
    }

    /** Asset ids declared inside an embedded animation manifest. */
    private void collectManifestAssetIds(JsonNode animNode, Set<UUID> ids) {
        if (animNode == null || !animNode.isObject()) return;
        JsonNode manifest = animNode.get("manifest");
        if (manifest == null || !manifest.isObject()) return;
        JsonNode arr = manifest.get("assets");
        if (arr != null && arr.isArray()) {
            for (JsonNode a : arr) {
                // Post-publish the manifest's assets[] is replaced with
                // embedded asset metadata whose "id" is the assets.id itself.
                // Draft manifests may carry {id:<key>, assetId:<uuid>} —
                // accept both shapes.
                UUID id = parseUuid(a.path("id").asText(null));
                if (id == null) id = parseUuid(a.path("assetId").asText(null));
                if (id != null) ids.add(id);
            }
        }
        JsonNode map = manifest.get("map");
        if (map != null) {
            UUID bg = parseUuid(map.path("backgroundAssetId").asText(null));
            if (bg != null) ids.add(bg);
        }
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
