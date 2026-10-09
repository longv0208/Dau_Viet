# Đối chiếu nguồn

Ngày kiểm tra: 2026-10-09. Đây là khảo sát tài liệu, chưa chạy hoặc kiểm toán công cụ.

## Hiện trạng Dấu Việt

- Ba thư mục ứng dụng đang trống. Tài liệu hiện hữu ở `docs/` mô tả Spring Boot, PostgreSQL, Next.js và Flutter.
- Git đang ở nhánh `master` chưa có commit; `docs/` là dữ liệu untracked của người dùng.
- Không có GitNexus hoặc Serena trong danh sách MCP tools của phiên khảo sát. Context7 được dùng để tra tài liệu GitNexus; việc đọc local dùng PowerShell và rg.
- Chưa cài package, kết nối MCP, chạy index, sửa cấu hình agent hoặc triển khai harness.

## ULP: thành phần tham khảo

[HARNESS.md](https://github.com/dikhamchua/ulp/blob/main/docs/HARNESS.md) mô tả CLI Rust, SQLite cục bộ, story, bằng chứng kiểm thử, trace, ADR và backlog cải tiến. Đây là thiết kế riêng của repo, chưa xác minh khả năng tái sử dụng binary hoặc mã nguồn.

[FEATURE_INTAKE.md](https://github.com/dikhamchua/ulp/blob/main/docs/FEATURE_INTAKE.md) phân công việc thành tiny, normal, high-risk. Dấu Việt cần chính sách riêng cho publish/version, quyền sở hữu attempt và reward.

[TOOL_REGISTRY.md](https://github.com/dikhamchua/ulp/blob/main/docs/TOOL_REGISTRY.md) phân biệt công cụ được khai báo với công cụ thực sự dùng được trong phiên. Dấu Việt nên kiểm tra kết nối và kết quả gọi thay vì chỉ kiểm tra có thư mục cấu hình.

[AGENTS.md](https://github.com/dikhamchua/ulp/blob/main/AGENTS.md) kết nối hướng dẫn Harness và GitNexus. Không sao chép số lượng symbol hoặc trạng thái index từ ULP sang Dấu Việt.

## GitNexus: điều đã xác minh qua tài liệu

[README chính thức](https://github.com/abhigyanpatwari/GitNexus) và Context7 `/abhigyanpatwari/gitnexus` mô tả CLI/MCP, công cụ tìm kiếm, ngữ cảnh symbol, phân tích ảnh hưởng và thay đổi. `analyze` có thể tạo hoặc cập nhật hướng dẫn/skills/hooks; `setup` có thể ghi cấu hình editor toàn cục. Cần pin phiên bản, đọc `--help`, kiểm tra diff và giới hạn cấu hình khi triển khai. Tài liệu nêu Java, TypeScript và Dart; chất lượng phân tích trên nền tảng, phiên bản và mã thực tế cần smoke test riêng.

## Quyết định đề xuất của kế hoạch

Xây harness nhỏ bằng script và dữ liệu có schema trong repo; giữ giao diện adapter để thay đổi công cụ sau này. Chưa port Rust/SQLite của ULP. Chỉ cân nhắc SQLite khi truy vấn và số lượng task tạo ra nhu cầu cụ thể. GitNexus hỗ trợ phân tích ảnh hưởng; build, test và contract test vẫn cung cấp bằng chứng đúng/sai. Đây là đề xuất cho Dấu Việt, không phải khẳng định về tính năng ULP.
