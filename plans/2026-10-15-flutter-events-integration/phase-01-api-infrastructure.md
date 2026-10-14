# Phase 01 — API infrastructure

## Context links

- `docs/backend-flutter-contract-notes.md` §1 (verified API shape), §3 decision 1 & 6
- `docs/API_SPEC.md` §2 events — error envelope `{code,message,details,traceId}` + `X-Request-Id`
- `dau-viet-mobile/pubspec.yaml` — needs `dio`
- `tasks/TASK-0005/handoff.md` — backend runs `localhost:8080`, seed under `local` profile

## Overview

- **Priority:** blocking (all later phases depend)
- **Status:** done
- **Effort:** Small
- **AC coverage:** AC-1 (Dio client, dart-define base URL, timeouts, typed errors, no infinite retry)

## Requirements

- Dio added to `pubspec.yaml` dependencies.
- `ApiConfig` reads `String.fromEnvironment('API_BASE_URL')`; default per platform:
  `Platform.isAndroid → http://10.0.2.2:8080`, else `http://localhost:8080`.
  Also expose `USE_MOCK` (`bool.fromEnvironment('USE_MOCK', defaultValue: false)`).
- `ApiClient` wraps a configured `Dio`: `connectTimeout`/`receiveTimeout`/`sendTimeout`
  (e.g. 10s/15s/10s), `Accept: application/json`, no automatic retry.
- `ApiError` typed model `{String code, String message, String? details, String? traceId}`
  with `fromJson` using explicit casts (`as String`, `as String?`, `as Map<String,dynamic>`).
- `ApiException implements Exception` carrying `ApiError` + `int? statusCode`; map
  `DioException` → `ApiException` (`badResponse` → parse envelope; timeout/connection
  → synthetic `NETWORK_ERROR`/`TIMEOUT` code). Helper `isNotFound`, `isUnauthorized`.
- No retry loop in client (explicit, single-attempt; UI retry button only).

## Related code files

**Create**
- `dau-viet-mobile/lib/core/api/api_config.dart`
- `dau-viet-mobile/lib/core/api/api_client.dart`
- `dau-viet-mobile/lib/core/api/api_error.dart`
- `dau-viet-mobile/lib/core/api/api_exception.dart`

**Modify**
- `dau-viet-mobile/pubspec.yaml` (+ `dio: ^5.x`)

## Implementation steps

1. Add `dio` to `pubspec.yaml` `dependencies:` (pin a stable `^5.x`); run `flutter pub get`.
2. Write `api_error.dart` — immutable model, `factory ApiError.fromJson(Map<String, dynamic> json)` with type-checked fields; `toString` includes `code` + `traceId`.
3. Write `api_exception.dart` — `ApiException(this.error, {this.statusCode})`; convenience predicates.
4. Write `api_config.dart` — `class ApiConfig { static String get baseUrl; static bool get useMock; }` reading `fromEnvironment`, with `Platform.isAndroid` default branch.
5. Write `api_client.dart` — `class ApiClient { ApiClient(this._dio) }`, factory `ApiClient.fromConfig(ApiConfig)` building `BaseOptions`, and `Future<Response<T>> get<T>(String path, {Map<String,dynamic>? query})` that wraps `DioException` into `ApiException`. Keep it thin — no business logic.
6. Keep each file <200 lines; kebab-case names already satisfied.

## Todo checklist

- [ ] `dio` in pubspec, `flutter pub get` green
- [ ] `api_error.dart` parses the real envelope incl. missing `details`/`traceId`
- [ ] `api_exception.dart` exposes `isNotFound`/`isUnauthorized`/status code
- [ ] `api_config.dart` resolves base URL per platform + `USE_MOCK`
- [ ] `api_client.dart` builds Dio with timeouts + envelope→exception mapping
- [ ] `flutter analyze` clean on new files

## Success criteria

- `ApiClient().get<Map<String,dynamic>>('/api/v1/events')` compiles and throws
  `ApiException` on `DioException`; unit test in phase 04 asserts mapping.
- No `dynamic` leaks: all JSON goes through `Map<String, dynamic>` + explicit `as`.

## Risks

- Dio version drift: pin `^5.x` compatible with Dart `^3.12.0` SDK; if `flutter pub get`
  resolves older Dart bounds, adjust the constraint.
- `Platform.isAndroid` can't be used in web builds; keep default safe for desktop/web.
