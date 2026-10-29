# TASK-0021 — Issue #34: Auth OTP + Google Sign-In

GitHub issue: https://github.com/longv0208/Dau_Viet/issues/34 (`[AUTH] Thêm chức năng Đăng nhập Google, Quên mật khẩu và Xác thực OTP`).

Ba luồng: (1) đăng ký xác thực OTP qua email, (2) quên/đặt lại mật khẩu bằng OTP + thu hồi refresh token cũ, (3) đăng nhập Google bằng idToken với account linking.

Plan chi tiết: `plans/261029-issue-34-auth-otp-google/plan.md` — bao gồm schema V51 (`auth_otp_challenges`, `user_oauth_accounts`, `users.password_hash` nullable), endpoints `/api/v1/auth/*`, error codes, mobile screens (OTP/forgot-password/Google button), tests và AC mapping.

Risk: high-risk (auth, DB migration, token revocation). Breaking change: `POST /auth/register` đổi contract sang flow 2 bước (request-otp → verify-otp). Mobile cập nhật cùng PR.

Mailer: `spring-boot-starter-mail` + `LoggingOtpSender` fallback (local/test, profile `local` mới log code). Google verify: `google-api-client` `GoogleIdTokenVerifier` kiểm tra sig/iss/aud/exp/email_verified; `GOOGLE_CLIENT_IDS` whitelist aud.
