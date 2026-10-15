package com.dauviet.learning.domain;

/** activity definition inside snapshot is malformed. */
public class SnapshotInvalidForActivityException extends RuntimeException {
    public SnapshotInvalidForActivityException(String message) {
        super(message);
    }
}