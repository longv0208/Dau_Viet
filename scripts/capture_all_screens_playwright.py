import os
import sys
import time

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

from playwright.sync_api import sync_playwright

ARTIFACT_DIR = r"C:\Users\Admin\.gemini\antigravity\brain\7edf7e41-c431-4e09-ab46-69dd585bdac3"
BASE_URL = "http://localhost:3000"

def capture():
    print(f"Connecting to {BASE_URL} for comprehensive UI/UX Pro Max verification...")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Mobile viewport 412x915 (Google Pixel 7 standard)
        context = browser.new_context(
            viewport={"width": 412, "height": 915},
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()

        # 1. Screen 1: Giới thiệu bài học (Lesson Entry Screen)
        print("\n1. Capturing Screen 1: Giới thiệu bài học (Lesson Entry)...")
        page.goto(f"{BASE_URL}/#/learning/lesson/demo-lesson-bach-dang", wait_until="networkidle")
        page.wait_for_timeout(4000)
        s1_path = os.path.join(ARTIFACT_DIR, "screen1_lesson_entry.png")
        page.screenshot(path=s1_path)
        print(f"   Saved: {s1_path}")

        # 2. Screen 2: Câu hỏi trắc nghiệm (Multiple Choice Quiz)
        print("\n2. Capturing Screen 2: Trắc nghiệm 4 lựa chọn...")
        page.goto(f"{BASE_URL}/#/learning/quiz", wait_until="networkidle")
        page.wait_for_timeout(4000)
        s2_path = os.path.join(ARTIFACT_DIR, "screen2_multiple_choice.png")
        page.screenshot(path=s2_path)
        print(f"   Saved: {s2_path}")

        # 3. Screen 3: Ghép cặp dữ kiện (Matching Board)
        print("\n3. Capturing Screen 3: Ghép cặp tư liệu...")
        page.goto(f"{BASE_URL}/#/learning/matching", wait_until="networkidle")
        page.wait_for_timeout(4000)
        s3_path = os.path.join(ARTIFACT_DIR, "screen3_matching.png")
        page.screenshot(path=s3_path)
        print(f"   Saved: {s3_path}")

        # 4. Screen 4: Sắp xếp trình tự (Chronological Order)
        print("\n4. Capturing Screen 4: Sắp xếp thứ tự niên đại...")
        page.goto(f"{BASE_URL}/#/learning/order", wait_until="networkidle")
        page.wait_for_timeout(4000)
        s4_path = os.path.join(ARTIFACT_DIR, "screen4_drag_order.png")
        page.screenshot(path=s4_path)
        print(f"   Saved: {s4_path}")

        # 5. Screen 5: Lesson Player Attempt (Ngữ cảnh & Hoạt động)
        print("\n5. Capturing Screen 5: Lesson Player Attempt...")
        page.goto(f"{BASE_URL}/#/learning/attempt/demo-attempt-0001", wait_until="networkidle")
        page.wait_for_timeout(4000)
        s5_path = os.path.join(ARTIFACT_DIR, "screen5_lesson_player.png")
        page.screenshot(path=s5_path)
        print(f"   Saved: {s5_path}")

        # 6. Screen 6: Kết quả bài học (Lesson Result Screen)
        print("\n6. Capturing Screen 6: Tổng kết kết quả bài học...")
        page.goto(f"{BASE_URL}/#/learning/result/demo-attempt-0001", wait_until="networkidle")
        page.wait_for_timeout(4000)
        s6_path = os.path.join(ARTIFACT_DIR, "screen6_lesson_result.png")
        page.screenshot(path=s6_path)
        print(f"   Saved: {s6_path}")

        # 7. Journey Map & Timeline View
        print("\n7. Capturing Journey Map & Timeline...")
        page.goto(f"{BASE_URL}/#/map", wait_until="networkidle")
        page.wait_for_timeout(4000)
        s7_path = os.path.join(ARTIFACT_DIR, "screen7_journey_map.png")
        page.screenshot(path=s7_path)
        print(f"   Saved: {s7_path}")

        browser.close()
        print("\nAll Playwright screenshots captured successfully!")

if __name__ == "__main__":
    capture()
