package com.dauviet.historicalevent.domain;

/**
 * Publication lifecycle of a historical event.
 * Learners only ever see PUBLISHED rows; DRAFT/ARCHIVED are hidden (404).
 */
public enum EventStatus {
    DRAFT,
    PUBLISHED,
    ARCHIVED
}
