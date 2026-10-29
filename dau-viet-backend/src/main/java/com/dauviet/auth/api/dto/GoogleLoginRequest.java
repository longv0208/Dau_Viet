package com.dauviet.auth.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Google Sign-In: raw idToken from the Google SDK. */
public record GoogleLoginRequest(
        @NotBlank @Size(max = 8192) String idToken
) {}
