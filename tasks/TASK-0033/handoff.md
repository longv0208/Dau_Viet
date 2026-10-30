# TASK-0033 handoff — Issue #41 Google Sign-In Web/Mobile + console 401/404

## Đã làm

- **Mobile `google_sign_in_provider.dart`** — `GoogleSignInGateway.signIn()` trả `({idToken, accessToken})`. `kIsWeb`: `GoogleSignIn(clientId: GOOGLE_WEB_CLIENT_ID || GOOGLE_CLIENT_ID)` — không `serverClientId` (plugin web assert-fail). Android/iOS giữ `GOOGLE_SERVER_CLIENT_ID`. `GoogleSignInNotConfiguredException` → `AuthScreen` hiển thị message rõ.
- **`web/index.html`** — thêm `<meta name="google-signin-client_id" content="">` + hướng dẫn điền.
- **Auth chain** — `AuthApiClient.loginWithGoogle`, `AuthRepository.loginWithGoogle`, `AuthSessionController.loginWithGoogle`, `AuthScreen._loginWithGoogle` đều nhận `{idToken?, accessToken?}` và forward cả hai.
- **Backend** — `GoogleLoginRequest(idToken?, accessToken?)` (`@AssertTrue hasCredential`); `GoogleTokenVerifier.verify(idToken, accessToken)`; `GoogleTokenVerifierImpl.verifyAccessToken` → POST `https://oauth2.googleapis.com/tokeninfo`, yêu cầu `aud ∈ clientIds` + `email_verified=true` + `sub`/`email`; `application-local.yml` + `docs/backend-runbook.md` đã cập nhật.
- **401 spam** — `energyProvider`, `streakProvider`, `rewardSummaryProvider`, `inventoryCatalogProvider`, `inventoryItemsProvider`, `rewardTransactionsProvider` trả placeholder rỗng khi real-mode + `unauthenticated`/`guest` (không gọi repo). `unknown` (đang restore) vẫn fetch như cũ.
- **404 avatar** — `profile_screen` bỏ `frameAsset`/`dv_avatar_scholar.png` (không tồn tại) → `StampSealBadge` chữ cái đầu.

## Verify đã chạy

- `mvnw test -Dtest=GoogleAuthServiceTest,GoogleAccessTokenVerifierTest,AuthServiceTest` → **30/30 pass**.
- `flutter test` (toàn bộ) → **522/522 pass**.
- `flutter analyze` → 9 issues, tất cả pre-existing `island/*`.
- `git diff --check` clean; generated plugin files (linux/macos/windows) đã revert.

## Tests mới

- `GoogleAccessTokenVerifierTest` — 7 cases: tokeninfo hợp lệ, aud không whitelist, email unverified/missing, non-200, unreachable, no-credential.
- `GoogleAuthServiceTest.google_accessToken_newEmail_createsLearnerAndIssuesTokens`.
- `auth_repository_test` — accessToken forwarding; `energy_provider_test` — unauthenticated → repo không bị gọi.

## Chưa kiểm chứng được (thiếu prerequisite)

- Luồng Google Sign-In **thật** cần Web OAuth client id thật: set `GOOGLE_CLIENT_IDS` (backend) + `--dart-define=GOOGLE_WEB_CLIENT_ID` hoặc meta `content` trong `web/index.html` (mobile web). Không có credential nên E2E thật chưa chạy — user cần cấu hình rồi kiểm trên `localhost:4300`.
- GitNexus index availability không xác nhận — `impact`/`detect_changes` chưa chạy (gap, không chặn code).

## Next action

User điền Web OAuth client id (GCP) → `GOOGLE_CLIENT_IDS` + meta/dart-define → chạy app web thật kiểm chứng nút Google + console sạch. Chờ ủy quyền commit.
