package com.dauviet.lesson.domain;

/**
 * A published lesson_versions.snapshot_json row failed to parse — a
 * data-integrity defect. Surfaced as a 500 without internal details.
 */
public class SnapshotCorruptException extends RuntimeException {
    public SnapshotCorruptException(String message) {
        super(message);
    }
}
