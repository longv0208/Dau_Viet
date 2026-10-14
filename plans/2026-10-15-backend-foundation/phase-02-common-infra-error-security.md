# Phase 02 — common/ infrastructure: error contract, security foundation, CORS, actuator

## Context links
- Plan: [plan.md](plan.md)
- Coding rules: `docs/CODING_RULES.md` §3 (constructor injection, DTO/Entity split, error contract `{code,message,details,traceId}`)
- API rules: `docs/CODING_RULES.md` §6 (REST `/api/v1`, validation error codes)

## Overview
- **Priority:** P1 — required before any controller
- **Status:** completed
- **Effort:** 2h
- Build `com.dauviet.common` package providing unified error envelope, global exception handler, request traceId, minimal Spring Security config, and dev CORS policy.

## Key insights
- No JWT yet — permit public reads on `/api/v1/events/**` and actuator health; deny everything else with 401.
- `traceId` lets logs correlate; use SLF4J MDC via a `OncePerRequestFilter` that reuses inbound `X-Request-Id` if present.
- `details` is a `Map<String,Object>` (validation errors) or empty object; never leak stack traces.

## Requirements
- Error body shape (JSON, camelCase):
  ```json
  {
    "code": "EVENT_NOT_FOUND",
    "message": "Historical event not found",
    "details": {"id": "..."},
    "traceId": "01JXYZ..."
  }
  ```
- Error code catalog (this scope):
  - `VALIDATION_ERROR` (400) — Bean Validation or bad pagination params
  - `EVENT_NOT_FOUND` (404) — id not found or not visible
  - `MALFORMED_ID` (400) — path var not a UUID
  - `METHOD_NOT_ALLOWED` (405) — wrong verb on a known path
  - `UNAUTHORIZED` (401) — Spring Security default for non-public endpoints
  - `INTERNAL_ERROR` (500) — catch-all
- `TraceIdFilter` — sets MDC `traceId`, generates UUID if header `X-Request-Id` absent, echoes header in response.
- `GlobalExceptionHandler` (`@RestControllerAdvice`) handles:
  - `MethodArgumentNotValidException` → `VALIDATION_ERROR` with `details={field: message}`
  - `MethodArgumentTypeMismatchException` / `ConstraintViolationException` → `VALIDATION_ERROR`
  - `HttpRequestMethodNotSupportedException` → `METHOD_NOT_ALLOWED`
  - `ResourceNotFoundException` (custom) → `EVENT_NOT_FOUND` (or domain-specific subclass)
  - `Exception` → `INTERNAL_ERROR` (log full stack with traceId; return generic message)
- `SecurityConfig` (`@Configuration`):
  - `SecurityFilterChain` bean: `csrf.disable()` (stateless REST), `sessionManagement.stateless()`
  - `authorizeHttpRequests`: permit `GET /api/v1/events/**`, `GET /actuator/health`, `GET /actuator/info`; `anyRequest().authenticated()` (placeholder until JWT lands)
  - HTTP Basic disabled; `httpBasic().disable()`, `formLogin().disable()`
- `CorsConfig` — allowed origins `http://localhost:3000`, `http://localhost:5173`, `capacitor://localhost`, `http://localhost` (Flutter web dev); methods `GET,POST,PUT,PATCH,DELETE,OPTIONS`; headers `*`; `allowCredentials=true`; max-age 3600. Driven by `app.cors.allowed-origins` property in `application-local.yml`.
- Actuator exposure: only `health` and `info` (already in `application.yml`).

## Architecture

```
com.dauviet.common/
├── api/
│   ├── ApiError.java                  # record {code, message, details, traceId}
│   └── PageResponse.java              # generic {content,page,size,totalElements,totalPages}
├── error/
│   ├── GlobalExceptionHandler.java    # @RestControllerAdvice
│   ├── ErrorCode.java                 # enum of code strings
│   └── ResourceNotFoundException.java
├── trace/
│   └── TraceIdFilter.java             # OncePerRequestFilter + MDC
└── config/
    ├── SecurityConfig.java
    ├── CorsConfig.java
    └── CorsProperties.java            # @ConfigurationProperties("app.cors")
```

