package com.dauviet.island.api.dto;

import java.util.UUID;

/**
 * PUT /api/v1/me/island/placements/{slotId} body.
 * expectedRevision optional — client gửi user_islands.row_version đã đọc;
 * null/omit = không kiểm (chấp nhận ghi cuối).
 */
public record IslandPlacementRequest(
        UUID itemId,
        Long expectedRevision
) {
}
