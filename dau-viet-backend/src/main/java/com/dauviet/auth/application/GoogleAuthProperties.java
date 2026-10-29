package com.dauviet.auth.application;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * `dauviet.auth.google.*` — OAuth client-id whitelist for Google idToken
 * `aud` verification (Issue #34). Empty list disables the /auth/google
 * endpoint (503 FEATURE_DISABLED).
 */
@ConfigurationProperties(prefix = "dauviet.auth.google")
public class GoogleAuthProperties {

    /**
     * Accepted `aud` values: Android/iOS/Web OAuth client ids, comma-separated
     * in GOOGLE_CLIENT_IDS. Spring binds "a,b,c" to List automatically.
     */
    private List<String> clientIds = List.of();

    public List<String> getClientIds() { return clientIds; }
    public void setClientIds(List<String> clientIds) {
        this.clientIds = clientIds == null ? List.of() : clientIds;
    }

    public boolean isConfigured() {
        return clientIds.stream().anyMatch(id -> id != null && !id.isBlank());
    }
}
