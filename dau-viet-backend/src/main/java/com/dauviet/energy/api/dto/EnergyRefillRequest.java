package com.dauviet.energy.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Body POST /api/v1/me/energy/refills — learner chỉ gửi remedyCode;
 * mọi quyết định (eligible, price, gain, cooldown) từ server.
 */
public record EnergyRefillRequest(
        @NotBlank(message = "remedyCode is required")
        @Size(max = 64)
        String remedyCode) {
}
