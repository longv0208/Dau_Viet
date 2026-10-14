# dau_viet_mobile

Ứng dụng Flutter Dấu Việt — Trục Thời Gian + Chi tiết chiến dịch nạp từ backend Spring Boot (`dau-viet-backend`).

## Chạy app

Yêu cầu: Flutter SDK (Dart >= 3.12), backend đang chạy (xem `docs/backend-runbook.md`).

```bash
# Cài dependencies (lần đầu / sau khi đổi pubspec)
flutter pub get

# Chạy mặc định — gọi API thật; base URL mặc định:
#   Android emulator  → http://10.0.2.2:8080
#   iOS sim / desktop → http://localhost:8080
flutter run

# Chỉ định base URL khác (máy thật / backend từ xa)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080

# Chạy chế độ demo offline — dữ liệu mock, không cần backend
flutter run --dart-define=USE_MOCK=true
```

`API_BASE_URL` mặc định: `http://10.0.2.2:8080` trên Android (alias localhost của máy host), `http://localhost:8080` cho các nền tảng còn lại.

`USE_MOCK` mặc định `false`. Khi API lỗi, app hiển thị thẻ lỗi + nút THỬ LẠI — **không** tự động đổi sang dữ liệu giả.

## Bật backend cho môi trường dev

```bash
cd ../dau-viet-backend
docker compose up -d
set JAVA_HOME=E:\Java\jdk-21   # bắt buộc trên máy này (JAVA_HOME hệ thống hỏng)
mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
# Seed Bạch Đằng 938: id 00000000-0000-0000-0000-000000000001, slug bach-dang-938
```

## Kiểm thử

```bash
flutter analyze
flutter test
```

Test suite bao gồm DTO parsing, repository (stub client), AssetResolver, widget states (loading/error/retry/empty), và journey test chạy trên `MockEventsRepository` override.
