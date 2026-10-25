import os
import sys
import time
import subprocess
import urllib.request
from playwright.sync_api import sync_playwright

ARTIFACT_DIR = r"C:\Users\Admin\.gemini\antigravity\brain\7edf7e41-c431-4e09-ab46-69dd585bdac3"
PORT = 3000
BASE_URL = f"http://localhost:{PORT}"

def wait_for_server(url, timeout=30):
    start = time.time()
    while time.time() - start < timeout:
        try:
            with urllib.request.urlopen(url, timeout=2) as resp:
                if resp.status == 200:
                    return True
        except Exception:
            time.sleep(1)
    return False

def main():
    print(f"Starting verification against {BASE_URL}...")

    # Check if server is running
    server_proc = None
    if not wait_for_server(BASE_URL, timeout=2):
        print(f"Port {PORT} not responding, launching static web server...")
        web_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "dau-viet-mobile", "build", "web")
        server_proc = subprocess.Popen([sys.executable, "-m", "http.server", str(PORT), "--directory", web_dir])
        if not wait_for_server(BASE_URL, timeout=15):
            print("Failed to start web server")
            if server_proc:
                server_proc.kill()
            sys.exit(1)

    try:
        with sync_playwright() as p:
            # Emulate modern mobile device (412 x 915 - Google Pixel 7)
            browser = p.chromium.launch(headless=True)
            context = browser.new_context(
                viewport={"width": 412, "height": 915},
                device_scale_factor=2,
                is_mobile=True,
                has_touch=True,
            )
            page = context.new_page()

            # 1. Lesson Entry Screen
            print("1. Testing Lesson Entry Screen...")
            page.goto(f"{BASE_URL}/#/learning/lesson/00000000-0000-0000-0000-000000000001", wait_until="networkidle")
            page.wait_for_timeout(4000) # Wait for Flutter canvas to settle

            entry_shot = os.path.join(ARTIFACT_DIR, "playwright_screen1_lesson_entry.png")
            page.screenshot(path=entry_shot, full_page=False)
            print(f"   Saved: {entry_shot}")

            # 2. Homepage and Timeline Exploration
            print("2. Testing Journey Map / Timeline...")
            page.goto(f"{BASE_URL}/#/map", wait_until="networkidle")
            page.wait_for_timeout(3500)
            map_shot = os.path.join(ARTIFACT_DIR, "playwright_screen_journey_map.png")
            page.screenshot(path=map_shot, full_page=False)
            print(f"   Saved: {map_shot}")

            # 3. Lesson Player / Attempt
            print("3. Testing Lesson Player Screen...")
            page.goto(f"{BASE_URL}/#/learning/attempt/00000000-0000-0000-0000-000000000001", wait_until="networkidle")
            page.wait_for_timeout(3500)
            player_shot = os.path.join(ARTIFACT_DIR, "playwright_screen2_lesson_player.png")
            page.screenshot(path=player_shot, full_page=False)
            print(f"   Saved: {player_shot}")

            # 4. Lesson Result Screen
            print("4. Testing Lesson Result Screen...")
            page.goto(f"{BASE_URL}/#/learning/result/00000000-0000-0000-0000-000000000001", wait_until="networkidle")
            page.wait_for_timeout(3500)
            result_shot = os.path.join(ARTIFACT_DIR, "playwright_screen6_lesson_result.png")
            page.screenshot(path=result_shot, full_page=False)
            print(f"   Saved: {result_shot}")

            browser.close()
            print("Playwright E2E verification completed successfully!")

    finally:
        if server_proc:
            server_proc.kill()

if __name__ == "__main__":
    main()
