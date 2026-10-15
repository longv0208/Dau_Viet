package com.dauviet.lesson.application;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import com.dauviet.lesson.api.dto.ActivityDto;
import com.dauviet.lesson.api.dto.ActivityPatchRequest;
import com.dauviet.lesson.api.dto.ActivityUpsertRequest;
import com.dauviet.lesson.api.dto.DraftActivitiesResponse;
import com.dauviet.lesson.api.dto.DraftStagesResponse;
import com.dauviet.lesson.api.dto.StageDto;
import com.dauviet.lesson.api.dto.StagePatchRequest;
import com.dauviet.lesson.api.dto.StageUpsertRequest;
import com.dauviet.lesson.domain.ActivityNotFoundException;
import com.dauviet.lesson.domain.InvalidStatusTransitionException;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonNotFoundException;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.domain.StageNotFoundException;
import com.dauviet.lesson.draft.DraftValidationException;
import com.dauviet.lesson.draft.DraftValidator;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.ValidationLevel;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;

/**
 * Stage/activity mutations on the canonical draft_json document.
 * Every write goes through mutateDraft → SAVE-level validation → persist,
 * so a malformed draft can never be stored via the sub-resource APIs.
 */
@Service
public class LessonDraftService {

    private final LessonRepository lessons;
    private final DraftValidator draftValidator;
    private final ObjectMapper mapper;

    public LessonDraftService(LessonRepository lessons,
                              DraftValidator draftValidator,
                              ObjectMapper mapper) {
        this.lessons = lessons;
        this.draftValidator = draftValidator;
        this.mapper = mapper;
    }

    /* ---------------- reads ---------------- */

    @Transactional(readOnly = true)
    public DraftStagesResponse listStages(UUID lessonId) {
        Lesson l = load(lessonId);
        ObjectNode draft = draftOf(l);
        List<StageDto> stages = new ArrayList<>();
        for (JsonNode s : draft.withArray("stages")) {
            stages.add(toStageDto((ObjectNode) s));
        }
        return new DraftStagesResponse(stages, l.getRowVersion());
    }

    @Transactional(readOnly = true)
    public StageDto getStage(UUID lessonId, String stageId) {
        Lesson l = load(lessonId);
        return toStageDto(requireStage(draftOf(l), stageId));
    }

    @Transactional(readOnly = true)
    public DraftActivitiesResponse listActivities(UUID lessonId, String stageId) {
        Lesson l = load(lessonId);
        ObjectNode stage = requireStage(draftOf(l), stageId);
        List<ActivityDto> acts = new ArrayList<>();
        JsonNode arr = stage.get("activities");
        if (arr != null && arr.isArray()) {
            for (JsonNode a : arr) acts.add(toActivityDto((ObjectNode) a));
        }
        return new DraftActivitiesResponse(acts, l.getRowVersion());
    }

    @Transactional(readOnly = true)
    public ActivityDto getActivity(UUID lessonId, String stageId, String activityId) {
        Lesson l = load(lessonId);
        ObjectNode stage = requireStage(draftOf(l), stageId);
        return toActivityDto(requireActivity(stage, activityId));
    }

    /* ---------------- stage mutations ---------------- */

    @Transactional
    public StageDto addStage(UUID lessonId, StageUpsertRequest req, UUID adminId) {
        return mutateDraft(lessonId, req.expectedRowVersion(), adminId, draft -> {
            ArrayNode stages = draft.withArray("stages");
            String id = req.id() == null || req.id().isBlank()
                    ? genId("stage", stages) : req.id();
            ObjectNode stage = mapper.createObjectNode();
            stage.put("id", id);
            stage.put("type", req.type());
            if (req.title() != null) stage.put("title", req.title());
            stage.put("required", req.required() != null && req.required());
            stage.putArray("activities");
            if (req.nextStageIds() != null) {
                ArrayNode next = stage.putArray("nextStageIds");
                req.nextStageIds().forEach(next::add);
            }
            int pos = req.position() == null ? stages.size()
                    : Math.max(0, Math.min(req.position(), stages.size()));
            stages.insert(pos, stage);
            return toStageDto(stage);
        });
    }

