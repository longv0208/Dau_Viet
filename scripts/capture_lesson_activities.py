import os
import sys
import time

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

from playwright.sync_api import sync_playwright

ARTIFACT_DIR = r"C:\Users\Admin\.gemini\antigravity\brain\7edf7e41-c431-4e09-ab46-69dd585bdac3"
BASE_URL = "http://localhost:3000"

def run():
    print("Launching Playwright to capture all interactive learning activities...")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 412, "height": 915},
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()

        # Load attempt
        page.goto(f"{BASE_URL}/#/learning/attempt/demo-attempt-0001", wait_until="networkidle")
        page.wait_for_timeout(4000)

        # 1. Screen 2: MCQ 4 choices
        print("1. Capturing Screen 2: Trắc nghiệm 4 lựa chọn...")
        mcq_path = os.path.join(ARTIFACT_DIR, "screen2_mcq_interactive.png")
        page.screenshot(path=mcq_path)
        print(f"   Saved: {mcq_path}")

        # Click first option (approx x: 206, y: 350)
        page.mouse.click(206, 350)
        page.wait_for_timeout(500)
        # Click submit "GỬI CÂU TRẢ LỜI" (approx y: 840)
        page.mouse.click(206, 840)
        page.wait_for_timeout(1000)
        # Click continue "TIẾP TỤC ›"
        page.mouse.click(206, 840)
        page.wait_for_timeout(3500)

        # 2. Screen 3: Matching
        print("2. Capturing Screen 3: Ghép cặp dữ kiện...")
        match_path = os.path.join(ARTIFACT_DIR, "screen3_matching_interactive.png")
        page.screenshot(path=match_path)
        print(f"   Saved: {match_path}")

        # Pair items and advance
        page.mouse.click(90, 260)  # Left 1
        page.wait_for_timeout(200)
        page.mouse.click(300, 480) # Right 4
        page.wait_for_timeout(300)
        # Submit
        page.mouse.click(206, 840)
        page.wait_for_timeout(1000)
        # Continue
        page.mouse.click(206, 840)
        page.wait_for_timeout(3500)

        # 3. Screen 4: Drag Order
        print("3. Capturing Screen 4: Sắp xếp trình tự...")
        order_path = os.path.join(ARTIFACT_DIR, "screen4_order_interactive.png")
        page.screenshot(path=order_path)
        print(f"   Saved: {order_path}")

        # Submit order
        page.mouse.click(206, 840)
        page.wait_for_timeout(1000)
        # Continue
        page.mouse.click(206, 840)
        page.wait_for_timeout(3500)

        # 4. Screen 5: True / False with historical scene painting
        print("4. Capturing Screen 5: Đúng / Sai có tranh minh họa...")
        tf_path = os.path.join(ARTIFACT_DIR, "screen5_true_false_interactive.png")
        page.screenshot(path=tf_path)
        print(f"   Saved: {tf_path}")

        # Click Đúng (left button, approx x: 100, y: 700)
        page.mouse.click(110, 680)
        page.wait_for_timeout(500)
        # Submit
        page.mouse.click(206, 840)
        page.wait_for_timeout(1000)
        # Complete
        page.mouse.click(206, 840)
        page.wait_for_timeout(4000)

        # 5. Screen 6: Lesson Result
        print("5. Capturing Screen 6: Kết quả bài học...")
        res_path = os.path.join(ARTIFACT_DIR, "screen6_result_interactive.png")
        page.screenshot(path=res_path)
        print(f"   Saved: {res_path}")

        browser.close()
        print("\nAll activities captured successfully!")

if __name__ == "__main__":
    run()
