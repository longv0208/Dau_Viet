package com.dauviet.path.domain;

/**
 * Trạng thái phiên bản lộ trình học tập (PATH-01).
 * PUBLISHED là bất biến; thay đổi cấu trúc/thứ tự yêu cầu xuất bản version mới.
 */
public enum LearningPathStatus {
    DRAFT,
    PUBLISHED,
    ARCHIVED
}
