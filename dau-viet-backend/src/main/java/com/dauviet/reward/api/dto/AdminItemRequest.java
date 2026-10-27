package com.dauviet.reward.api.dto;

import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Tạo/cập nhật vật phẩm catalog phía admin (TASK-0023 — partial update).
 * Field null = "không đổi" trên UPDATE; create yêu cầu code/name/
 * category/itemType. `clearAsset=true` là cách xoá assetId có chủ đích;
 * `sourceMetadata:{}` (object rỗng) là cách xoá source metadata.
 */
public record AdminItemRequest(
        @NotBlank @Size(max = 80) String code,
        @NotBlank @Size(max = 160) String name,
        String description,
        @NotBlank @Size(max = 48) String category,
        @NotBlank @Size(max = 48) String itemType,
        @Size(max = 24) String rarity,
        UUID assetId,
        Boolean clearAsset,
        JsonNode sourceMetadata,
        Boolean active,
        Boolean placeable,
        @Size(max = 80) String renderKey
) {
}
