package com.dauviet.auth.application;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Conditional;
import org.springframework.context.annotation.Configuration;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;

/**
 * Auth feature wiring (Issue #34). The GoogleIdTokenVerifier bean exists
 * only when the aud whitelist is non-empty — @ConditionalOnProperty can't
 * distinguish "set to empty string" from "set", so a dedicated Condition
 * checks the raw property. Its absence disables GoogleTokenVerifierImpl
 * and the endpoint reports FEATURE_DISABLED.
 */
@Configuration
@EnableConfigurationProperties({AuthOtpProperties.class, GoogleAuthProperties.class})
public class AuthInfrastructureConfig {

    @Bean
    @Conditional(GoogleClientIdsConfiguredCondition.class)
    public GoogleIdTokenVerifier googleIdTokenVerifier(GoogleAuthProperties props) {
        return new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), GsonFactory.getDefaultInstance())
                .setAudience(props.getClientIds())
                .build();
    }

    /**
     * Google credential checker (Issue #41). Moved here from a @Component
     * because @ConditionalOnBean on a component class can't see beans from
     * @Configuration classes (registered later) — the component always
     * registered without its dependency and failed instantiation.
     */
    @Bean
    @Conditional(GoogleClientIdsConfiguredCondition.class)
    public GoogleTokenVerifier googleTokenVerifier(GoogleIdTokenVerifier verifier,
                                                   GoogleAuthProperties props) {
        return new GoogleTokenVerifierImpl(verifier, props);
    }
}
