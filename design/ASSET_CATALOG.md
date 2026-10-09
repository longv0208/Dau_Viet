# DẤU VIỆT — VISUAL & AUDIO ASSET CATALOG / PRODUCTION BRIEF

**Important:** 8 ảnh đính kèm là **boards/mockups tổng hợp**, không cung cấp logo tách nền, tranh gốc, layers, sprite atlas hay file có thể chỉnh sửa. Tài liệu là **asset requirements/inventory**, không phải một thư mục asset đã được tạo. Artwork mới cần được vẽ/thiết kế và kiểm duyệt bản quyền, lịch sử.

## 1. Asset ownership & status

| Trạng thái | Ý nghĩa |
|---|---|
| `REFERENCE_ONLY` | mới có trong concept; không dùng trực tiếp làm production asset |
| `TO_CREATE` | cần vẽ hoặc thiết kế mới |
| `IN_DESIGN` | art đang sản xuất |
| `READY_FOR_REVIEW` | chờ duyệt style/accuracy/license |
| `APPROVED` | được phép import vào mobile/admin |
| `DEPRECATED` | không được dùng bản mới; phiên bản published cũ có thể phải giữ |

`sourceRef` dùng `UI-1..UI-8` và/hoặc `BA page xx`; `historicalAccuracyReview` bắt buộc cho bản đồ, chân dung, biểu tượng lịch sử, tàu/cọc gỗ, tư liệu.

## 2. Asset catalog: shared/design system

| Asset ID | Tên / nhóm | Render usage | Format đề xuất | Source | Priority |
|---|---|---|---|---|---|
| AST-BRD-001 | Dấu Việt main logo (transparent) | top bar/splash/admin login | SVG + PNG/WebP | UI-1..8 | P0 |
| AST-BRD-002 | App icon / favicon | OS/web | PNG + SVG source | UI-1..8 | P0 |
| AST-UI-001 | Parchment panel/scroll header | section headers | SVG/9-slice PNG | UI-1..8 | P0 |
| AST-UI-002 | Ornate red-gold plaque | title/result/buttons | 9-slice raster or SVG | UI-1..8 | P0 |
| AST-UI-003 | Button states atlas | CTA variants | SVG/9-slice | UI-1..8 | P0 |
| AST-UI-004 | Lock/unlock/completed icons | map/collection | SVG | UI-1,2,4,5 | P0 |
| AST-UI-005 | Bottom nav icon set | mobile navigation | SVG | UI-1..8 | P0 |
| AST-UI-006 | Background sky/mountain/water motifs | decorative shell | layered WebP | UI-1..8 | P1 |
| AST-UI-007 | Avatar/profile base set | profile/navigation | WebP/PNG | UI-1..8 | P0 |
| AST-UI-008 | Empty/error/loading illustrations | system states | SVG/WebP | Proposal | P0 |
| AST-UI-009 | Currency/XP/energy icons | reward/economy | SVG | UI-4,6,7 | P1/P2 |

## 3. Learning assets (MVP)

| Asset ID | Content/group | Screen use | Deliverable details | Source | Priority |
|---|---|---|---|---|---|
| AST-HIS-001 | Era: Âu Lạc visual | M-04 | era thumbnail + alt text/source record | UI-1 | P0 |
| AST-HIS-002 | Era: Hai Bà Trưng visual | M-04 | era thumbnail | UI-1 | P0 |
| AST-HIS-003 | Era: Vạn Xuân visual | M-04 | era thumbnail | UI-1 | P0 |
| AST-HIS-004 | Era: Ngô Quyền cover/hero | M-04/05 | landscape hero + thumbnail crop | UI-1 | P0 |
| AST-MAP-001 | Ngô Quyền period map base | M-06 | map art WITHOUT functional marker/labels | UI-1,2 | P0 |
| AST-MAP-002 | Map waypoint/path markers | M-06 | separate states, animation optional | UI-1,2 | P0 |
| AST-EVT-001 | Trận Bạch Đằng 938 hero | M-07/08/10/18 | landscape, portrait safe crop, attribution | UI-2..4 | P0 |
| AST-CLUE-001 | Dấu bối cảnh artwork | M-08 | card image and detail illustration | UI-2 | P0 |
| AST-CLUE-002 | Dấu nhân vật / Ngô Quyền | M-08/11 | portraits, transparent optional | UI-2,3 | P0 |
| AST-CLUE-003 | Dấu diễn biến / naval combat | M-08/12 | event tiles | UI-2,3 | P0 |
| AST-CLUE-004 | Dấu ý nghĩa / banner icon | M-08 | card image | UI-2 | P0 |
| AST-EVD-001 | Bãi cọc gỗ visual | evidence/reasoning | cropped thumb + full image | UI-3; BA p21 | P0 |
| AST-EVD-002 | Dòng sông/thủy triều visual | evidence/reasoning | thumb + source note | UI-3; BA p21 | P0 |
| AST-EVD-003 | Nam Hán/đối thủ illustration | reasoning | thumb + alt text | UI-3 | P0 |
| AST-EVT-002..N | Reconstruction event tile set | M-12 | sequence illustrations (N configurable) | UI-3 | P0 |
| AST-RES-001 | Victory banner/trophy/laurel | M-19 | split layers if animation | UI-4 | P0 |
| AST-RES-002 | Bạch Đằng achievement emblem | M-20 | unlocked/locked variants | UI-4 | P1 |
| AST-RES-003 | Thuyền Bạch Đằng collectible | M-19/20 | inventory thumb + detail | UI-4 | P1 |
| AST-STORY-001..N | Narration scene pack | M-18 | illustrations with text separate | BA p26, UI-4 | P0 |

