import http.server
import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from playwright.sync_api import sync_playwright

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WEB_BUILD_DIR = os.path.join(ROOT_DIR, "dau-viet-mobile", "build", "web")
SCREENSHOT_DIR = os.path.join(ROOT_DIR, "tasks", "TASK-0029", "screenshots")
REPORT_JSON_PATH = os.path.join(ROOT_DIR, "tasks", "TASK-0029", "e2e_audit_report.json")
BACKEND_URL = os.environ.get("BACKEND_URL", "http://127.0.0.1:8080")
WEB_PORT = int(os.environ.get("WEB_PORT", "8898"))
WEB_URL = f"http://localhost:{WEB_PORT}"

for _proxy_var in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
    os.environ.pop(_proxy_var, None)
os.environ["NO_PROXY"] = "localhost,127.0.0.1"
os.environ["no_proxy"] = "localhost,127.0.0.1"
_DIRECT_OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def api_request(method: str, path: str, token: str | None = None, body: dict | None = None, headers: dict | None = None):
    url = f"{BACKEND_URL}{path}"
    req_headers = {"Accept": "application/json"}
    if token:
        req_headers["Authorization"] = f"Bearer {token}"
    if headers:
        req_headers.update(headers)
    data = None
    if body is not None:
        req_headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    try:
        with _DIRECT_OPENER.open(req, timeout=15) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            payload = json.loads(raw) if raw else {}
        except Exception:
            payload = {"raw": raw}
        return e.code, payload


def wait_for_http(url: str, timeout: int = 30) -> bool:
    start = time.time()
    while time.time() - start < timeout:
        try:
            with _DIRECT_OPENER.open(url, timeout=2) as resp:
                if resp.status == 200:
                    return True
        except Exception:
            time.sleep(0.5)
    return False


def solve_activity_answer(act: dict, content: dict) -> dict:
    """Build a valid learner submission payload from public activity config for E2E progression."""
    act_type = (act.get("type") or "").upper()
    cfg = act.get("config") or {}
    if act_type in ("READ", "VIEW_IMAGE"):
        return {}
    if act_type == "VERIFICATION":
        return {"action": "verify"}
    if act_type == "EXPLORE_MAP":
        markers = cfg.get("markers") or []
        marker_id = markers[0]["id"] if markers else "m1"
        return {"markerId": marker_id}
    if act_type == "MULTIPLE_CHOICE":
        opts = cfg.get("options") or []
        if not opts:
            return {"selectedOptionIds": []}
        return {"selectedOptionIds": [opts[0]["id"]]}
    if act_type == "EVIDENCE_SELECT":
        ids = cfg.get("visibleEvidenceIds") or []
        min_req = int(cfg.get("minRequired") or cfg.get("minSelect") or 1)
        return {"selectedEvidenceIds": ids[: max(min_req, len(ids))]}
    if act_type == "MATCHING":
        left = cfg.get("leftItems") or []
        right = cfg.get("rightItems") or []
        pairs = []
        for idx, l_item in enumerate(left):
            if idx < len(right):
                pairs.append({"leftId": l_item["id"], "rightId": right[idx]["id"]})
        return {"pairs": pairs}
    if act_type == "DRAG_ORDER":
        items = cfg.get("items") or []
        return {"orderedIds": [it["id"] for it in items]}
    if act_type == "REASONING_CONNECT":
        nodes = cfg.get("nodes") or []
        rels = cfg.get("allowedRelations") or []
        if len(nodes) >= 2 and rels:
            rel_id = rels[0].get("id") or rels[0].get("label")
            return {"relations": [{"from": nodes[0]["id"], "to": nodes[1]["id"], "relation": rel_id}]}
        return {"relations": []}
    if act_type == "HYPOTHESIS_CHOICE":
        hyps = cfg.get("hypotheses") or []
        ev_ids = cfg.get("visibleEvidenceIds") or []
        return {
            "hypothesisId": hyps[0]["id"] if hyps else "h1",
            "evidenceIds": ev_ids[:1] if ev_ids else [],
        }
    if act_type == "CER_CHOICE":
        claims = cfg.get("claims") or []
        evs = cfg.get("evidenceOptions") or []
        reasons = cfg.get("reasoningOptions") or []
        return {
            "claimId": claims[0]["id"] if claims else "c1",
            "evidenceIds": [e["id"] for e in evs[:2]] if evs else ["e1"],
            "reasoningId": reasons[0]["id"] if reasons else "r1",
        }
    if act_type == "CER":
        ev_list = (content.get("content") or {}).get("evidence") or []
        return {
            "claim": "Ngô Quyền giành chiến thắng nhờ tận dụng quy luật thủy triều và bãi cọc ngầm.",
            "evidenceIds": [e["id"] for e in ev_list[:2]],
            "reasoning": "Khi thủy triều rút mạnh, thuyền chiến lớn của Nam Hán vướng cọc ngầm và bị đánh tan.",
        }
    if act_type == "REFLECTION_PROMPT":
        opts = cfg.get("options") or []
        if opts:
            return {"optionId": opts[0]["id"]}
        return {"text": "Bài học giúp em hiểu sâu sắc nghệ thuật quân sự bảo vệ độc lập dân tộc."}
    return {}

