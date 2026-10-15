package com.dauviet.lesson.domain;

/** Evidence lifecycle: DRAFT → APPROVED → ARCHIVED (DRAFT → ARCHIVED also allowed). */
public enum EvidenceStatus {
    DRAFT,
    APPROVED,
    ARCHIVED
}
