package com.dauviet.collection.domain;

/**
 * Không có mục collection nào cho (learner, evidenceId) — chưa collect,
 * hoặc cố đọc collection của learner khác → 404 (không phân biệt hai
 * trường hợp để tránh lộ tồn tại).
 */
public class CollectedEvidenceNotFoundException extends RuntimeException {

    public CollectedEvidenceNotFoundException(String message) {
        super(message);
    }
}
