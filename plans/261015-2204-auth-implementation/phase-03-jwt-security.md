# Phase 03 — JWT security wiring

## Context Links

- `common/config/SecurityConfig.java` (current deny-by-default chain).
- `common/error/*` envelope. AC-8 (JWT, stateless, role gating), AC-3..7 (enablement).
- `application.yml`, `application-local.yml`.

## Overview

Add `spring-boot-starter-oauth2-resource-server`, symmetric HS256 `JwtEncoder`/`JwtDecoder` from `app.security.jwt-secret`, `JwtTokenService` impl minting access tokens (sub=user UUID, role claim), `JwtAuthenticationConverter` mapping `role` claim → `ROLE_*` authority, SecurityConfig update: permit `/api/v1/auth/**`, `hasRole("CONTENT_ADMIN")` on `/api/v1/admin/**`, `oauth2ResourceServer(jwt)` enabled. Provide `GET /api/v1/admin/ping` placeholder to prove gating.

## Requirements

- pom: add `org.springframework.boot:spring-boot-starter-oauth2-resource-server` (managed version).
- Config props `app.security.jwt-secret` (env `JWT_SECRET`, dev fallback documented — fail startup if missing outside local profile: simplest is `@ConfigurationProperties` with no default + local yml supplies dev value; document prod requirement in runbook).
- `app.security.access-token-ttl-seconds` default 900; `app.security.refresh-token-ttl-seconds` default 1209600.
- Access token claims: `sub`=userId, `role`=LEARNER|CONTENT_ADMIN, `iss`=`dau-viet-backend`, iat/exp.
- `JwtAuthenticationConverter`: read `role` claim → `new SimpleGrantedAuthority("ROLE_" + role)`; set as converter on `JwtAuthenticationToken` via `jwtAuthenticationConverter()` bean wired in `oauth2ResourceServer(oauth -> oauth.jwt(jwt -> jwt.jwtAuthenticationConverter(...)))`.
- Principal everywhere: `@AuthenticationPrincipal Jwt` → `jwt.getSubject()`.
- Admin placeholder: `GET /api/v1/admin/ping` → `{"status":"ok"}` under `admin/api/AdminPingController` (new tiny file; do NOT create admin module yet — acceptable: `common/api` no; pick `auth/api/AdminPingController`? Cleaner: top-level `com.dauviet.admin.api.AdminPingController` since admin module will grow — keep file <50 lines).
- Public matchers preserved: GET `/api/v1/events`, `/api/v1/events/*`, actuator health/info; add POST `/api/v1/auth/**`.
- 401 vs 403 already correct via existing entry point + access denied handler.

## Related Code Files

Create:
- `security/jwt/JwtTokenService.java` — `createAccessToken(User): String` (+ `getAccessTokenTtlSeconds()` for response).
- `security/jwt/JwtConfig.java` — `@Configuration` providing `JwtEncoder` (`NimbusJwtEncoder` w/ `ImmutableSecret<SecurityContext>`), `JwtDecoder` (`NimbusJwtDecoderBuilder.withSecretKey`), `JwtAuthenticationConverter` bean.
- `security/jwt/JwtSecurityProperties.java` OR reuse `auth/config/AuthProperties` — DECIDE: single `app.security` props class lives in `security/jwt/AuthProperties.java` is confusing; put `SecurityTokenProperties` under `security/jwt/` holding jwtSecret+accessTtl+refreshTtl; auth module injects it (cross-module read fine).
- `admin/api/AdminPingController.java` — `GET /api/v1/admin/ping` returns `Map.of("status","ok")`.

