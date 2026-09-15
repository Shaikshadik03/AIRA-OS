"""
AIRA OS Desktop — System Tray Companion (Stage M / Stage 12)
Runs as a background notification tray icon on Windows, allowing instant access to:
- Emergency Automation Kill-Switch (Pause / Resume)
- Server Health Diagnostics & Status
- Web Dashboard
"""

import sys
import os
import webbrowser
import urllib.request
import json
import time

SERVER_URL = "http://127.0.0.1:8765"

def check_status():
    try:
        req = urllib.request.Request(f"{SERVER_URL}/automation/status")
        with urllib.request.urlopen(req, timeout=2) as resp:
            data = json.loads(resp.read().decode())
            return data.get("is_paused", False)
    except Exception:
        return None

def toggle_pause(pause: bool):
    endpoint = "pause" if pause else "resume"
    try:
        req = urllib.request.Request(f"{SERVER_URL}/automation/{endpoint}", data=b"{}", headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=3) as resp:
            print(f"[AIRA TRAY] Automation {endpoint}d successfully.")
    except Exception as e:
        print(f"[AIRA TRAY] Failed to send {endpoint} command: {e}")

def open_dashboard():
    webbrowser.open(f"{SERVER_URL}/health")

def main():
    print("=" * 50)
    print("  AIRA Desktop System Tray & Background Controller")
    print("=" * 50)
    
    try:
        import pystray
        from PIL import Image, ImageDraw
    except ImportError:
        print("\n  [INFO] 'pystray' or 'Pillow' not detected.")
        print("  To enable the graphical system tray icon, run:")
        print("    pip install pystray pillow\n")
        print("  Running lightweight command-line controller:")
        print("  Commands: [p]ause, [r]esume, [s]tatus, [d]ashboard, [q]uit")
        
        while True:
            cmd = input("  AIRA >> ").strip().lower()
            if cmd == "p":
                toggle_pause(True)
            elif cmd == "r":
                toggle_pause(False)
            elif cmd == "s":
                paused = check_status()
                print(f"  Status: {'PAUSED' if paused else 'ACTIVE' if paused is not None else 'SERVER OFFLINE'}")
            elif cmd == "d":
                open_dashboard()
            elif cmd == "q":
                break
        return

    # Create a clean procedural tray icon
    def create_image(is_paused):
        img = Image.new('RGBA', (64, 64), color=(0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        # Background circle
        color = (229, 57, 53) if is_paused else (76, 175, 80) # Red if paused, Green if active
        draw.ellipse([8, 8, 56, 56], fill=color)
        # White inner core
        draw.ellipse([24, 24, 40, 40], fill=(255, 255, 255))
        return img

    def on_pause(icon, item):
        toggle_pause(True)
        icon.icon = create_image(True)
        icon.title = "AIRA Desktop — Automations Paused"

    def on_resume(icon, item):
        toggle_pause(False)
        icon.icon = create_image(False)
        icon.title = "AIRA Desktop — Active"

    def on_dashboard(icon, item):
        open_dashboard()

    def on_exit(icon, item):
        icon.stop()

    menu = pystray.Menu(
        pystray.MenuItem("AIRA Health Dashboard", on_dashboard),
        pystray.MenuItem("Pause All Automations", on_pause),
        pystray.MenuItem("Resume Automations", on_resume),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Exit Companion", on_exit),
    )

    paused = check_status() or False
    icon = pystray.Icon(
        "AIRA OS",
        create_image(paused),
        "AIRA Desktop Agent",
        menu,
    )

    print("  ✅ System Tray Companion running in Windows notification area.")
    icon.run()

if __name__ == "__main__":
    main()
