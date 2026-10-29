# TASK-0021 handoff — Issue #34 OTP + Google auth

## Đã làm
- **V51 migration**: `users.password_hash` nullable; `auth_otp_challenges`; `user_oauth_accounts`.
- **Backend** (`com.dauviet.auth`): OTP lifecycle (`OtpService`, salted SHA-256 code_hash, max 5 attempts, TTL 300s, resend cooldown 60s), `OtpSender` (SMTP via MAIL_ENABLED=true / Logging fallback chỉ log code khi profile `local`), endpoints `/register`(202), `/register/verify`, `/otp/resend`, `/password/forgot`(luôn 200), `/password/reset`(+revoke all refresh tokens), `/google` (`GoogleIdTokenVerifier`, link-or-create, `GOOGLE_EMAIL_UNVERIFIED` khi email local chưa verified, `FEATURE_DISABLED` khi không cấu hình client-ids). Error codes mới trong `ErrorCode` + handlers.
- **Mobile**: `requestRegisterOtp`/`verifyRegisterOtp`/`resendOtp`/`forgotPassword`/`resetPassword`/`loginWithGoogle` trong AuthApiClient+AuthRepository+AuthSessionController; màn `OtpVerificationScreen` (6 số, countdown resend), `ForgotPasswordScreen`, `ResetPasswordScreen`; nút Quên mật khẩu + Tiếp tục với Google trên `AuthScreen` (`google_sign_in` + `googleSignInGatewayProvider` mockable); routes `/auth/forgot`, `/auth/otp`, `/auth/reset-password`.
- **Docs**: `API_SPEC.md`, `DATABASE_DESIGN.md`, `backend-runbook.md`, `project-changelog.md`.

## Verification đã chạy
- `mvnw compile`: pass (Java 21).
- `mvnw test` auth scope: **41/41 pass** — `OtpServiceTest` 11, `AuthServiceTest` 15, `GoogleAuthServiceTest` 7, `RefreshTokenServiceTest` 8.
- `mvnw test` full non-IT: **551 run / 550 pass**; fail duy nhất `DauVietApplicationTests` (context-load cần Testcontainers — Docker daemon off trên máy dev, pre-existing environment limit, giống TASK-0019).
- `flutter analyze lib/features/auth lib/app/router.dart`: clean (1 info pre-existing `unnecessary_underscores` ở `auth_screen.dart:176` — code cũ, không đụng).
- `flutter test test/auth/`: **29/29 pass**.
- `flutter test` full suite: 4 failures **pre-existing trên baseline** (đã verify bằng `git stash` + rerun): `lesson_player_test`, `lesson_player_energy_test` (2), `visual_storytelling_test` — không liên quan auth.

## Chưa verify (blockers)
- **Docker daemon off** → ITs không chạy: `AuthControllerIT` (đã viết lại đầy đủ cho contract OTP — 15 test cases gồm reset-revokes-refresh, cooldown 429, anti-enumeration), `AuthRefreshIT`, `FlywayMigrationIT` (V51 checksum/clean-DB). Cần `mvnw verify` khi Docker bật.
- **Google sign-in end-to-end trên thiết bị**: cần `GOOGLE_CLIENT_IDS` backend + `GOOGLE_SERVER_CLIENT_ID` dart-define mobile + OAuth client trong Google Cloud Console. `GoogleTokenVerifierImpl` chưa được IT (verifier bị mock trong unit test — token thật cần Google).
- **Email SMTP thật**: `SmtpOtpSender` chưa gửi mail thật; dev dùng `LoggingOtpSender` (profile `local` in mã ra log).

## Breaking change
`POST /api/v1/auth/register` không còn `201 profile` — giờ `202 OtpChallengeResponse`; user chỉ tồn tại sau `register/verify`. Mọi consumer phải qua OTP (mobile đã cập nhật). `AdminBootstrapRunner` insert trực tiếp DB nên không ảnh hưởng; lưu ý admin được bootstrap giờ nên có `email_verified_at` nếu muốn link Google sau này.

## Next action
1. Bật Docker → `mvnw verify -Dtest='AuthControllerIT,AuthRefreshIT,FlywayMigrationIT'` để xác nhận V51 + flows E2E.
2. Tạo OAuth client ids (Web + Android) trong Google Cloud Console → set `GOOGLE_CLIENT_IDS` backend, `--dart-define=GOOGLE_SERVER_CLIENT_ID` mobile; test đăng nhập Google thật trên emulator.
3. Cấu hình SMTP thật (`MAIL_*`) cho môi trường staging/prod.