    @Transactional
    public StageDto updateStage(UUID lessonId, String stageId,
                                StagePatchRequest req, UUID adminId) {
        return mutateDraft(lessonId, req.expectedRowVersion(), adminId, draft -> {
            ObjectNode stage = requireStage(draft, stageId);
            if (req.title() != null) stage.put("title", req.title());
            if (req.required() != null) stage.put("required", req.required());
            if (req.nextStageIds() != null) {
                ArrayNode next = mapper.createArrayNode();
                req.nextStageIds().forEach(next::add);
                stage.set("nextStageIds", next);
            }
            if (req.requiredEvidenceIds() != null) {
                ArrayNode refs = mapper.createArrayNode();
                req.requiredEvidenceIds().forEach(refs::add);
                stage.set("requiredEvidenceIds", refs);
            }
            return toStageDto(stage);
        });
    }

    @Transactional
    public DraftStagesResponse reorderStages(UUID lessonId, List<String> orderedIds,
                                             Long expectedRowVersion, UUID adminId) {
        return mutateDraft(lessonId, expectedRowVersion, adminId, (draft, lesson) -> {
            ArrayNode stages = draft.withArray("stages");
            ArrayNode reordered = reorderArray(stages, orderedIds, "stage");
            draft.set("stages", reordered);
            List<StageDto> out = new ArrayList<>();
            for (JsonNode s : reordered) out.add(toStageDto((ObjectNode) s));
            return new DraftStagesResponse(out, lesson.getRowVersion());
        });
    }

    @Transactional
    public DraftStagesResponse removeStage(UUID lessonId, String stageId,
                                           Long expectedRowVersion, UUID adminId) {
        return mutateDraft(lessonId, expectedRowVersion, adminId, (draft, lesson) -> {
            ArrayNode stages = draft.withArray("stages");
            int idx = indexOf(stages, stageId);
            if (idx < 0) throw new StageNotFoundException("Stage not found: " + stageId);
            stages.remove(idx);
            // prune transitions + completion references
            for (JsonNode s : stages) {
                JsonNode next = s.get("nextStageIds");
                if (next != null && next.isArray()) {
                    ArrayNode kept = mapper.createArrayNode();
                    for (JsonNode t : next) {
                        if (!stageId.equals(t.asText())) kept.add(t);
                    }
                    ((ObjectNode) s).set("nextStageIds", kept);
                }
            }
            JsonNode completion = draft.get("completion");
            if (completion != null && completion.isObject()) {
                JsonNode req = completion.get("requiredStageIds");
                if (req != null && req.isArray()) {
                    ArrayNode kept = mapper.createArrayNode();
                    for (JsonNode t : req) {
                        if (!stageId.equals(t.asText())) kept.add(t);
                    }
                    ((ObjectNode) completion).set("requiredStageIds", kept);
                }
            }
            List<StageDto> out = new ArrayList<>();
            for (JsonNode s : stages) out.add(toStageDto((ObjectNode) s));
            return new DraftStagesResponse(out, lesson.getRowVersion());
        });
    }

    /* ---------------- activity mutations ---------------- */

    @Transactional
    public ActivityDto addActivity(UUID lessonId, String stageId,
                                   ActivityUpsertRequest req, UUID adminId) {
        return mutateDraft(lessonId, req.expectedRowVersion(), adminId, draft -> {
            ObjectNode stage = requireStage(draft, stageId);
            ArrayNode acts = stage.withArray("activities");
            String id = req.id() == null || req.id().isBlank()
                    ? genId("act", acts) : req.id();
            ObjectNode act = mapper.createObjectNode();
            act.put("id", id);
            act.put("type", req.type());
            if (req.required() != null) act.put("required", req.required());
            if (req.instruction() != null) act.put("instruction", req.instruction());
            if (req.config() != null) act.set("config", req.config());
            if (req.validation() != null) act.set("validation", req.validation());
            if (req.feedback() != null) act.set("feedback", req.feedback());
            if (req.evidenceRefs() != null) {
                ArrayNode refs = act.putArray("evidenceRefs");
                req.evidenceRefs().forEach(refs::add);
            }
            int pos = req.position() == null ? acts.size()
                    : Math.max(0, Math.min(req.position(), acts.size()));
            acts.insert(pos, act);
            return toActivityDto(act);
        });
    }

