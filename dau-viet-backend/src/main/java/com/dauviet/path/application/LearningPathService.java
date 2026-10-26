package com.dauviet.path.application;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.path.api.dto.LearningPathResponse;
import com.dauviet.path.api.dto.LearningPathResponse.ChapterResponse;
import com.dauviet.path.api.dto.LearningPathResponse.EventNodeResponse;
import com.dauviet.path.api.dto.LearningPathResponse.LessonNodeResponse;
import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.domain.LearningPathEventNode;
import com.dauviet.path.domain.LearningPathExceptions.PathNotFoundException;
import com.dauviet.path.domain.LearningPathLessonNode;
import com.dauviet.path.domain.LearningPathStatus;
import com.dauviet.path.domain.LearningPathVersion;
import com.dauviet.path.domain.PathContentStatus;
import com.dauviet.path.infrastructure.persistence.LearningPathChapterRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathEventNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathLessonNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathVersionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Dịch vụ cung cấp dữ liệu lộ trình học tập Lịch sử Việt Nam chuẩn hóa (PATH-01).
 * Đảm bảo:
 * <ul>
 *   <li>Chỉ trả phiên bản PUBLISHED hiện hành.</li>
 *   <li>Thứ tự nhất quán: Chapter sort_order -> Event sort_order -> Lesson sort_order.</li>
 *   <li>Không phát sinh N+1 queries thông qua batch-loading.</li>
 *   <li>Không bao giờ trả private answer keys hoặc draft_json.</li>
 * </ul>
 */
@Service
public class LearningPathService {

    private static final Logger log = LoggerFactory.getLogger(LearningPathService.class);
    public static final String DEFAULT_PATH_CODE = "HISTORY_MAIN";

    private final LearningPathVersionRepository versionRepo;
    private final LearningPathChapterRepository chapterRepo;
    private final LearningPathEventNodeRepository eventNodeRepo;
    private final LearningPathLessonNodeRepository lessonNodeRepo;
    private final HistoricalEventRepository historicalEventRepo;
    private final LessonRepository lessonRepo;
    private final EventCompletionPolicyRepository policyRepo;
    private final ObjectMapper mapper;

