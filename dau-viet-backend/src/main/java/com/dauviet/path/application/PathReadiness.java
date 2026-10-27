package com.dauviet.path.application;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Component;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.domain.SnapshotCorruptException;
import com.dauviet.lesson.infrastructure.persistence.LessonVersionRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.path.domain.PathContentStatus;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** One readiness rule for admin, publish validation and learner projections. */
@Component
public class PathReadiness {
    private final LessonVersionRepository versions;
    private final ObjectMapper mapper;

    public PathReadiness(LessonVersionRepository versions, ObjectMapper mapper) {
        this.versions = versions;
        this.mapper = mapper;
    }

    public Map<UUID, LessonVersion> snapshots(Iterable<Lesson> lessons) {
        Set<UUID> ids = new HashSet<>();
        lessons.forEach(l -> { if (l.getCurrentVersionId() != null) ids.add(l.getCurrentVersionId()); });
        return versions.findAllById(ids).stream().collect(Collectors.toMap(LessonVersion::getId, Function.identity()));
    }

    /** Optional policy lessons remain valid without being attached to the path. */
    public void includePolicyLessons(Map<UUID, Lesson> lessons, Iterable<EventCompletionPolicy> policies,
                                    LessonRepository repository) {
        Set<UUID> referenced = new HashSet<>();
        for (EventCompletionPolicy policy : policies) {
            try {
                referenced.addAll(policyIds(policy.getRequiredLessonIdsJson()));
                referenced.addAll(policyIds(policy.getOptionalLessonIdsJson()));
            } catch (SnapshotCorruptException ex) {
                // status() reports malformed policies as CONTENT_REVIEW_REQUIRED.
            }
        }
        referenced.removeAll(lessons.keySet());
        if (!referenced.isEmpty()) repository.findAllById(referenced).forEach(lesson -> lessons.put(lesson.getId(), lesson));
    }

    public boolean published(Lesson lesson, Map<UUID, LessonVersion> snapshots) {
        if (lesson == null || lesson.getStatus() != LessonStatus.PUBLISHED || lesson.getCurrentVersionId() == null) return false;
        LessonVersion snapshot = snapshots.get(lesson.getCurrentVersionId());
        return snapshot != null && lesson.getId().equals(snapshot.getLessonId());
    }

    public PathContentStatus status(UUID eventId, Set<UUID> attached, EventCompletionPolicy policy,
            Map<UUID, Lesson> lessons, Map<UUID, LessonVersion> snapshots) {
        boolean hasPublished = attached.stream().map(lessons::get)
                .anyMatch(l -> l != null && eventId.equals(l.getEventId()) && published(l, snapshots));
        if (!hasPublished) return PathContentStatus.NO_PUBLISHED_LESSON;
        if (policy == null) return PathContentStatus.NO_COMPLETION_POLICY;
        if (!eventId.equals(policy.getEventId()) || policy.getStatus() != EventCompletionPolicy.Status.PUBLISHED) {
            return PathContentStatus.CONTENT_REVIEW_REQUIRED;
        }
        try {
            List<UUID> required = policyIds(policy.getRequiredLessonIdsJson());
            List<UUID> optional = policyIds(policy.getOptionalLessonIdsJson());
            Set<UUID> requiredSet = new HashSet<>(required);
            Set<UUID> optionalSet = new HashSet<>(optional);
            if (required.isEmpty() || requiredSet.size() != required.size() || optionalSet.size() != optional.size()
                    || requiredSet.stream().anyMatch(optionalSet::contains)
                    || (policy.getMasteryThreshold() != null && (policy.getMasteryThreshold() < 0 || policy.getMasteryThreshold() > 100))) {
                return PathContentStatus.CONTENT_REVIEW_REQUIRED;
            }
            for (UUID id : required) {
                Lesson lesson = lessons.get(id);
                if (!attached.contains(id) || lesson == null || !eventId.equals(lesson.getEventId()) || !published(lesson, snapshots)) {
                    return PathContentStatus.CONTENT_REVIEW_REQUIRED;
                }
            }
            for (UUID id : optional) {
                Lesson lesson = lessons.get(id);
                if (lesson == null || !eventId.equals(lesson.getEventId()) || !published(lesson, snapshots)) {
                    return PathContentStatus.CONTENT_REVIEW_REQUIRED;
                }
            }
            return PathContentStatus.PLAYABLE;
        } catch (SnapshotCorruptException ex) {
            return PathContentStatus.CONTENT_REVIEW_REQUIRED;
        }
    }

    public List<UUID> policyIds(String json) {
        try {
            JsonNode root = mapper.readTree(json);
            if (root == null || !root.isArray()) throw new IllegalArgumentException("Expected UUID array");
            java.util.ArrayList<UUID> ids = new java.util.ArrayList<>();
            for (JsonNode value : root) {
                if (!value.isTextual()) throw new IllegalArgumentException("Expected UUID string");
                UUID id = UUID.fromString(value.textValue());
                if (!id.toString().equalsIgnoreCase(value.textValue())) throw new IllegalArgumentException("Expected canonical UUID");
                ids.add(id);
            }
            return ids;
        } catch (Exception ex) {
            throw new SnapshotCorruptException("Invalid completion policy lesson IDs");
        }
    }
}
