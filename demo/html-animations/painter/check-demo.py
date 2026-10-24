# -*- coding: utf-8 -*-
"""Gate check for bach-dang-938-demo.html — mojibake + banned tokens."""
import os
import sys

F = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "bach-dang-938-demo.html")

# Mojibake signatures: UTF-8 Vietnamese bytes mis-decoded as ANSI produce these
# two/three-char runs. We test the actual mojibake strings directly.
MOJIBAKE = [
    "áº",   # áº
    "á»",   # á»
    "á»§", # á»§
    "Ă",          # Ă
    "Â·",   # Â·
    "â€",   # â€
    "Đ·",   # Đ·
    "Đá",   # Đá (uppercase Đ + á)
    "Ngô ", # "Ngô " misread can flip — but Ngô itself is fine, skip
]
MOJIBAKE = MOJIBAKE[:-1]  # drop the questionable one

BANNED = [
    "fetch(", "XMLHttpRequest", "createObjectURL", "new Worker",
    "localStorage", "sessionStorage", "indexedDB", "caches.open",
    "serviceWorker", "WebSocket", "EventSource", "RTCPeerConnection",
    "sendBeacon", "ReportingObserver", "window.open", "location.assign",
    "location.replace", "top.location", "parent.location", "import(",
    "<script src", "<link href", "<iframe", "<form", "<object",
    "<embed", "<applet", "<base href", "http-equiv=\"refresh\"",
]

def main():
    with open(F, "r", encoding="utf-8") as f:
        txt = f.read()

    bad = [m for m in MOJIBAKE if m in txt]
    hits = [b for b in BANNED if b in txt]

    size = os.path.getsize(F)
    ok = not bad and not hits and size < 15 * 1024 * 1024

    print("file:", F)
    print("size:", size, "bytes")
    if bad:
        print("MOJIBAKE FOUND:", bad)
    else:
        print("mojibake: clean")
    if hits:
        print("BANNED TOKENS:", hits)
    else:
        print("banned tokens: none")
    print("size<15MB:", size < 15 * 1024 * 1024)
    print("PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
