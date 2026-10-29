package com.dauviet.auth.application;

import java.util.Locale;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.stereotype.Component;

import com.dauviet.auth.domain.GoogleTokenInvalidException;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;

/**
 * GoogleIdTokenVerifier-backed checker: validates the JWT signature against
 * Google's rotating certs plus iss/exp/aud (aud whitelist baked into the
 * builder). We additionally require a present, verified email — an
 * unverified Google email must not link or create a local account.
 */
@Component
@ConditionalOnBean(GoogleIdTokenVerifier.class)
public class GoogleTokenVerifierImpl implements GoogleTokenVerifier {

    private static final Logger log = LoggerFactory.getLogger(GoogleTokenVerifierImpl.class);

    private final GoogleIdTokenVerifier verifier;

    public GoogleTokenVerifierImpl(GoogleIdTokenVerifier verifier) {
        this.verifier = verifier;
    }

    @Override
    public VerifiedGoogleUser verify(String idToken) {
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
}
