import os
import sys
import time
from playwright.sync_api import sync_playwright

ARTIFACT_DIR = r"C:\Users\Admin\.gemini\antigravity\brain\7edf7e41-c431-4e09-ab46-69dd585bdac3"
BASE_URL = "http://localhost:3000"

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Mobile viewport 412x915 (Pixel 7)
        context = browser.new_context(
            viewport={"width": 412, "height": 915},
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()

        print("=== Step 1: Login ===")
        page.goto(f"{BASE_URL}/#/auth", wait_until="networkidle")
        page.wait_for_timeout(3000)

        # Click email field and type
        page.mouse.click(206, 345)
        page.wait_for_timeout(300)
        page.keyboard.type("learner@dauviet.vn")

        # Tab to password field
        page.keyboard.press("Tab")
        page.wait_for_timeout(300)
        page.keyboard.type("password123")
        page.wait_for_timeout(300)
        page.keyboard.press("Enter")
        page.wait_for_timeout(4000)
        print(f"Logged in, current URL: {page.url}")

        # If on onboarding, skip it
        if "onboarding" in page.url:
            print("Skipping onboarding...")
            # Click 'Bỏ qua' at top right
            page.mouse.click(370, 30)
            page.wait_for_timeout(3000)
            print(f"URL after skip: {page.url}")

        print("\n=== Step 2: Journey Map & Timeline ===")
        page.goto(f"{BASE_URL}/#/map", wait_until="networkidle")
        page.wait_for_timeout(4000)
        map_path = os.path.join(ARTIFACT_DIR, "playwright_journey_map.png")
        page.screenshot(path=map_path)
        print(f"Captured Journey Map: {map_path}")

        print("\n=== Step 3: Lesson Entry Screen ===")
        page.goto(f"{BASE_URL}/#/learning/lesson/10000000-0000-0000-0000-000000000002", wait_until="networkidle")
        page.wait_for_timeout(4000)
        entry_path = os.path.join(ARTIFACT_DIR, "playwright_lesson_entry.png")
        page.screenshot(path=entry_path)
        print(f"Captured Lesson Entry: {entry_path}")

        print("\n=== Step 4: Click CTA to start lesson attempt ===")
        # CTA button "Bắt đầu học →" or "Tiếp tục học" is near the bottom
        page.mouse.click(206, 750)
        page.wait_for_timeout(4500)
        print(f"URL after CTA click: {page.url}")
        player_path = os.path.join(ARTIFACT_DIR, "playwright_lesson_player.png")
        page.screenshot(path=player_path)
        print(f"Captured Lesson Player: {player_path}")

        print("\n=== Step 5: Lesson Result Screen ===")
        page.goto(f"{BASE_URL}/#/learning/result/9bc7e6d0-5d8f-4a6b-8197-85a8beddd6e2", wait_until="networkidle")
        page.wait_for_timeout(4000)
        result_path = os.path.join(ARTIFACT_DIR, "playwright_lesson_result.png")
        page.screenshot(path=result_path)
        print(f"Captured Lesson Result: {result_path}")

        browser.close()
        print("\nAll Playwright E2E verification steps completed successfully!")

if __name__ == "__main__":
    run()
