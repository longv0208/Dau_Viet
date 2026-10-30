package com.dauviet.path.application;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.domain.LearningPathEventNode;
import com.dauviet.path.domain.LearningPathExceptions.PathNodeInvalidParentException;
import com.dauviet.path.domain.PathNodeType;
import com.dauviet.path.infrastructure.persistence.LearningPathChapterRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathEventNodeRepository;

/**
 * Validates the learning path hierarchy invariant:
 * {@code ERA -> PERIOD -> PHASE -> EVENT -> LESSON}.
 */
@Component
public class PathHierarchyValidator {

    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository eventNodes;

    public PathHierarchyValidator(LearningPathChapterRepository chapters,
                                  LearningPathEventNodeRepository eventNodes) {
        this.chapters = chapters;
        this.eventNodes = eventNodes;
    }

    public PathNodeType parseNodeType(String raw) {
        if (raw == null || raw.isBlank()) {
            return PathNodeType.PERIOD;
        }
        try {
            return PathNodeType.valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new PathNodeInvalidParentException("Invalid nodeType: " + raw);
        }
    }

    public void validateParentAssignment(UUID versionId, UUID nodeId,
                                         UUID parentId, PathNodeType nodeType) {
        PathNodeType effectiveType = nodeType != null ? nodeType : PathNodeType.PERIOD;
        if (nodeId != null && nodeId.equals(parentId)) {
            throw new PathNodeInvalidParentException("A chapter node cannot be its own parent");
        }
        if (effectiveType == PathNodeType.ERA) {
            if (parentId != null) {
                throw new PathNodeInvalidParentException("ERA node cannot have a parentId");
            }
            if (nodeId != null) {
                boolean hasEvents = eventNodes.findByPathVersionIdOrderBySortOrderAsc(versionId)
                        .stream().anyMatch(e -> nodeId.equals(e.getChapterId()));
                if (hasEvents) {
                    throw new PathNodeInvalidParentException(
                            "Cannot change node to ERA while events are directly attached to it");
                }
            }
            return;
        }

        if (effectiveType == PathNodeType.PERIOD) {
            if (parentId == null) {
                return; // Backward-compatible root PERIOD
            }
            LearningPathChapter parent = chapters.findById(parentId)
                    .filter(c -> versionId.equals(c.getPathVersionId()))
                    .orElseThrow(() -> new PathNodeInvalidParentException(
                            "Parent chapter not found in the same path version: " + parentId));
            if (parent.getNodeType() != PathNodeType.ERA) {
                throw new PathNodeInvalidParentException(
                        "PERIOD node parent must be an ERA node (found " + parent.getNodeType() + ")");
            }
            assertNoCycle(versionId, nodeId, parentId);
            return;
        }

        if (effectiveType == PathNodeType.PHASE) {
            if (parentId == null) {
                throw new PathNodeInvalidParentException("PHASE node must have a PERIOD parentId");
            }
            LearningPathChapter parent = chapters.findById(parentId)
                    .filter(c -> versionId.equals(c.getPathVersionId()))
                    .orElseThrow(() -> new PathNodeInvalidParentException(
                            "Parent chapter not found in the same path version: " + parentId));
            if (parent.getNodeType() != PathNodeType.PERIOD) {
                throw new PathNodeInvalidParentException(
                        "PHASE node parent must be a PERIOD node (found " + parent.getNodeType() + ")");
            }
            if (nodeId != null && chapters.existsByPathVersionIdAndParentId(versionId, nodeId)) {
                throw new PathNodeInvalidParentException(
                        "PHASE node cannot have child chapter nodes");
            }
            assertNoCycle(versionId, nodeId, parentId);
        }
    }

    public void validateEventAttachmentChapter(LearningPathChapter chapter) {
        if (chapter.getNodeType() == PathNodeType.ERA) {
            throw new PathNodeInvalidParentException(
                    "Events cannot be attached directly to an ERA node; attach to a PERIOD or PHASE node instead");
        }
    }

    public void validateCanDeleteChapter(UUID versionId, UUID chapterId) {
        if (chapters.existsByPathVersionIdAndParentId(versionId, chapterId)) {
            throw new PathNodeInvalidParentException(
                    "Cannot delete chapter node because it still has child nodes");
        }
    }

    public List<String> collectHierarchyAuditErrors(List<LearningPathChapter> chapterList,
                                                    List<LearningPathEventNode> nodeList) {
        Map<UUID, LearningPathChapter> byId = new HashMap<>();
        for (LearningPathChapter ch : chapterList) {
            byId.put(ch.getId(), ch);
        }
        List<String> errors = new java.util.ArrayList<>();
        for (LearningPathChapter ch : chapterList) {
            PathNodeType type = ch.getNodeType();
            UUID parentId = ch.getParentId();
            if (type == PathNodeType.ERA && parentId != null) {
                errors.add("Đại thời kỳ (ERA) «" + ch.getTitle() + "» (" + ch.getCode() + ") là cấp gốc nên không được phép có đơn vị cha.");
            } else if (type == PathNodeType.PERIOD && parentId != null) {
                LearningPathChapter p = byId.get(parentId);
                if (p == null || p.getNodeType() != PathNodeType.ERA) {
                    errors.add("Thời kỳ (PERIOD) «" + ch.getTitle() + "» (" + ch.getCode() + ") phải trực thuộc một Đại thời kỳ (ERA) trong cùng phiên bản lộ trình.");
                }
            } else if (type == PathNodeType.PHASE) {
                LearningPathChapter p = parentId == null ? null : byId.get(parentId);
                if (p == null || p.getNodeType() != PathNodeType.PERIOD) {
                    errors.add("Giai đoạn con (PHASE) «" + ch.getTitle() + "» (" + ch.getCode() + ") bắt buộc phải trực thuộc một Thời kỳ (PERIOD) trong cùng phiên bản lộ trình.");
                }
            }
            // Cycle check
            Set<UUID> visited = new HashSet<>();
            UUID cursor = ch.getId();
            while (cursor != null) {
                if (!visited.add(cursor)) {
                    errors.add("Phát hiện vòng lặp phân cấp cha–con không hợp lệ tại chương «" + ch.getTitle() + "» (" + ch.getCode() + ").");
                    break;
                }
                LearningPathChapter current = byId.get(cursor);
                cursor = current == null ? null : current.getParentId();
            }
        }
        for (LearningPathEventNode ev : nodeList) {
            LearningPathChapter ch = byId.get(ev.getChapterId());
            if (ch != null && ch.getNodeType() == PathNodeType.ERA) {
                errors.add("Không thể gắn trực tiếp sự kiện vào Đại thời kỳ (ERA) «" + ch.getTitle() + "» (" + ch.getCode() + ") — vui lòng gắn vào Thời kỳ (PERIOD) hoặc Giai đoạn (PHASE).");
            }
        }
        return errors;
    }

    private void assertNoCycle(UUID versionId, UUID nodeId, UUID newParentId) {
        if (nodeId == null || newParentId == null) {
            return;
        }
        Map<UUID, UUID> parentMap = new HashMap<>();
        for (LearningPathChapter c : chapters.findByPathVersionIdOrderBySortOrderAsc(versionId)) {
            if (c.getParentId() != null) {
                parentMap.put(c.getId(), c.getParentId());
            }
        }
        parentMap.put(nodeId, newParentId);
        Set<UUID> visited = new HashSet<>();
        UUID cur = nodeId;
        while (cur != null) {
            if (!visited.add(cur)) {
                throw new PathNodeInvalidParentException("Cycle detected in chapter hierarchy");
            }
            cur = parentMap.get(cur);
        }
    }
}