    public LearningPathService(LearningPathVersionRepository versionRepo,
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
     * Lấy lộ trình đã xuất bản theo mã (mặc định HISTORY_MAIN).
     *
     * @param pathCode mã lộ trình, null hoặc rỗng -> HISTORY_MAIN
     * @return cấu trúc cây toàn vẹn: version -> chapters -> event nodes -> lesson nodes
     */
    @Transactional(readOnly = true)
    public LearningPathResponse getPublishedPath(String pathCode) {
        String effectiveCode = (pathCode == null || pathCode.isBlank()) ? DEFAULT_PATH_CODE : pathCode.trim();

        LearningPathVersion version = versionRepo.findByPathCodeAndStatus(effectiveCode, LearningPathStatus.PUBLISHED)
                .orElseThrow(() -> new PathNotFoundException(effectiveCode));

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

        Map<UUID, List<LearningPathEventNode>> eventNodesByChapter = eventNodes.stream()
                .collect(Collectors.groupingBy(LearningPathEventNode::getChapterId));

        Map<UUID, List<LearningPathLessonNode>> lessonNodesByEventNode = lessonNodes.stream()
                .collect(Collectors.groupingBy(LearningPathLessonNode::getEventNodeId));

        List<ChapterResponse> chapterResponses = new ArrayList<>();
        for (LearningPathChapter chapter : chapters) {
            List<LearningPathEventNode> chapterEventNodes = eventNodesByChapter.getOrDefault(chapter.getId(), Collections.emptyList());
            List<EventNodeResponse> eventResponses = new ArrayList<>();

            for (LearningPathEventNode eventNode : chapterEventNodes) {
                HistoricalEvent event = eventsMap.get(eventNode.getEventId());
                if (event == null || event.getStatus() != EventStatus.PUBLISHED) {
                    log.warn("Historical event {} is missing or not published (status={})",
                            eventNode.getEventId(), event != null ? event.getStatus() : "NOT_FOUND");
                    continue;
                }

                List<LearningPathLessonNode> nodeLessonNodes = lessonNodesByEventNode.getOrDefault(eventNode.getId(), Collections.emptyList());
                List<LessonNodeResponse> lessonResponses = new ArrayList<>();
                for (LearningPathLessonNode lNode : nodeLessonNodes) {
                    Lesson lesson = lessonsMap.get(lNode.getLessonId());
                    if (lesson == null || lesson.getStatus() != LessonStatus.PUBLISHED || lesson.getCurrentVersionId() == null) {
                        continue;
                    }
                    lessonResponses.add(new LessonNodeResponse(
                            lNode.getId(),
                            lesson.getId(),
                            lesson.getTitle(),
                            lNode.getSortOrder(),
                            lesson.getStatus().name()
                    ));
                }

                PathContentStatus contentStatus = determineContentStatus(eventNode.getEventId(), lessonResponses, policiesMap.get(event.getId()), lessonsMap);
                String yearLabel = YearLabelFormatter.formatYear(event.getStartYear(), event.getPeriod());

                eventResponses.add(new EventNodeResponse(
                        eventNode.getId(),
                        event.getId(),
                        event.getSlug(),
                        event.getTitle(),
                        event.getStartYear(),
                        yearLabel,
                        event.getPeriod(),
                        event.getCoverAssetKey(),
                        eventNode.getSortOrder(),
                        contentStatus,
                        lessonResponses
                ));
            }

            chapterResponses.add(new ChapterResponse(
                    chapter.getId(),
                    chapter.getCode(),
                    chapter.getTitle(),
                    chapter.getDescription(),
                    chapter.getStartYear(),
                    chapter.getEndYear(),
                    chapter.getPeriodLabel(),
                    chapter.getSortOrder(),
                    chapter.getThemeKey(),
                    eventResponses
            ));
        }

        return new LearningPathResponse(
                version.getPathCode(),
                version.getVersionNo(),
                version.getTitle(),
                version.getDescription(),
                chapterResponses
        );
    }

    /**
     * Xác định ContentStatus theo quy tắc nghiêm ngặt:
     * - NO_PUBLISHED_LESSON: 0 bài học công bố
     * - NO_COMPLETION_POLICY: có bài nhưng chưa có published policy
     * - CONTENT_REVIEW_REQUIRED: policy đòi hỏi bài không tồn tại / chưa công bố / không thuộc event
     * - PLAYABLE: có bài và policy hợp lệ
     */
    private PathContentStatus determineContentStatus(UUID eventId,
                                                    List<LessonNodeResponse> publishedLessons,
                                                    EventCompletionPolicy policy,
                                                    Map<UUID, Lesson> lessonsMap) {
        if (publishedLessons.isEmpty()) {
            return PathContentStatus.NO_PUBLISHED_LESSON;
        }

        if (policy == null) {
            return PathContentStatus.NO_COMPLETION_POLICY;
        }

        List<UUID> requiredIds = policy.requiredLessonIds(mapper);
        if (requiredIds == null || requiredIds.isEmpty()) {
            return PathContentStatus.CONTENT_REVIEW_REQUIRED;
        }

        Set<UUID> availableLessonIds = publishedLessons.stream()
                .map(LessonNodeResponse::lessonId)
                .collect(Collectors.toSet());

        if (!availableLessonIds.containsAll(requiredIds)) {
            return PathContentStatus.CONTENT_REVIEW_REQUIRED;
        }

        for (UUID reqLessonId : requiredIds) {
            Lesson reqLesson = lessonsMap.get(reqLessonId);
            if (reqLesson == null
                    || !eventId.equals(reqLesson.getEventId())
                    || reqLesson.getStatus() != LessonStatus.PUBLISHED
                    || reqLesson.getCurrentVersionId() == null) {
                return PathContentStatus.CONTENT_REVIEW_REQUIRED;
            }
        }

        return PathContentStatus.PLAYABLE;
    }
}
