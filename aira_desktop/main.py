"""
AIRA Desktop Agent — Main FastAPI Server
Runs on your Windows laptop and accepts commands from the AIRA Android app
over your home Wi-Fi or Ngrok tunnel.

Usage:
    python main.py

Default: Listens on http://0.0.0.0:8765
"""

import os
import socket
import hashlib
import base64
import shutil
import webbrowser
import urllib.parse
from fastapi import FastAPI, HTTPException, Depends, WebSocket, WebSocketDisconnect, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional
import uvicorn

import mouse_control
import system_control
import screen_capture
import app_launcher
import file_manager
import terminal_runner
import clipboard_sync
import agent_runner

# ── Config ────────────────────────────────────────────────────────────────

# Change this PIN to anything you want. Your phone must send this to connect.
AIRA_PIN = os.environ.get("AIRA_PIN", "123456")
PORT = int(os.environ.get("AIRA_PORT", 8765))
AGENT_VERSION = "4.2.0"

agent_engine = agent_runner.AgentRunner()

app = FastAPI(
    title="AIRA Desktop Agent",
    description="Autonomous Agentic Laptop Controller for AIRA OS.",
    version=AGENT_VERSION,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Auth ──────────────────────────────────────────────────────────────────

def verify_pin(x_aira_pin: Optional[str] = Header(None, alias="X-AIRA-PIN")):
    """PIN-based authentication via X-AIRA-PIN HTTP header."""
    if x_aira_pin != AIRA_PIN:
        raise HTTPException(status_code=401, detail="Invalid AIRA PIN. Check your PIN in Settings.")
    return True


# ── Request Models ────────────────────────────────────────────────────────

class MouseMoveRequest(BaseModel):
    dx: int = 0
    dy: int = 0

class MouseClickRequest(BaseModel):
    x: Optional[int] = None
    y: Optional[int] = None
    button: str = "left"  # left, right, double

class TypeTextRequest(BaseModel):
    text: str

class HotkeyRequest(BaseModel):
    keys: list[str]  # e.g. ["ctrl", "c"]

class ScrollRequest(BaseModel):
    amount: int  # positive = up, negative = down

class VolumeRequest(BaseModel):
    level: int  # 0-100

class BrightnessRequest(BaseModel):
    level: int  # 0-100

class AppRequest(BaseModel):
    app_name: str

class CommandRequest(BaseModel):
    command: str
    working_dir: Optional[str] = None

class ClipboardRequest(BaseModel):
    text: str

class FileBrowseRequest(BaseModel):
    path: Optional[str] = None

class FileOpenRequest(BaseModel):
    path: str

class ShutdownRequest(BaseModel):
    delay_seconds: int = 10

class QuickNoteRequest(BaseModel):
    title: str = "AIRA_Note"
    content: str

class WebSearchRequest(BaseModel):
    query: str

class AgentTaskRequest(BaseModel):
    prompt: str
    steps: Optional[list] = None
    custom_groq_key: Optional[str] = None


# ── Info Endpoint ─────────────────────────────────────────────────────────

@app.get("/")
def root():
    """Health check — confirms the AIRA Desktop Agent is running."""
    return {
        "status": "AIRA Desktop Agent Online",
        "version": AGENT_VERSION,
        "hostname": socket.gethostname(),
        "screen": mouse_control.get_screen_size(),
    }

@app.get("/info")
def info(auth: bool = Depends(verify_pin)):
    """Return full system info (requires PIN)."""
    stats = system_control.get_system_stats()
    return {
        "hostname": socket.gethostname(),
        "screen": mouse_control.get_screen_size(),
        "mouse": mouse_control.get_mouse_position(),
        "stats": stats,
        "version": AGENT_VERSION,
    }


# ── Mouse & Keyboard ──────────────────────────────────────────────────────

@app.post("/mouse/move")
def mouse_move(req: MouseMoveRequest, auth: bool = Depends(verify_pin)):
    mouse_control.move_mouse(req.dx, req.dy)
    return {"success": True}

@app.post("/mouse/click")
def mouse_click(req: MouseClickRequest, auth: bool = Depends(verify_pin)):
    if req.button == "right":
        mouse_control.right_click(req.x, req.y)
    elif req.button == "double":
        mouse_control.double_click(req.x, req.y)
    else:
        mouse_control.left_click(req.x, req.y)
    return {"success": True}

@app.post("/mouse/scroll")
def mouse_scroll(req: ScrollRequest, auth: bool = Depends(verify_pin)):
    mouse_control.scroll(req.amount)
    return {"success": True}

@app.post("/keyboard/type")
def keyboard_type(req: TypeTextRequest, auth: bool = Depends(verify_pin)):
    mouse_control.type_text(req.text)
    return {"success": True, "typed": req.text}

@app.post("/keyboard/hotkey")
def keyboard_hotkey(req: HotkeyRequest, auth: bool = Depends(verify_pin)):
    mouse_control.hotkey(*req.keys)
    return {"success": True, "hotkey": req.keys}

@app.post("/keyboard/press")
def keyboard_press(req: TypeTextRequest, auth: bool = Depends(verify_pin)):
    mouse_control.press_key(req.text)
    return {"success": True, "key": req.text}


# ── Screenshot ────────────────────────────────────────────────────────────

@app.get("/screen/capture")
def get_screenshot(quality: int = 55, scale: float = 0.45, auth: bool = Depends(verify_pin)):
    """Capture a screenshot and return it as base64 JPEG."""
    image_b64 = screen_capture.capture_screenshot(quality=quality, scale=scale)
    return {"success": True, "image": image_b64, "format": "jpeg"}


# ── System Control ────────────────────────────────────────────────────────

@app.post("/system/volume")
def set_vol(req: VolumeRequest, auth: bool = Depends(verify_pin)):
    return system_control.set_volume(req.level)

@app.get("/system/volume")
def get_vol(auth: bool = Depends(verify_pin)):
    return {"volume": system_control.get_volume()}

@app.post("/system/volume/mute")
def mute(auth: bool = Depends(verify_pin)):
    return system_control.mute_volume()

@app.post("/system/volume/up")
def vol_up(auth: bool = Depends(verify_pin)):
    return system_control.volume_up()

@app.post("/system/volume/down")
def vol_down(auth: bool = Depends(verify_pin)):
    return system_control.volume_down()

@app.post("/system/brightness")
def set_bright(req: BrightnessRequest, auth: bool = Depends(verify_pin)):
    return system_control.set_brightness(req.level)

@app.get("/system/brightness")
def get_bright(auth: bool = Depends(verify_pin)):
    return {"brightness": system_control.get_brightness()}

@app.post("/system/lock")
def lock(auth: bool = Depends(verify_pin)):
    return system_control.lock_screen()

@app.post("/system/sleep")
def sleep(auth: bool = Depends(verify_pin)):
    return system_control.sleep_laptop()

@app.post("/system/shutdown")
def shutdown(req: ShutdownRequest, auth: bool = Depends(verify_pin)):
    return system_control.shutdown_laptop(req.delay_seconds)

@app.post("/system/restart")
def restart(req: ShutdownRequest, auth: bool = Depends(verify_pin)):
    return system_control.restart_laptop(req.delay_seconds)

@app.post("/system/cancel_shutdown")
def cancel_shut(auth: bool = Depends(verify_pin)):
    return system_control.cancel_shutdown()

@app.get("/system/stats")
def get_stats(auth: bool = Depends(verify_pin)):
    return system_control.get_system_stats()


# ── App Launcher ──────────────────────────────────────────────────────────

@app.post("/apps/open")
def open_app(req: AppRequest, auth: bool = Depends(verify_pin)):
    return app_launcher.open_app(req.app_name)

@app.post("/apps/close")
def close_app(req: AppRequest, auth: bool = Depends(verify_pin)):
    return app_launcher.close_app(req.app_name)

@app.get("/apps/list")
def list_apps(auth: bool = Depends(verify_pin)):
    return {"apps": app_launcher.list_running_apps()}


# ── File Manager ──────────────────────────────────────────────────────────

@app.post("/files/list")
def list_files(req: FileBrowseRequest, auth: bool = Depends(verify_pin)):
    return file_manager.list_directory(req.path)

@app.get("/files/quick_access")
def quick_access(auth: bool = Depends(verify_pin)):
    return file_manager.get_quick_access_paths()

@app.post("/files/open")
def open_file(req: FileOpenRequest, auth: bool = Depends(verify_pin)):
    return file_manager.open_file(req.path)

@app.post("/files/read")
def read_file(req: FileOpenRequest, auth: bool = Depends(verify_pin)):
    return file_manager.read_text_file(req.path)


# ── Terminal ──────────────────────────────────────────────────────────────

@app.post("/terminal/run")
def run_terminal(req: CommandRequest, auth: bool = Depends(verify_pin)):
    return terminal_runner.run_command(req.command, req.working_dir)


# ── Clipboard ─────────────────────────────────────────────────────────────

@app.get("/clipboard")
def get_clip(auth: bool = Depends(verify_pin)):
    return clipboard_sync.get_clipboard()

@app.post("/clipboard")
def set_clip(req: ClipboardRequest, auth: bool = Depends(verify_pin)):
    return clipboard_sync.set_clipboard(req.text)


# ── Autonomous Digital Agent Endpoints ────────────────────────────────────

@app.post("/auto/organize_downloads")
def organize_downloads(auth: bool = Depends(verify_pin)):
    """Automatically sorts files in Downloads folder into categorized folders."""
    downloads_path = os.path.join(os.path.expanduser("~"), "Downloads")
    if not os.path.exists(downloads_path):
        return {"success": False, "error": "Downloads folder not found"}

    categories = {
        "PDFs": [".pdf"],
        "Images": [".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".bmp"],
        "Documents": [".docx", ".doc", ".txt", ".pptx", ".ppt", ".xlsx", ".xls", ".csv"],
        "Archives": [".zip", ".rar", ".7z", ".tar", ".gz"],
        "Code": [".py", ".dart", ".js", ".ts", ".html", ".css", ".json", ".cpp", ".java"],
        "Installers": [".exe", ".msi", ".apk"],
        "Media": [".mp4", ".mkv", ".mp3", ".wav", ".avi", ".mov"],
    }

    moved_count = 0
    moved_details = []

    for filename in os.listdir(downloads_path):
        file_path = os.path.join(downloads_path, filename)
        if os.path.isdir(file_path):
            continue

        ext = os.path.splitext(filename)[1].lower()
        for folder_name, extensions in categories.items():
            if ext in extensions:
                target_dir = os.path.join(downloads_path, folder_name)
                os.makedirs(target_dir, exist_ok=True)
                target_path = os.path.join(target_dir, filename)
                try:
                    shutil.move(file_path, target_path)
                    moved_count += 1
                    moved_details.append(f"{filename} → {folder_name}/")
                except Exception as e:
                    pass
                break

    return {
        "success": True,
        "moved_count": moved_count,
        "details": moved_details,
        "message": f"Organized {moved_count} files in Downloads folder.",
    }

@app.post("/auto/quick_note")
def save_quick_note(req: QuickNoteRequest, auth: bool = Depends(verify_pin)):
    """Saves a markdown note to user's Desktop."""
    desktop_path = os.path.join(os.path.expanduser("~"), "Desktop")
    if not os.path.exists(desktop_path):
        desktop_path = os.path.expanduser("~")

    sanitized_title = "".join(c for c in req.title if c.isalnum() or c in (' ', '_', '-')).rstrip()
    if not sanitized_title:
        sanitized_title = "AIRA_Note"

    filename = f"{sanitized_title}.md"
    file_path = os.path.join(desktop_path, filename)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(req.content)

    return {
        "success": True,
        "path": file_path,
        "message": f"Note saved to Desktop as {filename}",
    }

@app.post("/auto/web_search")
def auto_web_search(req: WebSearchRequest, auth: bool = Depends(verify_pin)):
    """Opens browser directly to search query or URL."""
    q = req.query.strip()
    if q.startswith("http://") or q.startswith("https://"):
        url = q
    else:
        url = f"https://www.google.com/search?q={urllib.parse.quote_plus(q)}"
    
    webbrowser.open(url)
    return {
        "success": True,
        "url": url,
        "message": f"Opened search in browser: {q}",
    }


# ── Autonomous Multi-Step Agent Endpoints ─────────────────────────────────

@app.post("/agent/plan")
def agent_plan(req: AgentTaskRequest, auth: bool = Depends(verify_pin)):
    """Decomposes a user goal into an atomic step-by-step execution plan."""
    if req.custom_groq_key:
        engine = agent_runner.AgentRunner(groq_api_key=req.custom_groq_key)
    else:
        engine = agent_engine

    steps = engine.plan_task(req.prompt)
    return {
        "success": True,
        "prompt": req.prompt,
        "total_steps": len(steps),
        "steps": steps,
    }


@app.post("/agent/execute")
def agent_execute(req: AgentTaskRequest, auth: bool = Depends(verify_pin)):
    """Plans and executes an autonomous multi-step workflow on this laptop."""
    if req.custom_groq_key:
        engine = agent_runner.AgentRunner(groq_api_key=req.custom_groq_key)
    else:
        engine = agent_engine

    steps = req.steps if req.steps else engine.plan_task(req.prompt)
    result = engine.execute_plan(steps)

    return {
        "success": result["success"],
        "prompt": req.prompt,
        "total_steps": result["total_steps"],
        "results": result["results"],
        "message": f"Executed {result['total_steps']} steps successfully" if result["success"] else "Some steps encountered issues",
    }


# ── WebSocket for Live Agent Execution Progress ───────────────────────────

@app.websocket("/ws/agent")
async def agent_ws(websocket: WebSocket):
    """
    WebSocket endpoint for real-time autonomous task execution streaming.
    Phone sends: {"pin": "123456", "prompt": "open youtube and search...", "custom_groq_key": "..."}
    Server streams: {"type": "plan", "steps": [...]}, then {"type": "step_update", "step": 1, ...}, then {"type": "done", "success": true}
    """
    await websocket.accept()
    try:
        init_data = await websocket.receive_json()
        if init_data.get("pin") != AIRA_PIN:
            await websocket.send_json({"error": "Invalid PIN"})
            await websocket.close()
            return

        prompt = init_data.get("prompt", "")
        custom_key = init_data.get("custom_groq_key")
        engine = agent_runner.AgentRunner(groq_api_key=custom_key) if custom_key else agent_engine

        # 1. Generate plan
        await websocket.send_json({"type": "status", "message": "Analyzing goal and planning execution steps..."})
        steps = engine.plan_task(prompt)
        await websocket.send_json({"type": "plan", "total_steps": len(steps), "steps": steps})

        # 2. Execute plan with step events
        import asyncio
        loop = asyncio.get_event_loop()

        for idx, step in enumerate(steps, start=1):
            desc = step.get("description", f"Step {idx}")
            await websocket.send_json({
                "type": "step_progress",
                "step": idx,
                "total": len(steps),
                "description": desc,
                "status": "running",
            })

            # Execute single step synchronously in threadpool
            step_result = await loop.run_in_executor(None, lambda s=step, i=idx: engine.execute_plan([s])["results"][0])

            await websocket.send_json({
                "type": "step_progress",
                "step": idx,
                "total": len(steps),
                "description": desc,
                "status": step_result["status"],
                "output": step_result.get("output", ""),
            })

        await websocket.send_json({"type": "done", "message": "All steps executed successfully!", "success": True})
    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except Exception:
            pass


# ── WebSocket for Live Trackpad ───────────────────────────────────────────

@app.websocket("/ws/trackpad")
async def trackpad_ws(websocket: WebSocket):
    """
    WebSocket endpoint for real-time trackpad control.
    Phone sends JSON events like:
        {"type": "move", "dx": 5, "dy": -3}
        {"type": "click", "button": "left"}
        {"type": "scroll", "amount": -3}
    """
    await websocket.accept()
    # Verify PIN in first message
    try:
        auth_msg = await websocket.receive_json()
        if auth_msg.get("pin") != AIRA_PIN:
            await websocket.send_json({"error": "Invalid PIN"})
            await websocket.close()
            return
        await websocket.send_json({"status": "connected", "message": "AIRA trackpad ready"})

        while True:
            data = await websocket.receive_json()
            event_type = data.get("type")

            if event_type == "move":
                mouse_control.move_mouse(data.get("dx", 0), data.get("dy", 0))
            elif event_type == "click":
                btn = data.get("button", "left")
                if btn == "right":
                    mouse_control.right_click()
                elif btn == "double":
                    mouse_control.double_click()
                else:
                    mouse_control.left_click()
            elif event_type == "scroll":
                mouse_control.scroll(data.get("amount", 0))
            elif event_type == "type":
                mouse_control.type_text(data.get("text", ""))
            elif event_type == "hotkey":
                mouse_control.hotkey(*data.get("keys", []))

    except WebSocketDisconnect:
        pass


# ── Entry Point ───────────────────────────────────────────────────────────

def get_local_ip():
    """Get laptop's local Wi-Fi IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


if __name__ == "__main__":
    local_ip = get_local_ip()
    print("\n" + "="*55)
    print("  🤖  AIRA Desktop Agent v3.0.0 — ONLINE")
    print("="*55)
    print(f"  📡  Local IP  :  http://{local_ip}:{PORT}")
    print(f"  🔑  Your PIN  :  {AIRA_PIN}")
    print(f"  💻  Hostname  :  {socket.gethostname()}")
    print("="*55)
    print(f"\n  Open AIRA OS on your phone →")
    print(f"  Settings → Connect Laptop → Enter IP: {local_ip}")
    print(f"  Enter PIN: {AIRA_PIN}\n")

    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="warning")
