# TASK-0033: Sửa Google Sign-In Flutter Web/Mobile + dọn 401/404 màn Đăng nhập

## Goal

Issue #41: nút "Tiếp tục với Google" báo lỗi chung trên Flutter Web (và có thể mobile) vì `serverClientId` không được hỗ trợ trên Web và Web chỉ trả `accessToken`; console spam `401` từ `/me/*` khi chưa đăng nhập; `404` asset `dv_avatar_scholar.png`.

## Acceptance criteria

- AC-1: không truyền `serverClientId` trên `kIsWeb`; gateway trả `idToken`+`accessToken`; meta `google-signin-client_id` trong `web/index.html`.
- AC-2: `POST /api/v1/auth/google` chấp nhận `idToken` hoặc `accessToken` (verify qua Google tokeninfo, kiểm aud + email_verified), auto create/link LEARNER, trả TokenResponse.
- AC-3: providers `/me/*` short-circuit khi `!auth.isAuthenticated` (real mode); avatar dùng fallback thay vì asset thiếu.
- AC-4: backend test accessToken path + mobile unit test gateway/providers.

## Scope

Theo `task.json`. Modules: mobile, backend. Risk: high (auth).

## Plan

1. Mobile: `GoogleSignInGateway` trả `({String? idToken, String? accessToken})`; `GoogleSignInGatewayImpl` dùng `clientId` trên web (`GOOGLE_WEB_CLIENT_ID`, fallback `GOOGLE_CLIENT_ID`), `serverClientId` trên mobile; thêm meta tag; `AuthApiClient`/`AuthRepository`/`AuthSessionController`/`AuthScreen` truyền cả hai field.
2. Backend: `GoogleLoginRequest` nhận `idToken?`/`accessToken?` (ít nhất một, `@AssertTrue`); `GoogleTokenVerifier.verify(idToken, accessToken)` — idToken qua `GoogleIdTokenVerifier`, accessToken qua `GoogleAccessTokenVerifier` gọi `oauth2/v3/tokeninfo` kiểm `aud` whitelist + `email_verified`; `application-local.yml` thêm `dauviet.auth.google.client-ids` comment; `docs/backend-runbook.md` ghi GOOGLE_CLIENT_IDS.
3. Dọn console: `energyProvider`/`streakProvider`/`rewardSummaryProvider` trả mặc định khi real-mode + `!isAuthenticated`; `refresh()` no-op khi anon; profile avatar bỏ asset thiếu → `StampSealBadge` fallback.
4. Tests: `GoogleAuthServiceTest` + `GoogleAccessTokenVerifierTest` (tokeninfo mocked), `AuthControllerIT` nếu có pattern; mobile `google_sign_in` gateway test + provider short-circuit test.