**Historical review note:** Hình ảnh tái dựng các trận đánh, nhân vật và niên đại phải được gắn nhãn `Minh họa/tái dựng` nếu không là tư liệu gốc. Text/citation phải đi từ CMS, không chỉ tồn tại trong pixel image.

## 4. Metagame/Shop/Island assets (concept P2)

| Asset ID | Tên | Loại / yêu cầu layer | Referenced UI |
|---|---|---|---|
| AST-ISL-001 | Đảo nhỏ base | land-water background + decoration slots | UI-5 |
| AST-ISL-002 | Đảo vừa base | base + object layers | UI-5 |
| AST-ISL-003 | Đảo lớn base | base + objects/hit regions | UI-5 |
| AST-ISL-004 | Island world map / unlock map | background, independent island markers | UI-8 |
| AST-DEC-001 | Nhà tranh | inventory/store/placement variants | UI-6 |
| AST-DEC-002 | Cầu gỗ | inventory/store/placement | UI-6 |
| AST-DEC-003 | Cây đa | inventory/store/placement | UI-6 |
| AST-DEC-004 | Hồ sen | inventory/store/placement | UI-6 |
| AST-DEC-005 | Cây đào | inventory/store/placement | UI-6 |
| AST-DEC-006 | Bụi tre | inventory/store/placement | UI-6 |
| AST-DEC-007 | Đèn lồng | inventory/store/placement | UI-6 |
| AST-DEC-008 | Quán hàng | inventory/store/placement | UI-6 |
| AST-DEC-009 | Giếng đá | inventory/store/placement | UI-6 |
| AST-PRM-001 | Hoàng thành Thăng Long | premium collectible/placement | UI-6 |
| AST-PRM-002 | Chùa Trấn Quốc | premium collectible/placement | UI-6 |
| AST-PRM-003 | Thuyền rồng | premium collectible/placement | UI-6 |
| AST-PRM-004 | Quần đảo Hạ Long | premium collectible/placement | UI-6 |
| AST-ENE-001 | Lightning bolt icon | current energy/buy energy | UI-7 |
| AST-ENE-002..004 | Energy pack illustrations | 30/100/300 pack concept (values configurable) | UI-7 |

**Giá, năng lượng, XP trong mockup chỉ là concept, chưa được chuẩn hóa kinh tế hoặc quyết định giá bán.** Không hardcode thành asset, SKU hoặc business rule.

## 5. Admin-specific visual assets

| Asset ID | Purpose | Production |
|---|---|---|
| AST-ADM-001 | Admin brand lockup | derived approved logo, no redraw |
| AST-ADM-002 | Editor icons / stage taxonomy | vector 16/20/24 px adaptable |
| AST-ADM-003 | Asset placeholder/error preview | icon + descriptive text |
| AST-ADM-004 | Template illustration thumbnails | optional per template; can start with simple icons |
| AST-ADM-005 | Preview device frame | CSS-drawn preferred, not screenshot with baked content |

Admin Asset Library quản lý **metadata của tất cả asset học tập** và có thể tái dùng cho nhiều lessons; không upload trùng vì mỗi activity cần ảnh.

## 6. Technical asset manifest schema [Proposal]

```json
{
  "assetId": "AST-EVD-001",
  "slug": "bach-dang-wooden-stakes",
  "kind": "ILLUSTRATION",
  "status": "TO_CREATE",
  "sourceRef": ["UI-3", "BA-page-21"],
  "locale": "vi-VN",
  "variants": [
    {"role": "thumbnail", "uri": null, "width": null, "height": null},
    {"role": "full", "uri": null, "width": null, "height": null}
  ],
  "altText": "Minh họa các cọc gỗ trên sông Bạch Đằng",
  "historicalAccuracyReview": "PENDING",
  "license": "TBD",
  "attribution": "TBD",
  "usedBy": ["M-13", "M-11"]
}
```

## 7. Export & design handoff rules

1. **Tên file**: `ast_<category>_<subject>_<variant>_v001.webp` hoặc `.svg`, ASCII snake_case. Ví dụ `ast_evt_bach_dang_hero_v001.webp`.
2. **Master layers**: file editable design source (Figma/PSD/AI/Krita), background/character/effects/text/UI controls xuất riêng; không có text động trong background.
3. **Responsive crops**: hero full-bleed phải có vùng an toàn cho title/CTA; xuất thumb và detail variants; test low-end devices.
4. **Pixel/isometric consistency**: palette, texture grain, direction of light, line weight, pixel density phải thống nhất; không resize pixel art mờ.
5. **UI ornaments**: 9-slice / scalable borders; không stretch full PNG chứa góc trang trí gây biến dạng.
6. **Map semantics**: coordinate-based markers; nguồn tọa độ, label, tooltips là data.
7. **No unlicensed material**: track `creator`, rights/license, reference, source URL, attribution; tính nhạy cảm lịch sử cần review nội dung.
8. **Performance targets**: đặt sau benchmark trên device thực; nén media phù hợp, preload stage đầu, lazy load art độ phân giải cao.
9. **Version safety**: media được tham chiếu bởi LessonVersion không bị xóa/overwrite vật lý; archive/retention có quản lý.
10. **Asset acceptance**: correct art direction + historical check + accessibility label + size review + rendering test + rights approved.

## 8. Production priority / first art sprint

**P0 đầu tiên:** logo, top/nav/scroll/button system → event/era hero, period map base + standalone markers → 4 clue cards → evidence cards → MCQ/matching/order illustrated cards → result/story.  
**P1:** rewards expansion, collection, global map.  
**P2:** 3 island backgrounds + placeable decoration variants + shop premium goods + energy packs.
