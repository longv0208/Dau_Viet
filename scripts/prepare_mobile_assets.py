import os
import shutil
import numpy as np
from PIL import Image
from collections import deque

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def remove_background_connected(img, tolerance=28, feather=8):
    """
    Tách nền bằng thuật toán Flood Fill từ 4 viền mép ảnh:
    - Nhận diện màu nền từ 4 góc
    - Chỉ xóa các pixel kết nối với viền có màu tương đồng
    - Giữ nguyên 100% các chi tiết bên trong vật thể dù có cùng màu với nền
    - Feathering tạo viền mềm mại, không răng cưa
    """
    img = img.convert('RGBA')
    arr = np.array(img, dtype=np.float32)
    h, w, _ = arr.shape
    
    # Lấy màu nền mẫu từ các góc
    corners = [arr[0, 0, :3], arr[0, w - 1, :3], arr[h - 1, 0, :3], arr[h - 1, w - 1, :3]]
    bg_color = np.median(corners, axis=0)
    
    # Tính khoảng cách Euclidean màu
    diff = np.sqrt(np.sum((arr[:, :, :3] - bg_color) ** 2, axis=2))
    is_bg_candidate = diff < (tolerance + feather)
    
    # BFS Flood fill từ mép ngoài
    visited = np.zeros((h, w), dtype=bool)
    queue = deque()
    
    for x in range(w):
        if is_bg_candidate[0, x]:
            queue.append((0, x))
            visited[0, x] = True
        if is_bg_candidate[h - 1, x]:
            queue.append((h - 1, x))
            visited[h - 1, x] = True
    for y in range(h):
        if is_bg_candidate[y, 0] and not visited[y, 0]:
            queue.append((y, 0))
            visited[y, 0] = True
        if is_bg_candidate[y, w - 1] and not visited[y, w - 1]:
            queue.append((y, w - 1))
            visited[y, w - 1] = True
            
    while queue:
        cy, cx = queue.popleft()
        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and is_bg_candidate[ny, nx]:
                visited[ny, nx] = True
                queue.append((ny, nx))
                
    # Gán kênh Alpha với viền feathering
    alpha = arr[:, :, 3].copy()
    for y in range(h):
        for x in range(w):
            if visited[y, x]:
                d = diff[y, x]
                if d <= tolerance:
                    alpha[y, x] = 0
                else:
                    alpha[y, x] = int(255 * (d - tolerance) / feather)
                    
    arr[:, :, 3] = alpha
    result = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    
    # Tự động cắt khoảng trắng thừa xung quanh (Auto-trim bounding box)
    bbox = result.getbbox()
    if bbox:
        # Giữ viền padding 6px
        pad = 6
        left = max(0, bbox[0] - pad)
        top = max(0, bbox[1] - pad)
        right = min(w, bbox[2] + pad)
        bottom = min(h, bbox[3] + pad)
        return result.crop((left, top, right, bottom))
    return result

def make_circular_badge(img, diameter=460):
    """Cắt huy hiệu hình tròn với viền alpha mượt mà"""
    w, h = img.size
    cx, cy = w // 2, h // 2
    r = diameter // 2
    
    # Crop tâm
    cropped = img.crop((cx - r, cy - r, cx + r, cy + r)).convert('RGBA')
    
    # Tạo circular alpha mask
    mask = Image.new('L', (diameter, diameter), 0)
    import math
    for y in range(diameter):
        for x in range(diameter):
            dist = math.sqrt((x - r) ** 2 + (y - r) ** 2)
            if dist <= r - 2:
                mask.putpixel((x, y), 255)
            elif dist <= r:
                mask.putpixel((x, y), int(255 * (r - dist) / 2))
                
    cropped.putalpha(mask)
    return cropped

