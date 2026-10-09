# DẤU VIỆT — ASSET GENERATION GUIDELINES v2.0

**Status:** Proposed | **Art style:** Stylized Historical Illustration 2D / Illustrated Isometric 2.5D  
**Phạm vi:** asset cho Flutter learner, Admin CMS, bài học, bản đồ, island, reward.  
**Không dùng:** pixel art làm asset chủ đạo, text baked-in, AI image không review lịch sử.

## 1. Asset pipeline

`Brief → Historical References → Sketch/Composition → Style Review → Historical Review → Production → Export → Metadata → QA → Upload CMS → Mobile Preview → Publish`

Không đưa art AI thẳng vào lesson đã publish. Chỉ dùng với quyền rõ, nguồn ghi nhận, kiểm duyệt visual và nội dung lịch sử.

## 2. Category và format

| ID prefix | Nhóm | Hình thức | Định dạng delivery |
|---|---|---|---|
| `BG` | bối cảnh/scene | hand-painted 2D multi-layer | WebP/PNG layers |
| `CHR` | nhân vật | stylized 2D, poses/expression | PNG/WebP transparent |
| `MAP` | historical map | illustration base + markers separate | WebP/PNG + JSON marker coordinates |
| `EVT` | sự kiện / 4 Dấu | editorial illustrations, thumbnails | WebP/PNG |
| `EVD` | bằng chứng/tư liệu | scan/illustration + citation | WebP/PNG + metadata |
| `UI` | icon/frame/banner | vector clean, restrained motifs | SVG where supported / PNG fallback |
| `ACH` | badge/reward | illustrated metallic accents | SVG/PNG/WebP |
| `ISL` | island object | illustrated isometric 2.5D | transparent PNG/WebP + placement data |
| `ITEM` | shop/inventory | clear isometric/illustrated thumbnail | WebP/PNG |
| `FX` | effect | discreet motion (optional) | Lottie/Rive/sprite as evaluated |

SVG trong Flutter cần package/rendering support; không phụ thuộc SVG filter/feature không tương thích.

## 3. Composition rules

### 3.1 Historical scenes
- Subject / foreground / midground / background riêng nếu dùng parallax.
- Mỗi scene có focal point; để khoảng trống an toàn cho UI overlay và thiết bị nhiều aspect ratio.
- Không nhúng label, nút, đáp án, số tiền hay icon marker vào ảnh scene.
- Light direction và temperature thống nhất trong cùng chuỗi nội dung.

### 3.2 Characters
- Chốt style sheet trước khi làm nhiều nhân vật: tỷ lệ đầu/thân, contour, shading, brushwork, shadow, palette.
- Bàn giao neutral pose và action pose; ghi `era`, `identity`, `costumeEvidence`, `reviewStatus`.
- Tránh các chi tiết có thể gây nhầm niên đại hoặc vay mượn trang phục quốc gia khác.

### 3.3 Maps
- Asset nền không chứa vị trí click tương tác. Marker + route + unlock state là overlay data.
- Coordinates theo chuẩn normalized `(x, y)` trong miền [0,1] tương đối với kích thước map gốc; test ở các viewport.
- Thuyết minh ranh giới/lộ trình tranh luận hoặc giả định là 'sơ đồ minh họa' khi cần.

### 3.4 Isometric island
- Chọn thống nhất góc máy, hướng ánh sáng, scale object, baseline và shadow style; ghi trong style sheet.
- Mỗi vật phẩm có footprint, anchor/pivot, collision/placement rules và thumbnail riêng.
- Island tiers (nhỏ/vừa/lớn) là cấu hình scene/layout, không chỉ 3 ảnh raster cứng nếu muốn placement.

## 4. Export sizes — đề xuất ban đầu

| Asset | Master gợi ý | Delivery / QA |
|---|---|---|
| Event Hero | >= 2048 px cạnh dài | WebP responsive; check crop 16:9/4:3/portrait |
| Map Background | >= 2048 px cạnh dài, tile khi lớn | LOD/tiling nếu zoom sâu, memory test |
| Event/Trace Card | ~1024×768 master | crop-safe, thumbnails generated |
| Portrait | ~1024×1024 master | transparent, no text |
| Isometric Object | 512–1024 px vùng object master | transparent, anchor JSON |
| Icon | vector master | render test at 24/32/48dp |
| Background layer | phù hợp target scene | transparent layer, optimized size |

**Không** ép mọi hình về một pixel grid hay kích thước sprite 16/32/64 như v1. Kiểm soát độ sắc nét bằng master/resolution tiers, device pixel ratio và memory profiling.

## 5. File naming & storage

