package com.dauviet.path.application;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.path.api.dto.PathAuditReport;
import com.dauviet.path.api.dto.PathAuditReport.AuditIssue;
import com.dauviet.path.api.dto.PathAuditReport.DuplicateAliasReport;
import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.domain.LearningPathEventNode;
import com.dauviet.path.domain.LearningPathExceptions.PathNotFoundException;
import com.dauviet.path.domain.LearningPathExceptions.PathValidationException;
import com.dauviet.path.domain.LearningPathLessonNode;
import com.dauviet.path.domain.LearningPathStatus;
import com.dauviet.path.domain.LearningPathVersion;
import com.dauviet.path.infrastructure.persistence.LearningPathChapterRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathEventNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathLessonNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathVersionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Bộ kiểm tra tính nhất quán và kiểm toán dữ liệu lộ trình học (PATH-01 §7).
 */
@Component
public class LearningPathValidator {

    private static final Logger log = LoggerFactory.getLogger(LearningPathValidator.class);

    /** Các cặp alias lịch sử đã biết trong dữ liệu seed cần phát hiện */
    private static final Map<String, String> KNOWN_ALIASES = Map.of(
            "hai-ba-trung-40", "khoi-nghia-hai-ba-trung-40",
            "khoi-nghia-hai-ba-trung-40", "hai-ba-trung-40",
            "ly-thai-to-1010", "history-thang-long-1010",
            "history-thang-long-1010", "ly-thai-to-1010"
    );

    private final LearningPathVersionRepository versionRepo;
    private final LearningPathChapterRepository chapterRepo;
    private final LearningPathEventNodeRepository eventNodeRepo;
    private final LearningPathLessonNodeRepository lessonNodeRepo;
    private final HistoricalEventRepository historicalEventRepo;
    private final LessonRepository lessonRepo;
    private final EventCompletionPolicyRepository policyRepo;
    private final ObjectMapper mapper;

    public LearningPathValidator(LearningPathVersionRepository versionRepo,
                                 LearningPathChapterRepository chapterRepo,
                                 LearningPathEventNodeRepository eventNodeRepo,
                                 LearningPathLessonNodeRepository lessonNodeRepo,
                                 HistoricalEventRepository historicalEventRepo,
                                 LessonRepository lessonRepo,
                                 EventCompletionPolicyRepository policyRepo,
                                 ObjectMapper mapper) {
        this.versionRepo = versionRepo;
        this.chapterRepo = chapterRepo;
        this.eventNodeRepo = eventNodeRepo;
        this.lessonNodeRepo = lessonNodeRepo;
        this.historicalEventRepo = historicalEventRepo;
        this.lessonRepo = lessonRepo;
        this.policyRepo = policyRepo;
        this.mapper = mapper;
    }