## Related code files
- Create: `src/main/java/com/dauviet/common/api/ApiError.java`
- Create: `src/main/java/com/dauviet/common/api/PageResponse.java`
- Create: `src/main/java/com/dauviet/common/error/ErrorCode.java`
- Create: `src/main/java/com/dauviet/common/error/ResourceNotFoundException.java`
- Create: `src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java`
- Create: `src/main/java/com/dauviet/common/trace/TraceIdFilter.java`
- Create: `src/main/java/com/dauviet/common/config/SecurityConfig.java`
- Create: `src/main/java/com/dauviet/common/config/CorsConfig.java`
- Create: `src/main/java/com/dauviet/common/config/CorsProperties.java`
- Modify: `src/main/resources/application.yml` (add `app.cors.allowed-origins` empty default)
- Modify: `src/main/resources/application-local.yml` (add dev origins list)

## Implementation steps
1. Create `ApiError` record with `(String code, String message, Map<String,Object> details, String traceId)`; Jackson auto-serializes.
2. Create `ErrorCode` enum with the six constants above; expose `String code()`.
3. Create `ResourceNotFoundException(String message)` — runtime exception; the handler translates it into `EVENT_NOT_FOUND` when thrown from historical-event service (use generic name so other modules reuse it via their own handler if needed — for now the handler inspects exception type and uses `EVENT_NOT_FOUND`).
4. Implement `TraceIdFilter`: extends `OncePerRequestFilter`, reads `X-Request-Id` (default UUID random), `MDC.put("traceId", id)`, adds `X-Request-Id` response header, clears MDC in `finally`. Register as a bean with order `HIGHEST_PRECEDENCE`.
5. Implement `GlobalExceptionHandler`: methods annotated `@ExceptionHandler` returning `ResponseEntity<ApiError>`; pull `traceId` from `MDC.get("traceId")`.
6. Implement `CorsProperties` + `CorsConfig` registering `CorsConfigurationSource` bean.
7. Implement `SecurityConfig` returning `SecurityFilterChain`; inject `CorsConfigurationSource`; disable CSRF/form-login/basic; permit list above.
8. Sanity test via `@WebMvcTest` against a dummy controller in phase-05.

## Todo checklist
- [ ] `ApiError` record serializes exactly `{code,message,details,traceId}`
- [ ] `GlobalExceptionHandler` covers validation, type-mismatch, method-not-allowed, not-found, generic
- [ ] `TraceIdFilter` generates + echoes `X-Request-Id`, populates MDC
- [ ] `SecurityConfig` permits `GET /api/v1/events/**` + actuator health/info, denies rest
- [ ] `CorsConfig` reads allowed origins from `app.cors.allowed-origins`
- [ ] No stack trace leaks in error body

## Success criteria
- Hitting any unmapped authenticated path returns 401 JSON with `code=UNAUTHORIZED`
- Sending `GET /api/v1/events/abc-not-a-uuid` returns 400 `MALFORMED_ID` with `traceId` set (verified in phase-05 tests)
- Response always has `X-Request-Id` header

## Risk assessment
- Spring Security's default `AuthenticationEntryPoint` returns non-JSON for unauthenticated; we add a small `CustomAuthenticationEntryPoint` that writes `ApiError` JSON — include it in `SecurityConfig`.
- `PageResponse` naming — keep fields `content,page,size,totalElements,totalPages` to mirror Spring `Page` (Flutter already familiar).

## Security considerations
- No JWT yet → all non-`events` GET endpoints effectively closed; this is the safe default.
- CORS `allowCredentials=true` requires explicit origins, not `*` — enforced by reading properties.
- Actuator exposes only health/info; do NOT expose `env`, `beans`, `heapdump`.

## Next steps
- Phase 03 — historical event domain + Flyway V1.
