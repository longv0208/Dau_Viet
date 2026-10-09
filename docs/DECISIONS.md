# Quyết định kỹ thuật về agent workflow

Ngày: 2026-10-09. Phạm vi: workflow AI; kiến trúc sản phẩm giữ tại [TECH_STACK](TECH_STACK.md).

| ID | Quyết định | Lý do và hệ quả |
|---|---|---|
| ADR-001 | Claude Code là agent chính, workflow không phụ thuộc vendor | Adapter khác đọc cùng AGENTS/task; chỉ tạo adapter khi dùng |
| ADR-002 | PowerShell 7 + JSON cho harness đầu tiên | Phù hợp Windows; dễ review; chưa cần daemon/DB/Rust |
| ADR-003 | Task JSON là nguồn trạng thái chuẩn | PROGRESS là view; plans chứa thiết kế; tránh lệch trạng thái |
| ADR-004 | Tái sử dụng sáu tài liệu sản phẩm hiện hữu | Không tạo PROJECT/ARCHITECTURE/CONVENTIONS trùng nội dung |
| ADR-005 | GitNexus có fallback và snapshot | Code graph bổ sung tìm kiếm/contract; không thay thế test |
| ADR-006 | Evidence gắn fingerprint và gate config | Sửa input làm kết quả cũ stale; missing/failed không thành pass |
| ADR-007 | Module bắt đầu uninitialized | Repo chưa có source; chỉ active sau bootstrap và smoke |
| ADR-008 | Không auto commit/push hoặc sửa global MCP | Giữ thao tác bên ngoài runner trong phạm vi được ủy quyền |

Thay quyết định phải ghi lý do, ảnh hưởng, task/plan liên quan. Các lựa chọn sản phẩm còn mở trong tài liệu thiết kế cần PO xác nhận trước khi triển khai phần phụ thuộc.