    /**
     * Kiểm toán toàn diện một phiên bản lộ trình học tập và tạo báo cáo chuẩn.
     */
    public PathAuditReport audit(String pathCode, Integer versionNo) {
        LearningPathVersion version;
        if (versionNo != null) {
            version = versionRepo.findByPathCodeAndVersionNo(pathCode, versionNo)
                    .orElseThrow(() -> new PathNotFoundException(pathCode + " v" + versionNo));
        } else {
            version = versionRepo.findByPathCodeAndStatus(pathCode, LearningPathStatus.PUBLISHED)
                    .orElseThrow(() -> new PathNotFoundException(pathCode));
        }

        List<AuditIssue> issues = new ArrayList<>();
        List<DuplicateAliasReport> duplicateAliases = new ArrayList<>();
        List<String> emptyChapters = new ArrayList<>();
        Map<String, Long> statusCounts = new HashMap<>();

        List<LearningPathChapter> chapters = chapterRepo.findByPathVersionIdOrderBySortOrderAsc(version.getId());
        List<LearningPathEventNode> eventNodes = eventNodeRepo.findByPathVersionIdOrderBySortOrderAsc(version.getId());

        List<UUID> eventIds = eventNodes.stream().map(LearningPathEventNode::getEventId).distinct().toList();
        Map<UUID, HistoricalEvent> eventsMap = historicalEventRepo.findAllById(eventIds).stream()
                .collect(Collectors.toMap(HistoricalEvent::getId, Function.identity()));

        List<UUID> eventNodeIds = eventNodes.stream().map(LearningPathEventNode::getId).toList();
        List<LearningPathLessonNode> lessonNodes = eventNodeIds.isEmpty()
                ? Collections.emptyList()
                : lessonNodeRepo.findByEventNodeIdInOrderBySortOrderAsc(eventNodeIds);

        List<UUID> lessonIds = lessonNodes.stream().map(LearningPathLessonNode::getLessonId).distinct().toList();
        Map<UUID, Lesson> lessonsMap = lessonRepo.findAllById(lessonIds).stream()
                .collect(Collectors.toMap(Lesson::getId, Function.identity()));

        Map<UUID, EventCompletionPolicy> policiesMap = eventIds.isEmpty()
                ? Collections.emptyMap()
                : policyRepo.findPublishedByEventIdIn(eventIds).stream()
                        .collect(Collectors.toMap(EventCompletionPolicy::getEventId, Function.identity(), (p1, p2) -> p1));

        // 1. Kiểm tra Chapters
        Set<String> chapterCodes = new HashSet<>();
        Set<Integer> chapterSortOrders = new HashSet<>();
        for (LearningPathChapter c : chapters) {
            if (!chapterCodes.add(c.getCode())) {
                issues.add(new AuditIssue("ERROR", "DUPLICATE_CHAPTER_CODE", "Duplicate chapter code: " + c.getCode(), c.getId()));
            }
            if (!chapterSortOrders.add(c.getSortOrder())) {
                issues.add(new AuditIssue("ERROR", "DUPLICATE_CHAPTER_SORT", "Duplicate chapter sort_order: " + c.getSortOrder(), c.getId()));
            }
            if (c.getStartYear() > c.getEndYear()) {
                issues.add(new AuditIssue("ERROR", "INVALID_CHAPTER_YEARS", "startYear " + c.getStartYear() + " > endYear " + c.getEndYear(), c.getId()));
            }
        }

        // 2. Nhóm nodes theo chapter
        Map<UUID, List<LearningPathEventNode>> nodesByChapter = eventNodes.stream()
                .collect(Collectors.groupingBy(LearningPathEventNode::getChapterId));

        Map<UUID, List<LearningPathLessonNode>> lessonsByNode = lessonNodes.stream()
                .collect(Collectors.groupingBy(LearningPathLessonNode::getEventNodeId));

        Set<UUID> seenEventIds = new HashSet<>();
        Set<String> seenSlugs = new HashSet<>();

        for (LearningPathChapter chapter : chapters) {
            List<LearningPathEventNode> chapterNodes = nodesByChapter.getOrDefault(chapter.getId(), Collections.emptyList());
            if (chapterNodes.isEmpty()) {
                emptyChapters.add(chapter.getCode());
                issues.add(new AuditIssue("WARNING", "EMPTY_CHAPTER", "Chapter has 0 events: " + chapter.getTitle(), chapter.getId()));
                continue;
            }

            Set<Integer> nodeSortOrders = new HashSet<>();
            for (LearningPathEventNode node : chapterNodes) {
                if (!nodeSortOrders.add(node.getSortOrder())) {
                    issues.add(new AuditIssue("ERROR", "DUPLICATE_EVENT_SORT", "Duplicate event sort_order in chapter " + chapter.getCode() + ": " + node.getSortOrder(), node.getId()));
                }

                if (!seenEventIds.add(node.getEventId())) {
                    issues.add(new AuditIssue("ERROR", "DUPLICATE_EVENT_IN_PATH", "Event repeated in path: " + node.getEventId(), node.getId()));
                }

                HistoricalEvent event = eventsMap.get(node.getEventId());
                if (event == null) {
                    issues.add(new AuditIssue("ERROR", "EVENT_NOT_FOUND", "Event missing: " + node.getEventId(), node.getId()));
                    continue;
                }

                // Check alias trùng
                String slug = event.getSlug();
                seenSlugs.add(slug);
                String potentialAlias = KNOWN_ALIASES.get(slug);
                if (potentialAlias != null && seenSlugs.contains(potentialAlias)) {
                    issues.add(new AuditIssue("ERROR", "DUPLICATE_HISTORICAL_ALIAS", "Both alias and canonical event appeared in path: " + slug + " and " + potentialAlias, node.getId()));
                    duplicateAliases.add(new DuplicateAliasReport(slug, event.getId(), potentialAlias, null, "Trùng sự kiện lịch sử qua 2 alias"));
                }

                List<LearningPathLessonNode> nodeLessons = lessonsByNode.getOrDefault(node.getId(), Collections.emptyList());
                Set<Integer> lessonSortOrders = new HashSet<>();
                Set<UUID> nodeLessonIds = new HashSet<>();

                int publishedCount = 0;
                for (LearningPathLessonNode lNode : nodeLessons) {
                    if (!lessonSortOrders.add(lNode.getSortOrder())) {
                        issues.add(new AuditIssue("ERROR", "DUPLICATE_LESSON_SORT", "Duplicate lesson sort in event " + slug + ": " + lNode.getSortOrder(), lNode.getId()));
                    }
                    if (!nodeLessonIds.add(lNode.getLessonId())) {
                        issues.add(new AuditIssue("ERROR", "DUPLICATE_LESSON_IN_EVENT", "Duplicate lesson in event " + slug + ": " + lNode.getLessonId(), lNode.getId()));
                    }

                    Lesson lesson = lessonsMap.get(lNode.getLessonId());
                    if (lesson == null) {
                        issues.add(new AuditIssue("ERROR", "LESSON_NOT_FOUND", "Lesson missing: " + lNode.getLessonId(), lNode.getId()));
                        continue;
                    }
                    if (!lesson.getEventId().equals(node.getEventId())) {
                        issues.add(new AuditIssue("ERROR", "LESSON_EVENT_MISMATCH", "Lesson belongs to event " + lesson.getEventId() + " but attached to " + node.getEventId(), lNode.getId()));
                    }
                    if (lesson.getStatus() == LessonStatus.PUBLISHED) {
                        publishedCount++;
                    } else {
                        issues.add(new AuditIssue("WARNING", "UNPUBLISHED_LESSON_IN_PATH", "Lesson is " + lesson.getStatus() + ": " + lesson.getTitle(), lesson.getId()));
                    }
                }

                // Kiểm tra status
                EventCompletionPolicy policy = policiesMap.get(node.getEventId());
                String statusStr;
                if (publishedCount == 0) {
                    statusStr = "NO_PUBLISHED_LESSON";
                    issues.add(new AuditIssue("INFO", "NO_PUBLISHED_LESSON", "Event has no published lessons: " + event.getTitle(), event.getId()));
                } else if (policy == null) {
                    statusStr = "NO_COMPLETION_POLICY";
                    issues.add(new AuditIssue("WARNING", "NO_COMPLETION_POLICY", "Event has lessons but no published completion policy: " + event.getTitle(), event.getId()));
                } else {
                    List<UUID> reqIds = policy.requiredLessonIds(mapper);
                    if (reqIds == null || reqIds.isEmpty()) {
                        statusStr = "CONTENT_REVIEW_REQUIRED";
                        issues.add(new AuditIssue("ERROR", "EMPTY_POLICY_REQUIREMENT", "Policy has empty required lessons: " + event.getTitle(), policy.getId()));
                    } else if (!nodeLessonIds.containsAll(reqIds)) {
                        statusStr = "CONTENT_REVIEW_REQUIRED";
                        issues.add(new AuditIssue("ERROR", "POLICY_LESSON_UNSATISFIED", "Policy requires lessons not published/attached to event: " + reqIds, policy.getId()));
                    } else {
                        statusStr = "PLAYABLE";
                    }
                }
                statusCounts.put(statusStr, statusCounts.getOrDefault(statusStr, 0L) + 1);
            }
        }

        return new PathAuditReport(
                version.getPathCode(),
                version.getVersionNo(),
                version.getStatus().name(),
                chapters.size(),
                eventNodes.size(),
                lessonNodes.size(),
                statusCounts,
                issues,
                duplicateAliases,
                emptyChapters
        );
    }

    /**
     * Xác thực nghiêm ngặt trước publish: ném PathValidationException nếu có lỗi cấp ERROR.
     */
    public void validateForPublish(String pathCode, int versionNo) {
        PathAuditReport report = audit(pathCode, versionNo);
        List<String> errors = report.issues().stream()
                .filter(i -> "ERROR".equals(i.level()))
                .map(AuditIssue::message)
                .toList();

        if (!errors.isEmpty()) {
            throw new PathValidationException(errors);
        }
    }
}
