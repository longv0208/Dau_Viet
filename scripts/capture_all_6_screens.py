import os
import sys
import time

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

from playwright.sync_api import sync_playwright

ARTIFACT_DIR = r"C:\Users\Admin\.gemini\antigravity\brain\7edf7e41-c431-4e09-ab46-69dd585bdac3"
BASE_URL = "http://localhost:3000"

def capture():
    print("Capturing all 6 screens matching the user's UI/UX Pro Max mockup...")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 412, "height": 915},
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()

        # 1. Screen 1: Lesson Entry
        print("\n1. Screen 1: Giới thiệu bài học...")
        page.goto(f"{BASE_URL}/#/learning/lesson/demo-lesson-bach-dang", wait_until="networkidle")
        page.wait_for_timeout(3500)
        s1 = os.path.join(ARTIFACT_DIR, "screen1_lesson_entry_final.png")
        page.screenshot(path=s1)
        print(f"   Saved: {s1}")

        # 2. Screen 2: MCQ 4 Choices
        print("\n2. Screen 2: Câu hỏi trắc nghiệm 4 lựa chọn...")
        page.goto(f"{BASE_URL}/#/learning/attempt/demo-attempt-0001?step=0", wait_until="networkidle")
        page.wait_for_timeout(3500)
        # Select first option to show checked state
        page.mouse.click(206, 320)
        page.wait_for_timeout(500)
        s2 = os.path.join(ARTIFACT_DIR, "screen2_mcq_final.png")
        page.screenshot(path=s2)
        print(f"   Saved: {s2}")

        # 3. Screen 3: Matching Portraits & Connectors
        print("\n3. Screen 3: Ghép cặp thẻ tư liệu...")
        page.goto(f"{BASE_URL}/#/learning/attempt/demo-attempt-0001?step=1", wait_until="networkidle")
        page.wait_for_timeout(3500)
        # Select first left card to show active connector state
        page.mouse.click(90, 260)
        page.wait_for_timeout(500)
        s3 = os.path.join(ARTIFACT_DIR, "screen3_matching_final.png")
        page.screenshot(path=s3)
        print(f"   Saved: {s3}")

        # 4. Screen 4: Drag Order Badges
        print("\n4. Screen 4: Sắp xếp trình tự niên đại...")
        page.goto(f"{BASE_URL}/#/learning/attempt/demo-attempt-0001?step=2", wait_until="networkidle")
        page.wait_for_timeout(3500)
        s4 = os.path.join(ARTIFACT_DIR, "screen4_drag_order_final.png")
        page.screenshot(path=s4)
        print(f"   Saved: {s4}")

        # 5. Screen 5: True / False with Historical Painting
        print("\n5. Screen 5: Đúng / Sai có tranh minh họa...")
        page.goto(f"{BASE_URL}/#/learning/attempt/demo-attempt-0001?step=3", wait_until="networkidle")
        page.wait_for_timeout(3500)
        # Select 'Đúng' button to show active tactile state
        page.mouse.click(110, 680)
        page.wait_for_timeout(500)
        s5 = os.path.join(ARTIFACT_DIR, "screen5_true_false_final.png")
        page.screenshot(path=s5)
        print(f"   Saved: {s5}")

        # 6. Screen 6: Lesson Result Celebration
        print("\n6. Screen 6: Kết quả bài học & Ăn mừng...")
        page.goto(f"{BASE_URL}/#/learning/result/demo-attempt-0001", wait_until="networkidle")
        page.wait_for_timeout(3500)
        s6 = os.path.join(ARTIFACT_DIR, "screen6_result_final.png")
        page.screenshot(path=s6)
        print(f"   Saved: {s6}")

        browser.close()
        print("\nAll 6 screens captured with high fidelity!")

if __name__ == "__main__":
    capture()