    @Transactional
    public ActivityDto updateActivity(UUID lessonId, String stageId, String activityId,
                                      ActivityPatchRequest req, UUID adminId) {
        return mutateDraft(lessonId, req.expectedRowVersion(), adminId, draft -> {
            ObjectNode stage = requireStage(draft, stageId);
            ObjectNode act = requireActivity(stage, activityId);
            if (req.required() != null) act.put("required", req.required());
            if (req.instruction() != null) act.put("instruction", req.instruction());
            if (req.config() != null) act.set("config", req.config());
            if (req.validation() != null) act.set("validation", req.validation());
            if (req.feedback() != null) act.set("feedback", req.feedback());
            if (req.evidenceRefs() != null) {
                ArrayNode refs = mapper.createArrayNode();
                req.evidenceRefs().forEach(refs::add);
                act.set("evidenceRefs", refs);
            }
            return toActivityDto(act);
        });
    }

    @Transactional
    public DraftActivitiesResponse reorderActivities(UUID lessonId, String stageId,
                                                     List<String> orderedIds,
                                                     Long expectedRowVersion, UUID adminId) {
        return mutateDraft(lessonId, expectedRowVersion, adminId, (draft, lesson) -> {
            ObjectNode stage = requireStage(draft, stageId);
            ArrayNode acts = stage.withArray("activities");
            ArrayNode reordered = reorderArray(acts, orderedIds, "activity");
            stage.set("activities", reordered);
            List<ActivityDto> out = new ArrayList<>();
            for (JsonNode a : reordered) out.add(toActivityDto((ObjectNode) a));
            return new DraftActivitiesResponse(out, lesson.getRowVersion());
        });
    }

    @Transactional
    public DraftActivitiesResponse removeActivity(UUID lessonId, String stageId,
                                                  String activityId,
                                                  Long expectedRowVersion, UUID adminId) {
        return mutateDraft(lessonId, expectedRowVersion, adminId, (draft, lesson) -> {
            ObjectNode stage = requireStage(draft, stageId);
            ArrayNode acts = stage.withArray("activities");
            int idx = indexOf(acts, activityId);
            if (idx < 0) {
                throw new ActivityNotFoundException(
                        "Activity not found: " + activityId + " in stage " + stageId);
            }
            acts.remove(idx);
            List<ActivityDto> out = new ArrayList<>();
            for (JsonNode a : acts) out.add(toActivityDto((ObjectNode) a));
            return new DraftActivitiesResponse(out, lesson.getRowVersion());
        });
    }

    /* ---------------- core mutate pipeline ---------------- */

    /**
     * Load lesson → mutate draft tree → SAVE-validate → persist.
     * The mutation sees the draft tree; the BiFunction variant also sees the
     * Lesson so the result can embed the fresh rowVersion after save.
     */
    private <T> T mutateDraft(UUID lessonId, Long expectedRowVersion, UUID adminId,
                              java.util.function.Function<ObjectNode, T> mutation) {
        return mutateDraft(lessonId, expectedRowVersion, adminId,
                (draft, lesson) -> mutation.apply(draft));
    }

    private <T> T mutateDraft(UUID lessonId, Long expectedRowVersion, UUID adminId,
                              java.util.function.BiFunction<ObjectNode, Lesson, T> mutation) {
        Lesson l = load(lessonId);
        if (expectedRowVersion != null && !expectedRowVersion.equals(l.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    Lesson.class, lessonId);
        }
        if (l.getStatus() == LessonStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived lesson cannot be edited");
        }
        if (l.getStatus() != LessonStatus.DRAFT) {
            throw new InvalidStatusTransitionException(
                    "draft structure can only be edited while lesson is DRAFT");
        }
        ObjectNode draft = draftOf(l);
        List<FieldError> errs;
        T result = mutation.apply(draft, l);
        errs = draftValidator.validate(draft, l.getEventId(), ValidationLevel.SAVE);
        if (!errs.isEmpty()) throw new DraftValidationException(errs);
        l.setDraftJson(draft.toString());
        l.setUpdatedBy(adminId);
        Lesson saved = lessons.saveAndFlush(l);
        // The mutation produced its result before save — refresh rowVersion if
        // the result is a wrapper that carries it.
        if (result instanceof DraftStagesResponse r) {
            return (T) new DraftStagesResponse(r.stages(), saved.getRowVersion());
        }
        if (result instanceof DraftActivitiesResponse r) {
            return (T) new DraftActivitiesResponse(r.activities(), saved.getRowVersion());
        }
        return result;
    }

