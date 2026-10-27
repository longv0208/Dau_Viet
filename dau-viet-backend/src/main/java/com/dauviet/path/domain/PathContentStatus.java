package com.dauviet.path.domain;

/**
 * Trạng thái nội dung của sự kiện trong lộ trình học (PATH-01).
 * Không phản ánh tiến trình cá nhân learner (LOCKED/CURRENT/COMPLETED thuộc PATH-03).
 */
public enum PathContentStatus {
    /** Có bài published hợp lệ và điều kiện hoàn thành cấu hình đủ. */
    PLAYABLE,
    /** Chưa có bài học công bố. */
    NO_PUBLISHED_LESSON,
    /** Có bài học công bố nhưng chưa có published completion policy. */
    NO_COMPLETION_POLICY,
    /** Dữ liệu liên kết bài/policy chưa nhất quán. */
    CONTENT_REVIEW_REQUIRED
}
