package com.dauviet.lesson.api.dto;

import java.util.List;

import jakarta.validation.constraints.NotEmpty;

/** Full ordered-id list for an atomic reorder. */
public record OrderRequest(
        @NotEmpty List<String> orderedIds,
        Long expectedRowVersion) {
}
