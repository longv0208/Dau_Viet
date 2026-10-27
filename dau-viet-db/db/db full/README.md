# Full DB snapshot — dauviet

Dump Postgres nguyên trạng của instance local (`dauviet` trên `localhost:5433`),
chụp lúc 2026-10-26 sau khi đã chạy Flyway V1→V30 + EventSeedRunner.

## Chứa gì

- Toàn bộ schema + constraints + index + trigger
- 21 historical_events (PUBLISHED + vài ARCHIVED test)
- 32 lessons (gôm các bài học chuẩn hóa V29)
- 61 evidences
- 10 nimation_scenes PUBLISHED + template + version
- `item_catalog` + `item_unlock_rule`, `lesson_templates`, `users` hệ thống
- Sequence, extension, mọi migration metadata trong `flyway_schema_history`

## Restore

```powershell
# vào container Postgres đang chạy
docker exec -i dauviet-postgres psql -U dauviet -d dauviet < dauviet-full-dump.sql

# hoặc sang DB trống mới
docker exec dauviet-postgres createdb -U dauviet dauviet_new
docker exec -i dauviet-postgres psql -U dauviet -d dauviet_new < dauviet-full-dump.sql
```

## Lưu ý

- Dump là **plain SQL** (`-Fp`), không nén — chỉnh sửa được nhưng file ~2.3 MB.
- `--no-owner --no-privileges` → restore vào user/db khác cũng được, quyền giữ nguyên của user chạy.
- `flyway_schema_history` có sẵn trong dump → Flyway sẽ nhận ra "đã migrate xong", không chạy lại V1–V30.
- User `system@dauviet.local` là tài khoản hệ thống DISABLED, không đăng nhập được — tạo admin riêng qua API/seed sau khi restore.