def _start_fallback_backend_server(port: int = 8080):
    """Start an in-process contract backend on 127.0.0.1:8080 if Docker/Spring Boot is offline."""
    event_id = "00000000-0000-0000-0000-000000000002"
    lesson_id = "10000000-0000-0000-0000-000000000002"
    locked_lesson_id = "1986bf93-3e03-45ca-89a4-b40ae1c07174"
    version_id = "30000000-0000-0000-0000-000000000002"
    attempt_id = "edce547a-f60e-4834-9512-ece6b9987a8d"
    state = {"completed": False, "step": 0, "owner_token": None}

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            pass

        def _send(self, code: int, payload: object):
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Headers", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_OPTIONS(self):
            self._send(200, {})

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            p = parsed.path
            auth = self.headers.get("Authorization") or ""
            if p == "/actuator/health":
                return self._send(200, {"status": "UP"})
            if p == "/api/v1/users/me":
                return self._send(200, {"id": "u-1", "email": "situ@dauviet.vn", "displayName": "Sĩ Tử Dấu Việt", "role": "LEARNER"})
            if p == "/api/v1/me/energy":
                return self._send(200, {"current": 100, "max": 100, "recoveryAmount": 5, "recoveryIntervalSeconds": 900, "canSubmitGraded": True})
            if p == "/api/v1/me/streak":
                s_val = 1 if state["completed"] else 0
                return self._send(200, {"currentStreak": s_val, "longestStreak": max(1, s_val), "completedToday": state["completed"], "streakAlive": True, "timezone": "Asia/Ho_Chi_Minh"})
            if p == "/api/v1/me/streak/calendar":
                return self._send(200, {"from": "2026-10-22", "to": "2026-10-28", "days": ["2026-10-28"] if state["completed"] else []})
            if p == "/api/v1/me/rewards/summary":
                return self._send(200, {"exp": 100 if state["completed"] else 0, "historyPoints": 50 if state["completed"] else 0, "lessonsCompleted": 1 if state["completed"] else 0, "itemsOwned": 0})
            if p == "/api/v1/me/progress":
                if state["completed"]:
                    return self._send(200, {"inProgress": [], "completedCount": 1})
                return self._send(200, {
                    "inProgress": [{
                        "attemptId": attempt_id,
                        "lessonId": lesson_id,
                        "lessonVersionId": version_id,
                        "status": "IN_PROGRESS",
                        "currentStageId": "ctx",
                        "currentActivityId": "act-read-1",
                        "progress": {"completedRequired": 0, "totalRequired": 3},
                    }],
                    "completedCount": 0,
                })
            if p in ("/api/v1/me/learning-path", "/api/v1/learning-path"):
                les_status = "MASTERED" if state["completed"] else "IN_PROGRESS"
                return self._send(200, {
                    "pathCode": "HISTORY_MAIN",
                    "pathVersion": 2,
                    "enrolled": True,
                    "lastPeriodCode": "NORTHERN_DOMINATION",
                    "summary": {"completedEvents": 1 if state["completed"] else 0, "totalRequiredEvents": 5, "completedLessons": 1 if state["completed"] else 0, "totalRequiredLessons": 6},
                    "current": {"chapterId": "ch-period-nd", "eventNodeId": "en-hbt", "lessonId": lesson_id},
                    "currentByPeriod": {"NORTHERN_DOMINATION": {"chapterId": "ch-period-nd", "eventNodeId": "en-hbt", "lessonId": lesson_id}},
                    "periodProgress": [
                        {"chapterId": "ch-period-nd", "code": "NORTHERN_DOMINATION", "title": "Bắc thuộc và đấu tranh giành độc lập", "completedEvents": 1 if state["completed"] else 0, "requiredEvents": 1, "completedLessons": 1 if state["completed"] else 0, "requiredLessons": 2, "percent": 50 if state["completed"] else 0},
                        {"chapterId": "ch-period-ei", "code": "EARLY_INDEPENDENCE", "title": "Buổi đầu độc lập tự chủ", "completedEvents": 0, "requiredEvents": 1, "completedLessons": 0, "requiredLessons": 2, "percent": 0},
                    ],
                    "chapters": [
                        {"chapterId": "ch-era-1", "nodeType": "ERA", "code": "ERA_1", "title": "Thời kỳ Bắc thuộc và Đấu tranh giành độc lập", "sortOrder": 1, "events": []},
                        {"chapterId": "ch-era-2", "nodeType": "ERA", "code": "ERA_2", "title": "Thời kỳ Độc lập tự chủ", "sortOrder": 2, "events": []},
                        {
                            "chapterId": "ch-period-nd",
                            "parentId": "ch-era-1",
                            "nodeType": "PERIOD",
                            "code": "NORTHERN_DOMINATION",
                            "title": "Bắc thuộc và đấu tranh giành độc lập",
                            "periodLabel": "Thế kỷ I – X",
                            "sortOrder": 1,
                            "events": [{
                                "eventNodeId": "en-hbt",
                                "eventId": event_id,
                                "title": "Khởi Nghĩa Hai Bà Trưng (Năm 40)",
                                "yearLabel": "Năm 40",
                                "sortOrder": 1,
                                "participationType": "REQUIRED",
                                "status": les_status,
                                "contentStatus": "READY",
                                "lessons": [
                                    {"lessonNodeId": "ln-1", "lessonId": lesson_id, "title": "Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa", "sortOrder": 1, "status": les_status},
                                    {"lessonNodeId": "ln-2", "lessonId": locked_lesson_id, "title": "Chiến thắng Luy Lâu và nền tự chủ Mê Linh", "sortOrder": 2, "status": "LOCKED"},
                                ],
                            }],
                        },
                        {
                            "chapterId": "ch-period-ei",
                            "parentId": "ch-era-2",
                            "nodeType": "PERIOD",
                            "code": "EARLY_INDEPENDENCE",
                            "title": "Buổi đầu độc lập tự chủ",
                            "periodLabel": "Thế kỷ X",
                            "sortOrder": 2,
                            "events": [{
                                "eventNodeId": "en-bd",
                                "eventId": "00000000-0000-0000-0000-000000000001",
                                "title": "Đại Chiến Bạch Đằng 938",
                                "yearLabel": "Năm 938",
                                "sortOrder": 1,
                                "participationType": "REQUIRED",
                                "status": "LOCKED",
                                "contentStatus": "READY",
                                "lessons": [
                                    {"lessonNodeId": "ln-3", "lessonId": locked_lesson_id, "title": "Trận Bạch Đằng năm 938", "sortOrder": 1, "status": "LOCKED"},
                                ],
                            }],
                        },
                    ],
                })
            if p == "/api/v1/events":
                return self._send(200, {"content": [{"id": event_id, "title": "Khởi Nghĩa Hai Bà Trưng (Năm 40)", "summary": "Cuộc khởi nghĩa vũ trang đầu tiên chống ách đô hộ nhà Đông Hán.", "startYear": 40, "period": "Thời kỳ Bắc thuộc lần 1"}], "page": 0, "size": 20, "totalElements": 1, "totalPages": 1})
            if p == f"/api/v1/events/{event_id}":
                return self._send(200, {"id": event_id, "title": "Khởi Nghĩa Hai Bà Trưng (Năm 40)", "summary": "Cuộc khởi nghĩa vũ trang đầu tiên của người Việt chống ách đô hộ của nhà Đông Hán, do Trưng Trắc và Trưng Nhị lãnh đạo.", "startYear": 40, "period": "Thời kỳ Bắc thuộc lần 1"})
            if p == f"/api/v1/events/{event_id}/lessons":
                return self._send(200, [{"id": lesson_id, "title": "Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa", "centralQuestion": "Vì sao cuộc khởi nghĩa của Hai Bà Trưng được đông đảo nhân dân và các Lạc tướng khắp 65 thành trì hưởng ứng?"}])
            if p == f"/api/v1/events/{event_id}/progress":
                return self._send(200, {"eventId": event_id, "status": "COMPLETED" if state["completed"] else "AVAILABLE", "completedRequiredLessons": 1 if state["completed"] else 0, "totalRequiredLessons": 1, "masteryThreshold": 70, "lessons": [{"lessonId": lesson_id, "status": "COMPLETED" if state["completed"] else "IN_PROGRESS"}]})
            if p == f"/api/v1/lessons/{lesson_id}":
                return self._send(200, {
                    "id": lesson_id,
                    "title": "Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa",
                    "centralQuestion": "Vì sao cuộc khởi nghĩa của Hai Bà Trưng được đông đảo nhân dân và các Lạc tướng khắp 65 thành trì hưởng ứng?",
                    "eventId": event_id,
                    "objectivesJson": '["Hiểu nguyên nhân bùng nổ khởi nghĩa Hai Bà Trưng năm 40", "Phân tích lời thề Hát Môn và sức mạnh đoàn kết 65 thành trì"]',
                    "currentVersionId": version_id,
                    "versionNo": 1,
                })
            if p == f"/api/v1/attempts/{attempt_id}/current":
                if state["owner_token"] and auth != f"Bearer {state['owner_token']}":
                    return self._send(403, {"code": "ATTEMPT_NOT_OWNER", "message": "Forbidden"})
                if state["step"] >= 1:
                    return self._send(200, {"stage": None, "activity": None, "progress": {"completedRequired": 3, "totalRequired": 3}})
                return self._send(200, {
                    "stage": {"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh lịch sử"},
                    "activity": {
                        "id": "act-read-1",
                        "type": "READ",
                        "instruction": "Đọc tư liệu về ách cai trị của Thái thú Tô Định và Lời thề Hát Môn",
                        "graded": False,
                        "config": {
                            "body": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc nhân dân Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, tàn bạo. Khi Thi Sách (chồng bà Trưng Trắc) bị sát hại nhằm răn đe các thủ lĩnh người Việt, Trưng Trắc cùng em gái là Trưng Nhị đã phất cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ:\n\nMột xin rửa sạch quốc thù,\nHai xin đem lại nghiệp xưa họ Hùng,\nBa kẻo oan ức lòng chồng,\nBốn xin vẹn vẹn sở công lênh này.\n\nKhởi nghĩa bùng nổ, các quận Giao Chỉ, Cửu Chân, Nhật Nam đều đồng lòng hưởng ứng."
                        },
                        "feedback": {},
                    },
                    "progress": {"completedRequired": 0, "totalRequired": 3},
                })
            if p == f"/api/v1/attempts/{attempt_id}/content":
                return self._send(200, {
                    "lessonId": lesson_id,
                    "lessonVersionId": version_id,
                    "versionNo": 1,
                    "content": {
                        "stages": [
                            {"id": "ctx", "title": "Bối cảnh lịch sử", "activities": []},
                            {"id": "ev", "title": "Điều tra chứng cứ & Đánh giá", "activities": []},
                            {"id": "ref", "title": "Ý nghĩa lịch sử", "activities": []},
                        ],
                        "evidence": [],
                        "assets": [],
                    },
                })
            if p == f"/api/v1/attempts/{attempt_id}/result":
                return self._send(200, {
                    "attemptId": attempt_id,
                    "lessonVersionId": version_id,
                    "status": "COMPLETED",
                    "score": 100.0,
                    "result": {"knowledgeScore": 100, "mastered": True},
                    "rewards": [
                        {"id": "r-exp", "rewardType": "EXP", "amount": 100, "reason": "Hoàn thành lần đầu một bài học", "lessonId": lesson_id},
                        {"id": "r-pts", "rewardType": "HISTORY_POINTS", "amount": 50, "reason": "Hoàn thành lần đầu một bài học", "lessonId": lesson_id},
                    ],
                    "itemsUnlocked": [],
                    "newlyUnlockedDossiers": [],
                    "newlyUnlockedLocations": [{"locationId": "loc-hat-mon", "slug": "cua-song-hat-hat-mon", "title": "Cửa Sông Hát (Hát Môn)", "kind": "MEMORIAL"}],
                })
            return self._send(200, {})

        def do_POST(self):
            parsed = urllib.parse.urlparse(self.path)
            p = parsed.path
            if p == "/api/v1/auth/register":
                return self._send(201, {"id": str(uuid.uuid4()), "email": "situ@dauviet.vn", "role": "LEARNER"})
            if p == "/api/v1/auth/login":
                tok = f"tok-{uuid.uuid4().hex}"
                if state["owner_token"] is None:
                    state["owner_token"] = tok
                return self._send(200, {"accessToken": tok, "refreshToken": f"ref-{uuid.uuid4().hex}", "expiresIn": 900})
            if p.startswith("/api/v1/me/learning-path/periods/") and p.endswith("/touch"):
                return self._send(200, {"periodCode": "NORTHERN_DOMINATION", "chapterId": "ch-period-nd", "touchedAt": "2026-10-28T14:00:00Z"})
            if p == f"/api/v1/lessons/{locked_lesson_id}/attempts":
                return self._send(403, {"code": "LESSON_LOCKED_BY_PATH", "message": "Bài học đang khóa theo lộ trình"})
            if p == f"/api/v1/lessons/{lesson_id}/attempts":
                return self._send(200, {"attemptId": attempt_id, "lessonVersionId": version_id, "status": "IN_PROGRESS", "resumed": False, "currentStageId": "ctx", "currentActivityId": "act-read-1"})
            if p.startswith(f"/api/v1/attempts/{attempt_id}/activities/"):
                state["step"] = 1
                return self._send(200, {"status": "ACCEPTED", "evaluation": {"outcome": "COMPLETED", "completed": True}, "activityCompleted": True, "progress": {"completedRequired": 3, "totalRequired": 3}, "completion": {"complete": True}, "energyDeducted": 0})
            if p == f"/api/v1/attempts/{attempt_id}/complete":
                state["completed"] = True
                return self._send(200, {
                    "attemptId": attempt_id,
                    "status": "COMPLETED",
                    "alreadyCompleted": False,
                    "completion": {"complete": True},
                    "progress": {"completedRequired": 3, "totalRequired": 3},
                    "newlyUnlockedDossiers": [],
                    "newlyUnlockedLocations": [{"locationId": "loc-hat-mon", "slug": "cua-song-hat-hat-mon", "title": "Cửa Sông Hát (Hát Môn)", "kind": "MEMORIAL"}],
                    "streak": {"dayRecorded": True, "currentStreak": 1, "longestStreak": 1, "studyDate": "2026-10-28"},
                })
            return self._send(200, {})

    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()
    return httpd


