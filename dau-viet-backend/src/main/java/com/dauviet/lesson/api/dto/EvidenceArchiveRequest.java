package com.dauviet.lesson.api.dto;

/**
 * Optional body for POST /admin/evidences/{id}/archive.
 * Empty body is allowed — expectedRowVersion may be omitted.
 */
public record EvidenceArchiveRequest(Long expectedRowVersion) {
}
