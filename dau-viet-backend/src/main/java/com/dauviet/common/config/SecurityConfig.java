package com.dauviet.common.config;

import java.io.IOException;
import java.util.Map;

import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.web.cors.CorsConfigurationSource;

import com.dauviet.common.api.ApiError;
import com.dauviet.common.error.ErrorCode;
import com.dauviet.common.trace.TraceIdFilter;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.servlet.http.HttpServletResponse;

/**
 * Foundation security config: stateless REST, public read access to published
 * events and health probes; everything else requires authentication (JWT
 * wired in a later task). CSRF disabled — no cookie-based session.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final JwtAuthenticationConverter jwtAuthenticationConverter;

    public SecurityConfig(JwtAuthenticationConverter jwtAuthenticationConverter) {
        this.jwtAuthenticationConverter = jwtAuthenticationConverter;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http,
            @Qualifier("corsConfigurationSource") CorsConfigurationSource corsSource) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsSource))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .httpBasic(basic -> basic.disable())
            .formLogin(form -> form.disable())
            .logout(logout -> logout.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(org.springframework.http.HttpMethod.GET,
                        "/api/v1/events", "/api/v1/events/*", "/api/v1/events/*/lessons",
                        "/api/v1/lessons", "/api/v1/lessons/*", "/api/v1/lessons/*/content").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.POST,
                        "/api/v1/auth/**").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("CONTENT_ADMIN")
                .requestMatchers("/actuator/health", "/actuator/health/**",
                        "/actuator/info").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth -> oauth
                .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter))
            )
            .exceptionHandling(eh -> eh
                .authenticationEntryPoint(unauthorizedEntryPoint())
                .accessDeniedHandler(accessDeniedHandler())
            );
        return http.build();
    }

    private AuthenticationEntryPoint unauthorizedEntryPoint() {
        return (request, response, ex) -> writeError(response, HttpStatus.UNAUTHORIZED,
                ErrorCode.UNAUTHORIZED, "Authentication required");
    }

    private AccessDeniedHandler accessDeniedHandler() {
        return (request, response, ex) -> writeError(response, HttpStatus.FORBIDDEN,
                ErrorCode.FORBIDDEN, "Access denied");
    }

    private void writeError(HttpServletResponse response, HttpStatus status,
                            ErrorCode code, String message) throws IOException {
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        String traceId = MDC.get(TraceIdFilter.MDC_KEY);
        ApiError body = ApiError.of(code.name(), message, Map.of(), traceId);
        objectMapper.writeValue(response.getWriter(), body);
    }
}
