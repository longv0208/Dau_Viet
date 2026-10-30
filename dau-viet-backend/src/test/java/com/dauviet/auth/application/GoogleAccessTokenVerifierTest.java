package com.dauviet.auth.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.io.IOException;
import java.net.http.HttpClient;
import java.net.http.HttpResponse;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.dauviet.auth.domain.GoogleTokenInvalidException;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;

/**
 * Issue #41 — the accessToken (Flutter Web) branch of
 * GoogleTokenVerifierImpl: tokeninfo response must have a whitelisted aud
 * and email_verified=true, anything else → GoogleTokenInvalidException.
 * The real GoogleIdTokenVerifier bean is unused on this branch so a mock
 * suffices.
 */
class GoogleAccessTokenVerifierTest {

    private final GoogleAuthProperties props = props("client-abc", "client-web");

    private static GoogleAuthProperties props(String... ids) {
        GoogleAuthProperties p = new GoogleAuthProperties();
        p.setClientIds(List.of(ids));
        return p;
    }

    @SuppressWarnings("unchecked")
    private static HttpClient stubHttp(int status, String body) throws Exception {
        HttpClient http = mock(HttpClient.class);
        HttpResponse<String> res = mock(HttpResponse.class);
        when(res.statusCode()).thenReturn(status);
        when(res.body()).thenReturn(body);
        when(http.send(any(), any(HttpResponse.BodyHandler.class))).thenReturn(res);
        return http;
    }

    private GoogleTokenVerifierImpl verifier(HttpClient http) {
        return new GoogleTokenVerifierImpl(mock(GoogleIdTokenVerifier.class), props, http);
    }

    @Test
    void validTokeninfo_verifiedEmail_whitelistedAud_returnsUser() throws Exception {
        String body = """
            {"aud":"client-web","sub":"g-123","email":"Web@Gmail.com",
             "email_verified":"true","name":"Web User","scope":"openid email profile"}
            """;
        GoogleTokenVerifierImpl v = verifier(stubHttp(200, body));
        GoogleTokenVerifier.VerifiedGoogleUser u = v.verify(null, "ya29.tok");
        assertThat(u.subject()).isEqualTo("g-123");
        assertThat(u.email()).isEqualTo("web@gmail.com");
        assertThat(u.displayName()).isEqualTo("Web User");
    }

    @Test
    void nonWhitelistedAud_rejected() throws Exception {
        String body = """
            {"aud":"other-app","sub":"g-1","email":"a@b.com","email_verified":"true"}
            """;
        GoogleTokenVerifierImpl v = verifier(stubHttp(200, body));
        assertThatThrownBy(() -> v.verify(null, "ya29.tok"))
            .isInstanceOf(GoogleTokenInvalidException.class);
    }

    @Test
    void unverifiedEmail_rejected() throws Exception {
        String body = """
            {"aud":"client-web","sub":"g-1","email":"a@b.com","email_verified":"false"}
            """;
        GoogleTokenVerifierImpl v = verifier(stubHttp(200, body));
        assertThatThrownBy(() -> v.verify(null, "ya29.tok"))
            .isInstanceOf(GoogleTokenInvalidException.class);
    }

    @Test
    void missingEmail_rejected() throws Exception {
        String body = """
            {"aud":"client-web","sub":"g-1","email_verified":"true"}
            """;
        GoogleTokenVerifierImpl v = verifier(stubHttp(200, body));
        assertThatThrownBy(() -> v.verify(null, "ya29.tok"))
            .isInstanceOf(GoogleTokenInvalidException.class);
    }

    @Test
    void tokeninfoNon200_rejected() throws Exception {
        GoogleTokenVerifierImpl v = verifier(stubHttp(400, "{}"));
        assertThatThrownBy(() -> v.verify(null, "ya29.bad"))
            .isInstanceOf(GoogleTokenInvalidException.class);
    }

    @Test
    void tokeninfoUnreachable_rejected() throws Exception {
        HttpClient http = mock(HttpClient.class);
        when(http.send(any(), any(HttpResponse.BodyHandler.class)))
            .thenThrow(new IOException("no route"));
        assertThatThrownBy(() -> verifier(http).verify(null, "ya29.tok"))
            .isInstanceOf(GoogleTokenInvalidException.class);
    }

    @Test
    void noCredential_rejected() {
        GoogleTokenVerifierImpl v =
            new GoogleTokenVerifierImpl(mock(GoogleIdTokenVerifier.class), props);
        assertThatThrownBy(() -> v.verify(null, null))
            .isInstanceOf(GoogleTokenInvalidException.class);
    }
}
