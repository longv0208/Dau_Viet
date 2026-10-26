package com.dauviet.island.api.dto;

/**
 * POST /api/v1/me/island/upgrade body (optional). expectedRevision null =
 * không kiểm concurrent.
 */
public record IslandUpgradeRequest(Long expectedRevision) {
}