    /* ---------------- helpers ---------------- */

    private Lesson load(UUID id) {
        return lessons.findById(id)
                .orElseThrow(() -> new LessonNotFoundException("Lesson not found: " + id));
    }

    private ObjectNode draftOf(Lesson l) {
        try {
            JsonNode node = mapper.readTree(
                    l.getDraftJson() == null ? "{}" : l.getDraftJson());
            if (node == null || !node.isObject()) {
                throw new IllegalStateException("lesson draft_json is not an object");
            }
            return (ObjectNode) node;
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw new IllegalStateException("lesson draft_json is not parseable", e);
        }
    }

    private ObjectNode requireStage(ObjectNode draft, String stageId) {
        JsonNode stages = draft.get("stages");
        if (stages != null && stages.isArray()) {
            for (JsonNode s : stages) {
                if (stageId.equals(s.path("id").asText())) return (ObjectNode) s;
            }
        }
        throw new StageNotFoundException("Stage not found: " + stageId);
    }

    private ObjectNode requireActivity(ObjectNode stage, String activityId) {
        JsonNode acts = stage.get("activities");
        if (acts != null && acts.isArray()) {
            for (JsonNode a : acts) {
                if (activityId.equals(a.path("id").asText())) return (ObjectNode) a;
            }
        }
        throw new ActivityNotFoundException(
                "Activity not found: " + activityId + " in stage " + stage.path("id").asText());
    }

    /**
     * Reorder an array whose elements carry an "id" field so they match the
     * given ordered id list exactly (same set, no duplicates, no extras).
     */
    private ArrayNode reorderArray(ArrayNode arr, List<String> orderedIds, String kind) {
        if (orderedIds == null) return arr;
        if (new LinkedHashSet<>(orderedIds).size() != orderedIds.size()) {
            throw new IllegalArgumentException("duplicate ids in orderedIds");
        }
        Map<String, JsonNode> byId = new HashMap<>();
        for (JsonNode n : arr) byId.put(n.path("id").asText(), n);
        if (byId.size() != orderedIds.size() || !byId.keySet().containsAll(orderedIds)) {
            throw new IllegalArgumentException(
                    "orderedIds must list every " + kind + " id exactly once");
        }
        ArrayNode out = mapper.createArrayNode();
        for (String id : orderedIds) out.add(byId.get(id));
        return out;
    }

    private int indexOf(ArrayNode arr, String id) {
        for (int i = 0; i < arr.size(); i++) {
            if (id.equals(arr.get(i).path("id").asText())) return i;
        }
        return -1;
    }

    /** Generate a slug id unique within the array: prefix, prefix-2, ... */
    private String genId(String prefix, ArrayNode arr) {
        String candidate = prefix;
        int n = 1;
        while (indexOf(arr, candidate) >= 0) {
            candidate = prefix + "-" + (++n);
        }
        return candidate;
    }

    private StageDto toStageDto(ObjectNode s) {
        return new StageDto(
                s.path("id").asText(),
                s.path("type").asText(null),
                s.has("title") ? s.get("title").asText() : null,
                s.has("required") ? s.get("required").asBoolean() : null,
                jsonList(s.get("activities")),
                textList(s.get("nextStageIds")),
                textList(s.get("requiredEvidenceIds")));
    }

    private ActivityDto toActivityDto(ObjectNode a) {
        return new ActivityDto(
                a.path("id").asText(),
                a.path("type").asText(null),
                a.has("required") ? a.get("required").asBoolean() : null,
                a.has("instruction") ? a.get("instruction").asText() : null,
                a.get("config"),
                a.get("validation"),
                a.get("feedback"),
                textList(a.get("evidenceRefs")));
    }

    private List<JsonNode> jsonList(JsonNode arr) {
        List<JsonNode> out = new ArrayList<>();
        if (arr != null && arr.isArray()) arr.forEach(out::add);
        return out;
    }

    private List<String> textList(JsonNode arr) {
        List<String> out = new ArrayList<>();
        if (arr != null && arr.isArray()) arr.forEach(n -> out.add(n.asText()));
        return out;
    }
}
