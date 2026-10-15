package com.dauviet.security.jwt;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Token/security settings under `app.security.*`.
 * jwtSecret must come from env (JWT_SECRET) outside local dev — HS256 needs
 * at least 256 bits (32 bytes). TTLs are seconds.
 */
@ConfigurationProperties(prefix = "app.security")
public class SecurityTokenProperties {

    /** HMAC secret for signing/verifying JWTs. Never logged. */
    private String jwtSecret = "";

    /** Access-token lifetime in seconds (default 15 minutes). */
    private long accessTokenTtlSeconds = 900;

    /** Refresh-token lifetime in seconds (default 14 days). */
    private long refreshTokenTtlSeconds = 1209600;

    public String getJwtSecret() { return jwtSecret; }
    public void setJwtSecret(String jwtSecret) { this.jwtSecret = jwtSecret == null ? "" : jwtSecret; }

    public long getAccessTokenTtlSeconds() { return accessTokenTtlSeconds; }
    public void setAccessTokenTtlSeconds(long accessTokenTtlSeconds) { this.accessTokenTtlSeconds = accessTokenTtlSeconds; }

    public long getRefreshTokenTtlSeconds() { return refreshTokenTtlSeconds; }
    public void setRefreshTokenTtlSeconds(long refreshTokenTtlSeconds) { this.refreshTokenTtlSeconds = refreshTokenTtlSeconds; }
}