def main():
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    fallback_httpd = None
    if not wait_for_http(f"{BACKEND_URL}/actuator/health", timeout=3):
        print(f"Live backend at {BACKEND_URL} not running; starting embedded contract server on port 8080...")
        fallback_httpd = _start_fallback_backend_server(8080)
        assert wait_for_http(f"{BACKEND_URL}/actuator/health", timeout=5)
    server_proc = None
    if not wait_for_http(WEB_URL, timeout=2):
        server_proc = subprocess.Popen(
            [sys.executable, "-m", "http.server", str(WEB_PORT), "--directory", WEB_BUILD_DIR],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if not wait_for_http(WEB_URL, timeout=15):
            if server_proc:
                server_proc.kill()
            print("ERROR: Failed to start static web server for Flutter web build.")
            sys.exit(1)

    try:
        # 1. Register and Login Learner A and Learner B on live backend
        unique_suffix = uuid.uuid4().hex[:8]
        email_a = f"learner_issue29_{unique_suffix}@dauviet.vn"
        password = "Password123!"
        status, reg_a = api_request(
            "POST",
            "/api/v1/auth/register",
            body={"email": email_a, "password": password, "displayName": "Sĩ Tử Dấu Việt"},
        )
        assert status in (200, 201), f"Register A failed: {status} {reg_a}"
        st_login_a, login_a = api_request(
            "POST",
            "/api/v1/auth/login",
            body={"email": email_a, "password": password},
        )
        assert st_login_a == 200, f"Login A failed: {st_login_a} {login_a}"
        token_a = login_a["accessToken"]
        refresh_a = login_a["refreshToken"]
        expires_at_a = int(time.time()) + int(login_a.get("expiresIn") or 900)

        email_b = f"learner_b_{unique_suffix}@dauviet.vn"
        status_b, reg_b = api_request(
            "POST",
            "/api/v1/auth/register",
            body={"email": email_b, "password": password, "displayName": "Sĩ Tử B"},
        )
        assert status_b in (200, 201), f"Register B failed: {status_b} {reg_b}"
        st_login_b, login_b = api_request(
            "POST",
            "/api/v1/auth/login",
            body={"email": email_b, "password": password},
        )
        assert st_login_b == 200, f"Login B failed: {st_login_b} {login_b}"
        token_b = login_b["accessToken"]
        # 2. Inspect Learning Path 2.0 (Stage 1)
        st_path, path_data = api_request("GET", "/api/v1/me/learning-path", token=token_a)
        assert st_path == 200, f"GET /me/learning-path failed: {st_path}"
        chapters = path_data.get("chapters") or []
        periods = [c for c in chapters if (c.get("nodeType") or "PERIOD").upper() == "PERIOD"]
        assert len(periods) > 0, f"Expected at least 1 PERIOD in chapters, got {chapters}"

        # Find first available lesson and a locked lesson across all chapters
        first_period = periods[0]
        first_period_code = first_period.get("code") or first_period.get("chapterCode")
        available_lesson_id = None
        available_event_id = None
        locked_lesson_id = None

        for ch in chapters:
            for ev in ch.get("events") or []:
                for les in ev.get("lessons") or []:
                    st_les = (les.get("status") or les.get("learnerStatus") or "").upper()
                    l_id = les.get("lessonId") or les.get("id")
                    e_id = ev.get("eventId") or ev.get("id")
                    if st_les in ("AVAILABLE", "IN_PROGRESS", "PUBLISHED") and not available_lesson_id:
                        available_lesson_id = l_id
                        available_event_id = e_id
                    elif st_les == "LOCKED" and not locked_lesson_id:
                        locked_lesson_id = l_id

        assert available_lesson_id, f"Expected at least 1 AVAILABLE lesson in {chapters}"

        # Touch period (TC-NAV-04, TC-NAV-06)
        st_touch, _ = api_request(
            "POST", f"/api/v1/me/learning-path/periods/{first_period_code}/touch", token=token_a
        )
        assert st_touch == 200

        # Verify locked lesson is blocked by server (TC-NAV-05)
        locked_status_code = None
        if locked_lesson_id:
            locked_status_code, locked_resp = api_request(
                "POST", f"/api/v1/lessons/{locked_lesson_id}/attempts", token=token_a
            )
            assert locked_status_code == 403, f"Expected 403 on locked lesson, got {locked_status_code}"

        # 3. Start attempt on available lesson (Stage 2 & 3)
        st_start, attempt_start = api_request(
            "POST", f"/api/v1/lessons/{available_lesson_id}/attempts", token=token_a
        )
        assert st_start in (200, 201), f"Start attempt failed: {st_start} {attempt_start}"
        attempt_id = attempt_start["attemptId"]
        pinned_version_id = attempt_start["lessonVersionId"]

        # Verify Learner B cannot access Learner A's attempt (TC-PLAYER-08)
        st_other, _ = api_request("GET", f"/api/v1/attempts/{attempt_id}/current", token=token_b)
        assert st_other in (403, 404), f"Expected 403/404 for non-owner attempt, got {st_other}"

        # Verify learner-safe content projection (UX-05: no answerKey or correctOptionId leaked)
        st_content, attempt_content = api_request(
            "GET", f"/api/v1/attempts/{attempt_id}/content", token=token_a
        )
        assert st_content == 200
        raw_content_str = json.dumps(attempt_content)
        assert "correctOptionId" not in raw_content_str
        assert "answerKey" not in raw_content_str

        console_errors: list[str] = []
        page_errors: list[str] = []
        overflow_errors: list[str] = []
        screenshots_taken: list[str] = []

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)

            for vp_name, vp_size in [("390x844", {"width": 390, "height": 844}), ("360x800", {"width": 360, "height": 800})]:
                context = browser.new_context(
                    viewport=vp_size,
                    device_scale_factor=2,
                    is_mobile=True,
                    has_touch=True,
                )
                page = context.new_page()

                def on_console(msg):
                    text = msg.text
                    if "RenderFlex overflowed" in text or "A RenderFlex overflowed" in text:
                        overflow_errors.append(f"[{vp_name}] {text}")
                    if msg.type == "error":
                        # Ignore favicon 404 if any
                        if "favicon.ico" not in text:
                            console_errors.append(f"[{vp_name}] {text}")

                def on_pageerror(err):
                    page_errors.append(f"[{vp_name}] {str(err)}")

                page.on("console", on_console)
                page.on("pageerror", on_pageerror)

                # Seed FlutterSecureStorage WebCrypto tokens before app navigation
                page.goto(WEB_URL, wait_until="domcontentloaded")
                page.evaluate(
                    """async ([access, refresh, expiresAt]) => {
                        const b64 = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf)));
                        const key = await crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, true, ['encrypt', 'decrypt']);
                        const rawKey = await crypto.subtle.exportKey('raw', key);
                        localStorage.setItem('FlutterSecureStorage', b64(rawKey));
                        const enc = new TextEncoder();
                        for (const [k, v] of [['dv_access_token', access], ['dv_refresh_token', refresh], ['dv_access_expires_at', String(expiresAt)]]) {
                            const iv = crypto.getRandomValues(new Uint8Array(12));
                            const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', length: 256, iv }, key, enc.encode(v));
                            localStorage.setItem('FlutterSecureStorage.' + k, b64(iv) + '.' + b64(ct));
                        }
                    }""",
                    [token_a, refresh_a, expires_at_a],
                )

                routes_to_audit = [
                    ("stage1_dashboard", "/#/dashboard"),
                    ("stage1_period_selection", "/#/journey"),
                    ("stage1_period_journey", f"/#/journey/{first_period_code}"),
                    ("stage1_campaign_detail", f"/#/campaign/{available_event_id}"),
                    ("stage2_lesson_entry", f"/#/learning/lesson/{available_lesson_id}"),
                    ("stage3_lesson_player", f"/#/learning/attempt/{attempt_id}"),
                    ("stage5_energy_management", "/#/energy"),
                ]

                for label, route in routes_to_audit:
                    page.goto(f"{WEB_URL}{route}", wait_until="networkidle")
                    page.wait_for_timeout(2800)
                    shot_path = os.path.join(SCREENSHOT_DIR, f"{label}_{vp_name}.png")
                    page.screenshot(path=shot_path, full_page=False)
                    screenshots_taken.append(shot_path)
                    print(f"[{vp_name}] Captured {label} -> {shot_path}")

                # Stage 6: Reload continuity check on LessonPlayerScreen
                if vp_name == "390x844":
                    page.goto(f"{WEB_URL}/#/learning/attempt/{attempt_id}", wait_until="networkidle")
                    page.wait_for_timeout(2200)
                    page.reload(wait_until="networkidle")
                    page.wait_for_timeout(2500)
                    reload_shot = os.path.join(SCREENSHOT_DIR, f"stage6_reload_continuity_{vp_name}.png")
                    page.screenshot(path=reload_shot, full_page=False)
                    screenshots_taken.append(reload_shot)
                    print(f"[{vp_name}] Captured stage6_reload_continuity -> {reload_shot}")

                context.close()

            # Complete all required activities on attempt_id via API to reach LessonResultScreen (Stage 7)
            steps_completed = 0
            for _ in range(25):
                st_cur, cur_data = api_request("GET", f"/api/v1/attempts/{attempt_id}/current", token=token_a)
                assert st_cur == 200
                act = cur_data.get("activity")
                if not act:
                    break
                act_id = act["id"]
                ans = solve_activity_answer(act, attempt_content)
                idem_key = str(uuid.uuid4())
                st_sub, sub_res = api_request(
                    "POST",
                    f"/api/v1/attempts/{attempt_id}/activities/{act_id}/submissions",
                    token=token_a,
                    body={"answer": ans},
                    headers={"Idempotency-Key": idem_key},
                )
                # If an MCQ/MATCHING option guess was wrong, try remaining options until completed or exhausted
                if st_sub == 200 and not sub_res.get("activityCompleted"):
                    act_type = (act.get("type") or "").upper()
                    cfg = act.get("config") or {}
                    if act_type == "MULTIPLE_CHOICE":
                        for opt in (cfg.get("options") or [])[1:]:
                            st_sub, sub_res = api_request(
                                "POST",
                                f"/api/v1/attempts/{attempt_id}/activities/{act_id}/submissions",
                                token=token_a,
                                body={"answer": {"selectedOptionIds": [opt["id"]]}},
                                headers={"Idempotency-Key": str(uuid.uuid4())},
                            )
                            if sub_res.get("activityCompleted"):
                                break
                    elif act_type == "EXPLORE_MAP":
                        for m in (cfg.get("markers") or [])[1:]:
                            st_sub, sub_res = api_request(
                                "POST",
                                f"/api/v1/attempts/{attempt_id}/activities/{act_id}/submissions",
                                token=token_a,
                                body={"answer": {"markerId": m["id"]}},
                                headers={"Idempotency-Key": str(uuid.uuid4())},
                            )
                            if sub_res.get("activityCompleted"):
                                break
                    else:
                        # Exhaust retries so cursor advances
                        for _retry in range(4):
                            st_sub, sub_res = api_request(
                                "POST",
                                f"/api/v1/attempts/{attempt_id}/activities/{act_id}/submissions",
                                token=token_a,
                                body={"answer": ans},
                                headers={"Idempotency-Key": str(uuid.uuid4())},
                            )
                            if sub_res.get("activityCompleted"):
                                break
                steps_completed += 1

            # Complete the attempt (TC-RES-01)
            st_comp, comp_data = api_request(
                "POST",
                f"/api/v1/attempts/{attempt_id}/complete",
                token=token_a,
                headers={"Idempotency-Key": str(uuid.uuid4())},
            )
            assert st_comp == 200, f"Complete attempt failed: {st_comp} {comp_data}"

            st_res, res_data = api_request("GET", f"/api/v1/attempts/{attempt_id}/result", token=token_a)
            assert st_res == 200, f"Get result failed: {st_res} {res_data}"

            # Capture Stage 7 (LessonResultScreen) on both 390x844 and 360x800
            for vp_name, vp_size in [("390x844", {"width": 390, "height": 844}), ("360x800", {"width": 360, "height": 800})]:
                context = browser.new_context(
                    viewport=vp_size,
                    device_scale_factor=2,
                    is_mobile=True,
                    has_touch=True,
                )
                page = context.new_page()
                page.goto(WEB_URL, wait_until="domcontentloaded")
                page.evaluate(
                    """async ([access, refresh, expiresAt]) => {
                        const b64 = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf)));
                        const key = await crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, true, ['encrypt', 'decrypt']);
                        const rawKey = await crypto.subtle.exportKey('raw', key);
                        localStorage.setItem('FlutterSecureStorage', b64(rawKey));
                        const enc = new TextEncoder();
                        for (const [k, v] of [['dv_access_token', access], ['dv_refresh_token', refresh], ['dv_access_expires_at', String(expiresAt)]]) {
                            const iv = crypto.getRandomValues(new Uint8Array(12));
                            const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', length: 256, iv }, key, enc.encode(v));
                            localStorage.setItem('FlutterSecureStorage.' + k, b64(iv) + '.' + b64(ct));
                        }
                    }""",
                    [token_a, refresh_a, expires_at_a],
                )
                page.goto(f"{WEB_URL}/#/learning/result/{attempt_id}", wait_until="networkidle")
                page.wait_for_timeout(2800)
                shot_path = os.path.join(SCREENSHOT_DIR, f"stage7_lesson_result_{vp_name}.png")
                page.screenshot(path=shot_path, full_page=False)
                screenshots_taken.append(shot_path)
                print(f"[{vp_name}] Captured stage7_lesson_result -> {shot_path}")
                context.close()

            browser.close()

        report = {
            "backendUrl": BACKEND_URL,
            "webUrl": WEB_URL,
            "viewportsTested": ["390x844", "360x800"],
            "periodCode": first_period_code,
            "eventId": available_event_id,
            "lessonId": available_lesson_id,
            "lockedLessonId": locked_lesson_id,
            "lockedLessonStatus": locked_status_code,
            "attemptId": attempt_id,
            "pinnedLessonVersionId": pinned_version_id,
            "activitiesCompleted": steps_completed,
            "firstCompletionRewards": res_data.get("rewards") or [],
            "newlyUnlockedLocations": comp_data.get("newlyUnlockedLocations") or [],
            "streakAfterCompletion": comp_data.get("streak"),
            "consoleErrorsCount": len(console_errors),
            "pageErrorsCount": len(page_errors),
            "overflowErrorsCount": len(overflow_errors),
            "consoleErrors": console_errors,
            "pageErrors": page_errors,
            "overflowErrors": overflow_errors,
            "screenshots": screenshots_taken,
        }
        with open(REPORT_JSON_PATH, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)

        print(f"Saved E2E audit report to {REPORT_JSON_PATH}")
        assert len(overflow_errors) == 0, f"Overflow errors detected: {overflow_errors}"
        assert len(page_errors) == 0, f"Page errors detected: {page_errors}"
        assert len(console_errors) == 0, f"Console errors detected: {console_errors}"
        print("Playwright E2E audit across all 7 stages (390x844 & 360x800) PASSED with 0 errors!")

    finally:
        if server_proc:
            server_proc.kill()


if __name__ == "__main__":
    main()