Pattern: `{project}_{category}_{era}_{subject}_{variant}_v{number}.{ext}`

Ví dụ:

```text
dv_BG_ngoquyen_bachdang_river-sunset_v01.webp
dv_CHR_ngoquyen_ngo-quyen_portrait-34_v02.png
dv_EVT_ngoquyen_bachdang_context-card_v01.webp
dv_MAP_ngoquyen_bachdang_base_v03.webp
dv_ISL_generic_village-house_a_v01.webp
```

Lưu master/source editable ở kho art riêng. Backend/CMS quản lý metadata, delivery URL và version; không xóa media đã tham chiếu bởi published lesson snapshot.

## 6. Asset metadata bắt buộc

```json
{
  "assetId": "BG_NGOQUYEN_BACHDANG_001",
  "kind": "BACKGROUND",
  "era": "Ngo Quyen (938-944)",
  "eventId": "bach-dang-938",
  "title": "Minh hoa song Bach Dang",
  "altText": "Minh họa thuyền chiến trên sông và núi ven bờ",
  "illustrationType": "HISTORICAL_RECONSTRUCTION",
  "historicalSources": [],
  "historicalConfidence": "REVIEW_REQUIRED",
  "historicalReviewer": null,
  "artReviewer": null,
  "license": "TO_BE_CONFIRMED",
  "generatedWithAI": false,
  "approvalStatus": "DRAFT",
  "version": 1,
  "variants": ["hero", "card", "thumbnail"]
}
```

`historicalConfidence` và `approvalStatus` phải có enum thống nhất với Admin CMS. Ghi rõ khi scene chỉ là tái dựng mang tính minh họa.

## 7. Prompt brief cho đội họa sĩ hoặc AI (đề xuất)

**Cấu trúc brief:**

```text
Subject: [đối tượng và thời kỳ]
Historical references: [nguồn/bằng chứng cụ thể]
Purpose: [hero/card/map/portrait]
Style: stylized 2D hand-painted Vietnamese historical illustration,
       nuanced natural palette, clean readable shapes,
       editorial adventure storybook atmosphere
Composition: [góc máy, vùng trống để overlay UI, crop-safe]
Light: [hướng sáng và thời gian trong ngày]
Output: [kích thước, nền trong suốt nếu object, layers]
Avoid: pixel art, modern objects, generic East Asian fantasy,
       embedded text/labels/buttons, inaccurate costume symbols
Review required: historical and licensing clearance before publishing
```

**Ví dụ brief — Bạch Đằng 938:**

> Minh họa 2D hand-painted mang tính tái dựng về cảnh sông Bạch Đằng năm 938, thuyền chiến trên sông, cảnh quan thiên nhiên Bắc Bộ; bố cục màn hình dọc có vùng trống phía dưới cho overlay chữ. Không có chữ trên ảnh. Phục trang, thuyền, chiến thuật và cờ cần được reviewer đối chiếu với nguồn tham khảo trước khi xuất bản; những chi tiết chưa chắc chắn phải được đánh dấu minh họa.

## 8. QA Checklist

- [ ] Visual style: minh họa 2D/2.5D thống nhất, không pixel-art ngoài chủ đích.
- [ ] Thể hiện đúng thời kỳ; reviewer lịch sử duyệt.
- [ ] Quyền sở hữu/license/source đầy đủ.
- [ ] Không chứa UI text baked-in.
- [ ] Thử crop trên màn nhỏ, tablet, tỉ lệ dọc/ngang cần hỗ trợ.
- [ ] Test performance/memory: kích thước decode texture và lazy loading.
- [ ] Alt text, caption và attribution chính xác.
- [ ] Transparency không có halo; edge/lighting khớp scene.
- [ ] Marker/interaction positions không nằm trong raster.
- [ ] Các variant và version được upload CMS, rollback được.

## 9. Delivery folder convention

```text
assets/
├── source/                 # PSD/KRA/AI/FIG, không đưa vào app
├── exported/
│   ├── backgrounds/
│   ├── characters/
│   ├── maps/
│   ├── event-cards/
│   ├── evidence/
│   ├── ui-icons/
│   ├── achievements/
│   └── islands/
└── manifests/              # JSON metadata; map markers; footprints
```

## 10. Quyết định còn mở

- Công cụ tạo artwork chính; chuẩn layer có bắt buộc không.
- Góc isometric và world-unit cụ thể của Island.
- Crop profiles cho thiết bị target và cỡ tải phù hợp.
- Quyền sử dụng/giấy phép cho nguồn tham khảo, font và asset tạo bằng AI.
- Bộ 10–20 art samples chuẩn để Art Lead approve trước khi scale production.
