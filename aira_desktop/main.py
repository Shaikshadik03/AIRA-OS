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
import secrets
import time
import json
import random
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
import vision_agent
import task_execution_engine

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


# ── Persistent Pairing & Durable Command State (Stage 8 / Stage I) ─────────

PAIRED_DEVICES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "paired_devices.json")
COMMAND_RECEIPTS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "command_receipts.json")

# In-memory active pairing PIN state with TTL
active_pairing_state = {
    "pin": AIRA_PIN,
    "expires_at": time.time() + 300,
    "client_name": None,
    "device_id": None,
}
is_remote_paused = False

def get_paired_devices() -> dict:
    if os.path.exists(PAIRED_DEVICES_FILE):
        try:
            with open(PAIRED_DEVICES_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_paired_devices(devices: dict):
    try:
        with open(PAIRED_DEVICES_FILE, "w", encoding="utf-8") as f:
            json.dump(devices, f, indent=2)
    except Exception:
        pass

def get_command_receipts() -> dict:
    if os.path.exists(COMMAND_RECEIPTS_FILE):
        try:
            with open(COMMAND_RECEIPTS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_command_receipt(command_id: str, receipt: dict):
    try:
        receipts = get_command_receipts()
        receipts[command_id] = receipt
        # Keep buffer bounded to last 250 receipts
        if len(receipts) > 250:
            keys = list(receipts.keys())
            for k in keys[:-250]:
                del receipts[k]
        with open(COMMAND_RECEIPTS_FILE, "w", encoding="utf-8") as f:
            json.dump(receipts, f, indent=2)
    except Exception:
        pass


# ── Auth & Security Verification ──────────────────────────────────────────

def verify_auth(
    authorization: Optional[str] = Header(None),
    x_aira_pin: Optional[str] = Header(None, alias="X-AIRA-PIN"),
):
    """
    Dual-mode authentication:
    1. Cryptographically secure per-device Bearer token (Primary - Stage 8/Stage I)
    2. Legacy X-AIRA-PIN header (Fallback for backward compatibility)
    """
    global is_remote_paused
    if is_remote_paused:
        raise HTTPException(status_code=423, detail="Remote control is temporarily paused by laptop host.")

    # 1. Bearer Token Verification
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ")[1].strip()
        devices = get_paired_devices()
        if token in devices:
            device = devices[token]
            if device.get("is_revoked", False):
                raise HTTPException(status_code=403, detail="Device has been revoked.")
            device["last_seen"] = int(time.time() * 1000)
            save_paired_devices(devices)
            return device
        raise HTTPException(status_code=401, detail="Invalid or unrecognized device token.")

    # 2. Legacy / Fallback PIN Auth
    if x_aira_pin == AIRA_PIN:
        return {"device_id": "legacy_client", "device_name": "PIN Client", "is_legacy": True}

    raise HTTPException(status_code=401, detail="Authentication required: Provide valid Bearer token or X-AIRA-PIN.")

def verify_pin(x_aira_pin: Optional[str] = Header(None, alias="X-AIRA-PIN"), authorization: Optional[str] = Header(None)):
    """Maintain backward-compatibility for existing endpoints."""
    return verify_auth(authorization=authorization, x_aira_pin=x_aira_pin)


# ── Request Models ────────────────────────────────────────────────────────

class PairRequest(BaseModel):
    client_name: str = "AIRA Phone"
    device_id: str
    platform: str = "android"

class PairConfirmRequest(BaseModel):
    pin: str
    device_id: str
    device_name: str = "AIRA Phone"
    platform: str = "android"

class RevokeDeviceRequest(BaseModel):
    device_token: Optional[str] = None
    device_id: Optional[str] = None

class PauseControlRequest(BaseModel):
    pause: bool

class DurableCommandRequest(BaseModel):
    command_id: str
    device_id: str
    tool: str
    arguments: dict = {}
    created_at: int
    expires_at: int
    owner_id: Optional[str] = "arshan"

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

class SearchFilesRequest(BaseModel):
    directory: Optional[str] = "downloads"
    query: Optional[str] = ""
    extensions: Optional[list[str]] = None
    max_results: Optional[int] = 25

class OrganizeFolderRequest(BaseModel):
    directory: Optional[str] = "downloads"
    preview: Optional[bool] = False

class UndoOrganizationRequest(BaseModel):
    directory: Optional[str] = "downloads"

class PrepareDocumentRequest(BaseModel):
    title: str
    content: str
    doc_format: Optional[str] = "txt"
    open_after: Optional[bool] = True

class SupervisedScreenActionRequest(BaseModel):
    target_description: str
    action: Optional[str] = "click"
    text: Optional[str] = None
    expected_outcome: Optional[str] = None

class AgentTaskRequest(BaseModel):
    prompt: str
    steps: Optional[list] = None
    custom_groq_key: Optional[str] = None

class LiveDesktopCommandRequest(BaseModel):
    command: str
    custom_groq_key: Optional[str] = None


# ── Secure Phone-Laptop Pairing Endpoints (Stage 8 / Stage I) ─────────────

@app.post("/pair/request")
def request_pairing(req: PairRequest):
    """
    Generate a short-lived 6-digit one-time pairing code approved on the laptop.
    Expires in 5 minutes (300 seconds).
    """
    global active_pairing_state
    code = f"{random.randint(100000, 999999)}"
    active_pairing_state = {
        "pin": code,
        "expires_at": time.time() + 300,
        "client_name": req.client_name,
        "device_id": req.device_id,
    }
    print("\n" + "─"*50)
    print(f"  🔐  [AIRA PAIRING REQUEST] From: {req.client_name} ({req.device_id})")
    print(f"  👉  One-Time Approval PIN:  >>>  {code}  <<<")
    print(f"  ⏳  Valid for: 5 minutes")
    print("─"*50 + "\n")

    return {
        "status": "waiting_approval",
        "ttl_seconds": 300,
        "hint": "Enter the 6-digit PIN displayed on your laptop terminal.",
    }


@app.post("/pair/confirm")
def confirm_pairing(req: PairConfirmRequest):
    """
    Exchanges one-time PIN or master PIN for a permanent, cryptographically
    secure per-device Bearer token bound to the owner.
    """
    global active_pairing_state
    now = time.time()
    valid_pin = False

    # 1. Check active one-time pairing PIN
    if active_pairing_state.get("expires_at", 0) > now:
        if req.pin.strip() == active_pairing_state.get("pin", "").strip():
            valid_pin = True

    # 2. Check master AIRA_PIN fallback
    if req.pin.strip() == AIRA_PIN.strip():
        valid_pin = True

    if not valid_pin:
        raise HTTPException(status_code=401, detail="Invalid or expired pairing PIN. Request a new PIN.")

    token = secrets.token_hex(24)
    devices = get_paired_devices()
    devices[token] = {
        "device_id": req.device_id,
        "device_name": req.device_name,
        "platform": req.platform,
        "paired_at": int(now * 1000),
        "last_seen": int(now * 1000),
        "is_revoked": False,
    }
    save_paired_devices(devices)

    print(f"\n  ✅  [AIRA PAIRING SUCCESS] Paired '{req.device_name}' ({req.device_id})")
    return {
        "success": True,
        "device_token": token,
        "owner_id": "arshan",
        "hostname": socket.gethostname(),
        "paired_at": int(now * 1000),
    }


@app.get("/pair/status")
def pairing_status(auth: dict = Depends(verify_auth)):
    """Check pairing state, latency, and online heartbeat."""
    return {
        "status": "authenticated",
        "paired": True,
        "hostname": socket.gethostname(),
        "is_paused": is_remote_paused,
        "device": auth,
        "server_time": int(time.time() * 1000),
    }


@app.post("/pair/revoke")
def revoke_device(req: RevokeDeviceRequest, auth: dict = Depends(verify_auth)):
    """Revoke a paired device immediately. Revoked phones lose control instantaneously."""
    devices = get_paired_devices()
    revoked_count = 0
    for tok, d in list(devices.items()):
        if (req.device_token and tok == req.device_token) or (req.device_id and d.get("device_id") == req.device_id):
            d["is_revoked"] = True
            revoked_count += 1
    save_paired_devices(devices)
    print(f"\n  🚫  [AIRA REVOCATION] Revoked {revoked_count} device connection(s).")
    return {"success": True, "revoked_count": revoked_count, "message": "Device pairing revoked."}


@app.post("/pair/pause")
def toggle_pause(req: PauseControlRequest):
    """Host or client toggle to pause/resume remote command execution."""
    global is_remote_paused
    is_remote_paused = req.pause
    state_str = "PAUSED 🔕" if is_remote_paused else "RESUMED 🔔"
    print(f"\n  ⚠️   [AIRA REMOTE CONTROL] Status: {state_str}")
    return {"success": True, "is_paused": is_remote_paused}


@app.get("/pair/devices")
def list_paired_devices(auth: dict = Depends(verify_auth)):
    """List paired devices, last seen timestamps, and active revocation states."""
    devices = get_paired_devices()
    now_ms = int(time.time() * 1000)
    device_list = []
    for tok, d in devices.items():
        last_seen = d.get("last_seen", 0)
        is_online = (now_ms - last_seen) < 120000 and not d.get("is_revoked", False)
        device_list.append({
            "device_id": d.get("device_id"),
            "device_name": d.get("device_name"),
            "platform": d.get("platform"),
            "paired_at": d.get("paired_at"),
            "last_seen": last_seen,
            "is_online": is_online,
            "is_revoked": d.get("is_revoked", False),
        })
    return {"devices": device_list, "is_paused": is_remote_paused}


# ── Durable Idempotent Remote Command Pipeline ────────────────────────────

@app.post("/command/execute")
def execute_durable_command(cmd: DurableCommandRequest, auth: dict = Depends(verify_auth)):
    """
    Durable, idempotent remote command execution:
    1. Authenticates device and checks host pause status
    2. Replay & Expiry Check: rejects if now > expires_at (prevents stale actions on reconnect)
    3. Idempotency Check: returns existing cached receipt if command_id already ran
    4. Executes whitelisted tool and records receipt
    """
    start_time = time.time()
    now_ms = int(start_time * 1000)

    # 1. Expiry Check (reject actions safe-to-defer that expired, e.g. stale clicks)
    if now_ms > cmd.expires_at:
        print(f"  ⚠️  [EXPIRED COMMAND] '{cmd.tool}' ({cmd.command_id}) expired {now_ms - cmd.expires_at}ms ago. Skipped.")
        return {
            "command_id": cmd.command_id,
            "status": "expired",
            "output": f"Command expired {now_ms - cmd.expires_at}ms ago. Discarded to prevent stale execution.",
            "executed_at": now_ms,
            "duration_ms": 0,
            "replayed": False,
        }

    # 2. Idempotency Check (Duplicate command prevention on reconnect)
    receipts = get_command_receipts()
    if cmd.command_id in receipts:
        cached = receipts[cmd.command_id]
        cached["replayed"] = True
        print(f"  🔄  [IDEMPOTENT REPLAY] Returned cached receipt for '{cmd.command_id}' without re-executing.")
        return cached

    # 3. Tool Execution
    tool = cmd.tool.lower().strip()
    args = cmd.arguments
    output = ""
    status = "executed"

    try:
        if tool == "open_app":
            app_name = args.get("app_name", "")
            output = app_launcher.launch_app(app_name)
        elif tool == "mouse_click":
            x = args.get("x")
            y = args.get("y")
            btn = args.get("button", "left")
            if btn == "right":
                mouse_control.right_click(x, y)
            elif btn == "double":
                mouse_control.double_click(x, y)
            else:
                mouse_control.left_click(x, y)
            output = f"Mouse clicked ({btn}) at ({x}, {y})"
        elif tool == "type_text":
            text = args.get("text", "")
            mouse_control.type_text(text)
            output = f"Typed: {text}"
        elif tool == "hotkey":
            keys = args.get("keys", [])
            mouse_control.hotkey(*keys)
            output = f"Executed hotkey: {keys}"
        elif tool == "system_control":
            action = args.get("action", "")
            if action == "lock":
                system_control.lock_screen()
                output = "Screen locked"
            elif action == "mute":
                system_control.mute_volume()
                output = "Audio muted"
            elif action == "volume":
                level = args.get("level", 50)
                system_control.set_volume(level)
                output = f"Volume set to {level}%"
            elif action == "sleep":
                system_control.sleep_system()
                output = "System put to sleep"
            else:
                output = f"System action '{action}' executed"
        elif tool == "terminal":
            command_str = args.get("command", "")
            output = terminal_runner.run_command(command_str)
        elif tool == "quick_note":
            title = args.get("title", "AIRA_Note")
            content = args.get("content", "")
            output = file_manager.save_quick_note(title, content)
        elif tool == "web_search":
            query = args.get("query", "")
            webbrowser.open(f"https://www.google.com/search?q={urllib.parse.quote(query)}")
            output = f"Opened web search for '{query}'"
        elif tool == "screen_capture":
            b64 = screen_capture.capture_screenshot(quality=args.get("quality", 55), scale=args.get("scale", 0.45))
            output = "Screenshot captured successfully"
        elif tool == "search_files":
            directory = args.get("directory", "downloads")
            query = args.get("query", "")
            extensions = args.get("extensions")
            max_results = args.get("max_results", 25)
            output = task_execution_engine.search_files(directory, query, extensions, max_results)
        elif tool == "organize_folder":
            directory = args.get("directory", "downloads")
            preview = args.get("preview", False)
            output = task_execution_engine.organize_folder(directory, preview=preview)
        elif tool == "undo_organization":
            directory = args.get("directory", "downloads")
            output = task_execution_engine.undo_organization(directory)
        elif tool == "prepare_document":
            title = args.get("title", "AIRA_Note")
            content = args.get("content", "")
            doc_format = args.get("doc_format", "txt")
            open_after = args.get("open_after", True)
            output = task_execution_engine.prepare_document(title, content, doc_format=doc_format, open_after=open_after)
        elif tool == "supervised_screen_action":
            target = args.get("target_description", "")
            action = args.get("action", "click")
            text = args.get("text")
            expected = args.get("expected_outcome")
            output = task_execution_engine.execute_supervised_screen_action(target, action=action, text=text, expected_outcome=expected)
        else:
            status = "unsupported_tool"
            output = f"Tool '{tool}' is not in the allowed remote execution registry."

    except Exception as e:
        status = "failed"
        output = f"Error: {str(e)}"

    duration_ms = int((time.time() - start_time) * 1000)
    receipt = {
        "command_id": cmd.command_id,
        "device_id": cmd.device_id,
        "tool": cmd.tool,
        "status": status,
        "output": str(output),
        "executed_at": now_ms,
        "duration_ms": duration_ms,
        "replayed": False,
    }

    # Save receipt for idempotency
    save_command_receipt(cmd.command_id, receipt)
    print(f"  ⚡  [DURABLE COMMAND EXECUTED] Tool: {cmd.tool} | ID: {cmd.command_id} | Status: {status} ({duration_ms}ms)")
    return receipt


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


# ── Stage J: Windows Digital Task Execution Endpoints ──────────────────────

@app.post("/task/search_files")
def api_search_files(req: SearchFilesRequest, auth: dict = Depends(verify_auth)):
    """Scoped file search across user directories (Downloads, Documents, Desktop, etc.)."""
    return task_execution_engine.search_files(
        directory=req.directory,
        query=req.query,
        extensions=req.extensions,
        max_results=req.max_results,
    )

@app.post("/task/organize_folder")
def api_organize_folder(req: OrganizeFolderRequest, auth: dict = Depends(verify_auth)):
    """Reversible folder organization with undo manifest generation."""
    return task_execution_engine.organize_folder(
        directory=req.directory,
        preview=req.preview,
    )

@app.post("/task/undo_organization")
def api_undo_organization(req: UndoOrganizationRequest, auth: dict = Depends(verify_auth)):
    """Safely restores organized files back to their original folder locations."""
    return task_execution_engine.undo_organization(
        directory=req.directory,
    )

@app.post("/task/prepare_document")
def api_prepare_document(req: PrepareDocumentRequest, auth: dict = Depends(verify_auth)):
    """Prepares structured document in Documents/AIRA_Documents and opens in Notepad."""
    return task_execution_engine.prepare_document(
        title=req.title,
        content=req.content,
        doc_format=req.doc_format,
        open_after=req.open_after,
    )

@app.post("/task/supervised_screen_action")
def api_supervised_screen_action(req: SupervisedScreenActionRequest, auth: dict = Depends(verify_auth)):
    """Supervised screen action loop: Observe -> Target -> Validate -> Act -> Verify."""
    return task_execution_engine.execute_supervised_screen_action(
        target_description=req.target_description,
        action=req.action,
        text=req.text,
        expected_outcome=req.expected_outcome,
    )


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

    if req.steps:
        result = engine.execute_plan(req.steps)
    else:
        result = engine.execute_self_healing_goal(req.prompt)

    msg = f"Executed {result['total_steps']} steps successfully"
    if result.get("self_healed"):
        msg += " (Autonomous self-healing applied to overcome initial error)"
    elif not result["success"]:
        msg = "Some steps encountered issues"

    return {
        "success": result["success"],
        "prompt": req.prompt,
        "total_steps": result["total_steps"],
        "results": result["results"],
        "self_healed": result.get("self_healed", False),
        "message": msg,
    }


@app.post("/agent/live_desktop_command")
def live_desktop_command(req: LiveDesktopCommandRequest, auth: bool = Depends(verify_pin)):
    """
    Processes a live voice or text command directly on the host laptop.
    Grounded in the current laptop screen (using VisionAgent and AgentRunner).
    """
    cmd = req.command.strip().lower()
    custom_key = req.custom_groq_key
    va = vision_agent.VisionAgent(groq_api_key=custom_key)

    def safe_capture():
        try:
            return screen_capture.capture_screenshot(quality=50, scale=0.45)
        except Exception:
            return None

    # 1. Direct window close command
    if any(k in cmd for k in ["close this app", "close app", "close window", "exit app", "quit this app", "close current app"]):
        mouse_control.hotkey("alt", "f4")
        fresh_b64 = safe_capture()
        return {
            "success": True,
            "action": "close_window",
            "message": "Closed the active window on your laptop.",
            "screenshot": fresh_b64,
        }

    # 2. Window management shortcuts
    if "minimize" in cmd:
        mouse_control.hotkey("win", "down")
        fresh_b64 = safe_capture()
        return {"success": True, "action": "minimize", "message": "Minimized active window.", "screenshot": fresh_b64}
    if "maximize" in cmd:
        mouse_control.hotkey("win", "up")
        fresh_b64 = safe_capture()
        return {"success": True, "action": "maximize", "message": "Maximized window.", "screenshot": fresh_b64}

    # 3. Direct visual click request ("press that green button", "click submit", etc.)
    is_visual_click = any(trigger in cmd for trigger in [
        "press that", "press the", "click that", "click the", "click on", "press button",
        "click button", "tap on", "select that", "green button", "blue button", "red button", "play button"
    ])

    if is_visual_click:
        target_desc = req.command
        for prefix in ["press that", "press the", "click that", "click the", "click on", "press", "click", "tap on"]:
            if target_desc.lower().startswith(prefix):
                target_desc = target_desc[len(prefix):].strip()
                break

        try:
            click_res = va.locate_and_click_element(target_desc)
            fresh_b64 = safe_capture()
            if click_res.get("success"):
                return {
                    "success": True,
                    "action": "vision_click",
                    "message": f"Located and clicked '{target_desc}' on your laptop screen.",
                    "screenshot": fresh_b64,
                }
        except Exception:
            pass

    # 4. General agent goal execution (e.g. "open chrome and search...", "scroll down", etc.)
    try:
        engine = agent_runner.AgentRunner(groq_api_key=custom_key) if custom_key else agent_engine
        result = engine.execute_self_healing_goal(req.command)
        fresh_b64 = safe_capture()
        return {
            "success": result.get("success", True),
            "action": "agent_execution",
            "message": f"Executed on laptop: {req.command}",
            "screenshot": fresh_b64,
        }
    except Exception as e:
        fresh_b64 = safe_capture()
        return {
            "success": False,
            "action": "error",
            "message": f"Execution error: {str(e)}",
            "screenshot": fresh_b64,
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