Modify:
- `pom.xml` — add resource-server starter.
- `common/config/SecurityConfig.java` — add `.requestMatchers(HttpMethod.POST,"/api/v1/auth/**").permitAll()`, `.requestMatchers("/api/v1/admin/**").hasRole("CONTENT_ADMIN")`, `.oauth2ResourceServer(oauth -> oauth.jwt(...))` with converter bean injected.
- `application.yml` — add `app.security.{jwt-secret: ${JWT_SECRET:}, access-token-ttl-seconds: 900, refresh-token-ttl-seconds: 1209600}` (empty secret default fails fast on missing env outside local — but empty string passes binding; add startup validation: `@PostConstruct` in JwtConfig asserts non-blank → throws IllegalStateException. Simpler: decoder bean build fails on empty key bytes anyway? Nimbus requires >=256-bit key → throws; acceptable, document).
- `application-local.yml` — add `app.security.jwt-secret: ${JWT_SECRET:local-dev-secret-change-me-32bytes-minimum-0123456789abcdef}` (>=256 bits HS256), keep env override.

## Implementation Steps

1. pom.xml: add `spring-boot-starter-oauth2-resource-server` after `spring-boot-starter-security`.
2. `SecurityTokenProperties` `@ConfigurationProperties(prefix="app.security")`: fields `jwtSecret`, `accessTokenTtlSeconds=900`, `refreshTokenTtlSeconds=1209600`; `@EnableConfigurationProperties` on JwtConfig.
3. `JwtConfig`: `@Bean JwtDecoder` from `SecretKeySpec(Base64 or UTF-8 bytes of jwtSecret, "HmacSHA256")`; `@Bean JwtEncoder` `new NimbusJwtEncoder(new ImmutableSecret<>(key))`; `@Bean JwtAuthenticationConverter` mapping `role` claim.
4. `JwtTokenService.createAccessToken(User)`: build `JwtClaimsSet` (issuer, issuedAt, expiresAt=now+ttl, subject=user.getId().toString(), claim "role"=user.getRole().name()), `JwsHeader.with(MacAlgorithm.HS256).build()`, `encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue()`.
5. SecurityConfig updates (matchers + oauth2ResourceServer). Inject `JwtAuthenticationConverter`.
6. `AdminPingController`.
7. application.yml + application-local.yml entries.
8. `mvnw -q test-compile`.
9. Note for executor: `HistoricalEventControllerTest` imports `SecurityConfig` in a `@WebMvcTest` slice — resource-server beans (`JwtDecoder`) won't exist in that slice and `oauth2ResourceServer` DSL may fail context load. Fix pattern: define jwt decoder/converter beans in `JwtConfig` (separate `@Configuration`) which is NOT imported by the slice test, so the filter chain's `jwt()` config resolves a `JwtDecoder` lazily only when needed — verify: if context fails, add `@MockitoBean JwtDecoder` to the slice test OR move `oauth2ResourceServer` config to reference beans via `applicationContext.getBean`. Flagged risk; simplest fallback = add `@MockitoBean JwtDecoder jwtDecoder` + `@MockitoBean JwtAuthenticationConverter` where needed in existing test (one-line change, keeps test semantics).

## Todo

- [ ] pom dep added
- [ ] SecurityTokenProperties bound to app.security
- [ ] JwtConfig beans (encoder/decoder/converter)
- [ ] JwtTokenService.createAccessToken
- [ ] SecurityConfig matchers + oauth2ResourceServer + admin hasRole
- [ ] AdminPingController
- [ ] application.yml + application-local.yml entries
- [ ] Existing slice tests still compile/load (fix via @MockitoBean if needed)
- [ ] test-compile green

## Success Criteria

- Bearer token minted/decoded symmetric-HS256; sub=UUID; role authority `ROLE_CONTENT_ADMIN` gates `/api/v1/admin/**` (403 for LEARNER, 401 unauthenticated).
- Public GET events still 200 without token.
- Secret only from env/local file; never logged.

## Security Considerations

- HS256 symmetric OK for monolith MVP; document RS256/asymmetric as future if services split.
- TTLs configurable; access 15min default.
- No token/password in logs — do not add log statements printing auth headers; keep `org.springframework.security` log at default INFO.

## Risk

- Slice tests + resource-server auto-config interplay (mitigation above).
- Secret length <32 bytes → Nimbus throws on decoder build; ensure local fallback ≥256 bits and document min length.
- Role claim missing → zero authorities → protected endpoints 403; acceptable (tokens always minted with role).
