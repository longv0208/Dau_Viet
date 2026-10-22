package com.dauviet.reward.api.dto;

import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** Gán unlock rule cho item (MVP: một rule active mỗi item). */
public record AdminRuleRequest(
        @NotBlank @Size(max = 48) String ruleType,
        UUID lessonId,
        @Positive Integer threshold,
        Boolean active
) {
}
