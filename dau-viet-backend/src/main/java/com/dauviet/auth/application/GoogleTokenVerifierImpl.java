package com.dauviet.auth.application;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.stereotype.Component;

import com.dauviet.auth.domain.GoogleTokenInvalidException;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.json.gson.GsonFactory;

/**
 * Google credential checker (Issue #41):
 *  - idToken → GoogleIdTokenVerifier: JWT signature against Google's rotating
 *    certs plus iss/exp/aud (aud whitelist baked into the builder).
 *  - accessToken → Google's oauth2/v3/tokeninfo endpoint, then the same
 *    policy as idToken: aud must be in the GOOGLE_CLIENT_IDS whitelist and
 *    email_verified must be true. Used on Flutter Web where the plugin's
 *    token client doesn't mint an idToken.
 * We always require a present, verified email — an unverified Google email
 * must not link or create a local account.
 */
@Component
@ConditionalOnBean(GoogleIdTokenVerifier.class)
public class GoogleTokenVerifierImpl implements GoogleTokenVerifier {

    private static final Logger log = LoggerFactory.getLogger(GoogleTokenVerifierImpl.class);
    private static final URI TOKENINFO =
        URI.create("https://oauth2.googleapis.com/tokeninfo");

    private final GoogleIdTokenVerifier verifier;
    private final GoogleAuthProperties props;
    private final HttpClient http;

    public GoogleTokenVerifierImpl(GoogleIdTokenVerifier verifier,
                                   GoogleAuthProperties props) {
        this(verifier, props,
             HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
    }

    /** Test seam — inject an HttpClient stub. */
    GoogleTokenVerifierImpl(GoogleIdTokenVerifier verifier,
                            GoogleAuthProperties props,
                            HttpClient http) {
        this.verifier = verifier;
        this.props = props;
        this.http = http;
    }

    @Override
    public VerifiedGoogleUser verify(String idToken, String accessToken) {
        if (idToken != null && !idToken.isBlank()) {
            return verifyIdToken(idToken);
        }
        if (accessToken != null && !accessToken.isBlank()) {
            return verifyAccessToken(accessToken);
        }
        throw new GoogleTokenInvalidException("no google credential supplied");
    }

    private VerifiedGoogleUser verifyIdToken(String idToken) {
        GoogleIdToken token;
        try {
            token = verifier.verify(idToken);
        } catch (Exception e) {
            throw new GoogleTokenInvalidException("google idToken verification failed", e);
        }
        if (token == null) {
            throw new GoogleTokenInvalidException("google idToken verification failed");
        }
        GoogleIdToken.Payload p = token.getPayload();
        String email = p.getEmail();
        if (email == null || email.isBlank() || !Boolean.TRUE.equals(p.getEmailVerified())) {
            log.warn("google token rejected: email present={} verified={}",
                    email != null, p.getEmailVerified());
            throw new GoogleTokenInvalidException("google email missing or unverified");
        }
        String name = p.get("name") instanceof String s && !s.isBlank() ? s : null;
        return new VerifiedGoogleUser(p.getSubject(),
                email.trim().toLowerCase(Locale.ROOT), name);
    }

    /**
     * Verify an OAuth2 access token via Google's tokeninfo endpoint. The
     * response carries `aud` + `email`/`email_verified` for tokens issued
     * with the openid/email/profile scopes — aud must match our client-id
     * whitelist so a token minted for some other app can't be replayed.
     */
    @SuppressWarnings("unchecked")
    private VerifiedGoogleUser verifyAccessToken(String accessToken) {
        HttpRequest req = HttpRequest.newBuilder(TOKENINFO)
            .timeout(Duration.ofSeconds(8))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .POST(HttpRequest.BodyPublishers.ofString(
                "access_token=" + URLEncoder.encode(accessToken, StandardCharsets.UTF_8)))
            .build();
        Map<String, Object> info;
        try {
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200) {
                log.warn("google tokeninfo rejected access token: status={}", res.statusCode());
                throw new GoogleTokenInvalidException("google accessToken verification failed");
            }
            info = GsonFactory.getDefaultInstance()
                .fromString(res.body(), Map.class);
        } catch (GoogleTokenInvalidException e) {
            throw e;
        } catch (IOException | InterruptedException e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            throw new GoogleTokenInvalidException("google tokeninfo unreachable", e);
        }

        Object aud = info.get("aud");
        List<String> allowed = props.getClientIds();
        if (!(aud instanceof String audStr) || !allowed.contains(audStr)) {
            log.warn("google accessToken rejected: aud not whitelisted");
            throw new GoogleTokenInvalidException("google accessToken aud not allowed");
        }
        Object verified = info.get("email_verified");
        boolean emailVerified = "true".equals(verified) || Boolean.TRUE.equals(verified);
        Object email = info.get("email");
        if (!(email instanceof String emailStr) || emailStr.isBlank() || !emailVerified) {
            log.warn("google accessToken rejected: email present={} verified={}",
                    email instanceof String, emailVerified);
            throw new GoogleTokenInvalidException("google email missing or unverified");
        }
        String name = info.get("name") instanceof String s && !s.isBlank() ? s : null;
        return new VerifiedGoogleUser(String.valueOf(info.get("sub")),
                emailStr.trim().toLowerCase(Locale.ROOT), name);
    }
}