def process_all_assets():
    src_dir = r'design\assets'
    dest_dir = r'dau-viet-mobile\assets'
    img_dir = os.path.join(dest_dir, 'images')
    badge_dir = os.path.join(dest_dir, 'badges')
    item_dir = os.path.join(dest_dir, 'items')
    
    ensure_dir(img_dir)
    ensure_dir(badge_dir)
    ensure_dir(item_dir)
    
    # 1. Copy các ảnh toàn cảnh / Hero / Sa bàn (giữ nguyên độ phân giải cao)
    full_images = [
        'dv_EVT_ngoquyen_bachdang_hero_v01.jpg',
        'dv_MAP_ngoquyen_bachdang-base_v01.jpg',
        'dv_ISL_generic_island-base-tiers_v01.jpg',
        'activity_feedback_ui.jpg',
    ]
    for fn in full_images:
        sp = os.path.join(src_dir, fn)
        dp = os.path.join(img_dir, fn)
        if os.path.exists(sp):
            shutil.copy2(sp, dp)
            print(f'[COPY FULL] {fn} -> {dp}')
            
    # 2. Xử lý Dải Băng Khải Hoàn (Victory Banner) -> Transparent PNG
    ach_path = os.path.join(src_dir, 'dv_ACH_shared_victory-banner_v01.jpg')
    if os.path.exists(ach_path):
        ach_img = Image.open(ach_path)
        ach_trans = remove_background_connected(ach_img, tolerance=32, feather=10)
        ach_out = os.path.join(img_dir, 'victory_banner.png')
        ach_trans.save(ach_out, 'PNG')
        print(f'[TRANSPARENT] Victory Banner -> {ach_out}')

    # 3. Cắt và Tách nền Bộ 4 Công Trình Đảo Di Sản (Decor Pack 1)
    decor_path = os.path.join(src_dir, 'dv_ISL_heritage_decor-pack-1_v01.jpg')
    if os.path.exists(decor_path):
        decor_img = Image.open(decor_path)
        decor_items = [
            ('decor_cay_da.png', (0, 0, 512, 512)),
            ('decor_cau_kieu.png', (512, 0, 1024, 512)),
            ('decor_nha_tranh.png', (0, 512, 512, 1024)),
            ('decor_ho_sen.png', (512, 512, 1024, 1024)),
        ]
        for name, box in decor_items:
            quad = decor_img.crop(box)
            trans = remove_background_connected(quad, tolerance=30, feather=8)
            out_p = os.path.join(item_dir, name)
            trans.save(out_p, 'PNG')
            print(f'[DECOR ITEM] {name} -> {out_p}')

    # 4. Cắt và Tách nền Bộ 4 Gói Dược Liệu Năng Lượng (Energy Packs)
    energy_path = os.path.join(src_dir, 'dv_UI_shared_energy-packs_v01.jpg')
    if os.path.exists(energy_path):
        energy_img = Image.open(energy_path)
        energy_items = [
            ('energy_tra_sen.png', (0, 0, 512, 512)),
            ('energy_nuoc_voi.png', (512, 0, 1024, 512)),
            ('energy_sam_ngoc_linh.png', (0, 512, 512, 1024)),
            ('energy_linh_chi.png', (512, 512, 1024, 1024)),
        ]
        for name, box in energy_items:
            quad = energy_img.crop(box)
            trans = remove_background_connected(quad, tolerance=24, feather=8)
            out_p = os.path.join(item_dir, name)
            trans.save(out_p, 'PNG')
            print(f'[ENERGY ITEM] {name} -> {out_p}')

    # 5. Cắt và Tách nền Bộ 4 Huy Hiệu Dấu Vết Lịch Sử (Badges)
    badge_path = os.path.join(src_dir, 'bon_dau_vet_badges.jpg')
    if os.path.exists(badge_path):
        b_img = Image.open(badge_path)
        badge_items = [
            ('badge_trace_1_context.png', (0, 0, 512, 512)),
            ('badge_trace_2_characters.png', (512, 0, 1024, 512)),
            ('badge_trace_3_tactics.png', (0, 512, 512, 1024)),
            ('badge_trace_4_archaeology.png', (512, 512, 1024, 1024)),
        ]
        for name, box in badge_items:
            quad = b_img.crop(box)
            circ = make_circular_badge(quad, diameter=440)
            out_p = os.path.join(badge_dir, name)
            circ.save(out_p, 'PNG')
            print(f'[CIRCULAR BADGE] {name} -> {out_p}')

    print('=== ALL ASSETS PROCESSED SUCCESSFULLY ===')

if __name__ == '__main__':
    process_all_assets()
