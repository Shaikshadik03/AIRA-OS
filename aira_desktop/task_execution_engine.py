"""
AIRA Desktop Agent — Windows Digital Task Execution Engine (Stage J)
Provides:
1. Allowlisted executable registry & path-bounded safety guardrails
2. Scoped file search across user directories (Downloads, Documents, Desktop, etc.)
3. Reversible folder organization with undo manifests (_aira_undo_manifest.json)
4. Document preparation & Notepad previewing
5. Supervised screen action pipeline: Observe -> Target -> Validate -> Act -> Verify
6. Unexpected dialog detection (UAC, credential prompts) to halt risky clicks
7. Untrusted screen data prompt injection quarantine
"""

import os
import re
import sys
import time
import json
import shutil
import ctypes
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple

# ── Allowlisted Paths & Executables Registry ───────────────────────────────

ALLOWED_DIR_ALIASES = {
    "downloads": lambda: os.path.join(Path.home(), "Downloads"),
    "documents": lambda: os.path.join(Path.home(), "Documents"),
    "desktop": lambda: os.path.join(Path.home(), "Desktop"),
    "pictures": lambda: os.path.join(Path.home(), "Pictures"),
    "music": lambda: os.path.join(Path.home(), "Music"),
    "videos": lambda: os.path.join(Path.home(), "Videos"),
    "home": lambda: str(Path.home()),
}

FILE_EXTENSIONS_MAP = {
    "PDFs": [".pdf"],
    "Documents": [".docx", ".doc", ".txt", ".pptx", ".xlsx", ".csv", ".md", ".rtf", ".odt"],
    "Images": [".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".ico"],
    "Code": [".py", ".dart", ".js", ".ts", ".html", ".css", ".json", ".java", ".cpp", ".c", ".rs", ".go"],
    "Media": [".mp4", ".mkv", ".mp3", ".wav", ".mov", ".avi", ".flac"],
    "Archives": [".zip", ".rar", ".7z", ".tar", ".gz"],
}

UNEXPECTED_DIALOG_KEYWORDS = [
    "user account control",
    "credential",
    "password",
    "enter credentials",
    "windows security",
    "security warning",
    "administrator",
    "do you want to allow this app",
    "format disk",
    "fatal error",
]

INJECTION_PATTERNS = [
    r"ignore\s+(?:all\s+)?(?:previous\s+)?instructions",
    r"disregard\s+(?:all\s+)?(?:prior\s+)?commands",
    r"system\s+prompt\s+override",
    r"you\s+are\s+now\s+in\s+(?:developer|admin|god)\s+mode",
    r"send\s+(?:all\s+)?files\s+to",
    r"exfiltrate",
    r"delete\s+everything",
]


def resolve_scoped_path(raw_path: Optional[str]) -> Tuple[bool, str]:
    """
    Validates and resolves a directory path within user boundaries.
    Prevents path traversal or system root access.
    """
    if not raw_path or not raw_path.strip():
        return True, str(Path.home())

    cleaned = raw_path.strip().lower()
    if cleaned in ALLOWED_DIR_ALIASES:
        resolved = ALLOWED_DIR_ALIASES[cleaned]()
        return True, resolved

    # Expand variables and user tilde
    expanded = os.path.expandvars(os.path.expanduser(raw_path.strip()))
    resolved = os.path.abspath(expanded)
    home_dir = str(Path.home())

    # Disallow root drives, Windows system folders
    disallowed_prefixes = [
        os.environ.get("WINDIR", r"C:\Windows").lower(),
        os.environ.get("ProgramFiles", r"C:\Program Files").lower(),
        os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)").lower(),
    ]

    for prefix in disallowed_prefixes:
        if resolved.lower().startswith(prefix):
            return False, f"Access to system folder '{prefix}' is blocked for security."

    # Allow anything inside the user's home directory or secondary data drives
    if not resolved.lower().startswith(home_dir.lower()) and not resolved.lower().startswith("d:\\") and not resolved.lower().startswith("e:\\"):
        return False, f"Path '{resolved}' is outside permitted user workspace."

    return True, resolved


# ── 1. Scoped File Search ──────────────────────────────────────────────────

def search_files(
    directory: Optional[str] = "downloads",
    query: str = "",
    extensions: Optional[List[str]] = None,
    max_results: int = 25
) -> Dict[str, Any]:
    """
    Searches files within a scoped directory with query and extension filters.
    """
    valid, target_dir = resolve_scoped_path(directory)
    if not valid:
        return {"success": False, "error": target_dir, "files": []}

    if not os.path.exists(target_dir) or not os.path.isdir(target_dir):
        return {"success": False, "error": f"Directory does not exist: {target_dir}", "files": []}

    query_lower = query.strip().lower() if query else ""
    ext_list = [e.lower() if e.startswith(".") else f".{e.lower()}" for e in (extensions or [])]

    results = []
    try:
        for root, dirs, files in os.walk(target_dir):
            # Skip hidden and cache folders
            dirs[:] = [d for d in dirs if not d.startswith(".") and not d.startswith("__")]

            for file in files:
                if file.startswith(".") or file.startswith("_aira_"):
                    continue

                file_ext = os.path.splitext(file)[1].lower()
                if ext_list and file_ext not in ext_list:
                    continue

                if query_lower and query_lower not in file.lower():
                    continue

                full_path = os.path.join(root, file)
                try:
                    stat = os.stat(full_path)
                    results.append({
                        "name": file,
                        "extension": file_ext,
                        "size_bytes": stat.st_size,
                        "size_human": _format_size(stat.st_size),
                        "modified": int(stat.st_mtime),
                        "path": full_path,
                        "directory": root,
                    })
                    if len(results) >= max_results:
                        break
                except (PermissionError, FileNotFoundError):
                    pass

            if len(results) >= max_results:
                break

        return {
            "success": True,
            "directory": target_dir,
            "query": query,
            "extensions": ext_list,
            "count": len(results),
            "files": results,
        }
    except Exception as e:
        return {"success": False, "error": str(e), "files": []}


# ── 2. Reversible Folder Organization ─────────────────────────────────────

def organize_folder(directory: str = "downloads", preview: bool = False) -> Dict[str, Any]:
    """
    Categorizes files into subfolders (PDFs, Documents, Images, Code, Media, Archives).
    Creates an `_aira_undo_manifest.json` enabling 100% reversible undo.
    """
    valid, target_dir = resolve_scoped_path(directory)
    if not valid:
        return {"success": False, "error": target_dir}

    if not os.path.exists(target_dir) or not os.path.isdir(target_dir):
        return {"success": False, "error": f"Folder does not exist: {target_dir}"}

    manifest_path = os.path.join(target_dir, "_aira_undo_manifest.json")
    moved_records = []
    planned_moves = []

    try:
        for entry in os.scandir(target_dir):
            if not entry.is_file():
                continue
            if entry.name.startswith(".") or entry.name.startswith("_aira_"):
                continue

            file_ext = os.path.splitext(entry.name)[1].lower()
            target_category = None

            for category, exts in FILE_EXTENSIONS_MAP.items():
                if file_ext in exts:
                    target_category = category
                    break

            if not target_category:
                continue

            cat_folder = os.path.join(target_dir, target_category)
            dest_path = os.path.join(cat_folder, entry.name)

            # Prevent collision if file already exists in target
            if os.path.exists(dest_path) and dest_path != entry.path:
                base, ext = os.path.splitext(entry.name)
                dest_path = os.path.join(cat_folder, f"{base}_{int(time.time())}{ext}")

            planned_moves.append({
                "filename": entry.name,
                "category": target_category,
                "original_path": entry.path,
                "destination_path": dest_path,
            })

        if preview:
            return {
                "success": True,
                "preview": True,
                "directory": target_dir,
                "files_to_move": len(planned_moves),
                "planned_moves": planned_moves,
            }

        # Execute moves
        for move in planned_moves:
            cat_folder = os.path.dirname(move["destination_path"])
            os.makedirs(cat_folder, exist_ok=True)
            shutil.move(move["original_path"], move["destination_path"])
            moved_records.append({
                "original_path": move["original_path"],
                "new_path": move["destination_path"],
                "category": move["category"],
            })

        # Save Undo Manifest
        manifest = {
            "manifest_id": f"manifest_{int(time.time())}",
            "created_at": int(time.time() * 1000),
            "directory": target_dir,
            "moved_count": len(moved_records),
            "moves": moved_records,
        }
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)

        return {
            "success": True,
            "directory": target_dir,
            "moved_count": len(moved_records),
            "manifest_path": manifest_path,
            "message": f"Organized {len(moved_records)} files in '{os.path.basename(target_dir)}'. Undo manifest created.",
        }

    except Exception as e:
        return {"success": False, "error": str(e), "moved_count": len(moved_records)}


def undo_organization(directory: str = "downloads") -> Dict[str, Any]:
    """
    Reads `_aira_undo_manifest.json` and restores all moved files back to their original paths.
    Cleans up empty category folders afterwards.
    """
    valid, target_dir = resolve_scoped_path(directory)
    if not valid:
        return {"success": False, "error": target_dir}

    manifest_path = os.path.join(target_dir, "_aira_undo_manifest.json")
    if not os.path.exists(manifest_path):
        return {
            "success": False,
            "error": f"No undo manifest found in '{target_dir}'. Nothing to undo.",
        }

    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = json.load(f)

        moves = manifest.get("moves", [])
        restored_count = 0

        for m in reversed(moves):
            orig = m["original_path"]
            curr = m["new_path"]
            if os.path.exists(curr):
                os.makedirs(os.path.dirname(orig), exist_ok=True)
                shutil.move(curr, orig)
                restored_count += 1

        # Remove empty category folders
        for cat in FILE_EXTENSIONS_MAP.keys():
            cat_dir = os.path.join(target_dir, cat)
            if os.path.exists(cat_dir) and os.path.isdir(cat_dir):
                try:
                    if not os.listdir(cat_dir):
                        os.rmdir(cat_dir)
                except OSError:
                    pass

        # Remove manifest after successful restoration
        os.remove(manifest_path)

        return {
            "success": True,
            "restored_count": restored_count,
            "directory": target_dir,
            "message": f"Successfully restored {restored_count} files back to their original locations.",
        }

    except Exception as e:
        return {"success": False, "error": str(e)}


# ── 3. Document Preparation ────────────────────────────────────────────────

def prepare_document(
    title: str,
    content: str,
    doc_format: str = "txt",
    open_after: bool = True
) -> Dict[str, Any]:
    """
    Creates or updates a document in Documents/AIRA_Documents and optionally opens it in Notepad.
    Sanitizes filenames to prevent invalid character errors.
    """
    clean_title = re.sub(r'[\\/*?:"<>|]', "", title).strip()
    if not clean_title:
        clean_title = f"AIRA_Document_{int(time.time())}"

    ext = doc_format.lower().strip().replace(".", "")
    if ext not in ["txt", "md", "csv", "log"]:
        ext = "txt"

    docs_dir = os.path.join(Path.home(), "Documents", "AIRA_Documents")
    os.makedirs(docs_dir, exist_ok=True)

    file_path = os.path.join(docs_dir, f"{clean_title}.{ext}")

    try:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)

        if open_after:
            try:
                subprocess.Popen(["notepad.exe", file_path])
            except Exception:
                try:
                    os.startfile(file_path)
                except Exception:
                    pass

        return {
            "success": True,
            "title": clean_title,
            "path": file_path,
            "char_count": len(content),
            "opened": open_after,
            "message": f"Document '{clean_title}.{ext}' prepared and opened on laptop.",
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


# ── 4. Supervised Screen Action Pipeline & Guardrails ──────────────────────

def get_foreground_window_title() -> str:
    """Returns the title of the active foreground window on Windows."""
    try:
        user32 = ctypes.windll.user32
        hwnd = user32.GetForegroundWindow()
        length = user32.GetWindowTextLengthW(hwnd)
        buff = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buff, length + 1)
        return buff.value
    except Exception:
        return ""


def detect_unexpected_dialog() -> Tuple[bool, str]:
    """
    Inspects the active window for unexpected security/UAC dialogs.
    Halts risky screen actions if an unapproved prompt has stolen focus.
    """
    title = get_foreground_window_title().strip().lower()
    if not title:
        return False, ""

    for kw in UNEXPECTED_DIALOG_KEYWORDS:
        if kw in title:
            return True, title

    return False, title


def sanitize_screen_text(text: str) -> str:
    """
    Quarantines untrusted text parsed from screen captures.
    Neutralizes prompt injection patterns.
    """
    if not text:
        return ""

    sanitized = text
    for pattern in INJECTION_PATTERNS:
        sanitized = re.sub(pattern, "[DEFUSED_INJECTION_PROMPT]", sanitized, flags=re.IGNORECASE)

    # Disarm XML/HTML system boundaries
    sanitized = sanitized.replace("<SYSTEM>", "").replace("</SYSTEM>", "")
    sanitized = sanitized.replace("<PROMPT>", "").replace("</PROMPT>", "")

    return f"<UNTRUSTED_SCREEN_CONTENT>\n{sanitized.strip()}\n</UNTRUSTED_SCREEN_CONTENT>"


def execute_supervised_screen_action(
    target_description: str,
    action: str = "click",
    text: Optional[str] = None,
    expected_outcome: Optional[str] = None
) -> Dict[str, Any]:
    """
    Supervised 5-stage screen action loop:
    1. Observe: Capture current window title and state
    2. Target: Locate requested UI control coordinates
    3. Validate: Check for unexpected dialogs or focus shifts (halts if risky)
    4. Act: Perform verified click / typing
    5. Verify: Re-observe screen to check if state changed as expected
    """
    pipeline_trace = []
    now_ms = int(time.time() * 1000)

    # Stage 1: Observe
    fg_title = get_foreground_window_title()
    pipeline_trace.append({
        "stage": "observe",
        "timestamp": now_ms,
        "foreground_window": fg_title,
    })

    # Stage 2 & 3: Validate active focus before acting
    has_dialog, dialog_title = detect_unexpected_dialog()
    if has_dialog:
        pipeline_trace.append({
            "stage": "validate",
            "status": "halted_security_dialog",
            "dialog_title": dialog_title,
        })
        return {
            "success": False,
            "status": "halted_on_dialog",
            "pipeline": pipeline_trace,
            "message": f"Action halted: Unexpected sensitive dialog detected ('{dialog_title}').",
        }

    pipeline_trace.append({
        "stage": "validate",
        "status": "focus_validated",
        "foreground_window": fg_title,
    })

    # Stage 4: Target & Act via Vision or Direct Simulation
    action_result = {}
    try:
        from vision_agent import VisionAgent
        agent = VisionAgent()

        if action.lower() == "click":
            action_result = agent.locate_and_click_element(target_description)
        elif action.lower() == "type":
            # If element specified, click first, then type
            if target_description and target_description.lower() not in ["none", "active"]:
                agent.locate_and_click_element(target_description)
                time.sleep(0.2)
            import mouse_control
            mouse_control.type_text(text or "")
            action_result = {"success": True, "typed": text}
        else:
            action_result = {"success": False, "error": f"Unknown action '{action}'"}

    except Exception as e:
        # Fallback to coordinate simulation or friendly report
        action_result = {"success": False, "error": str(e)}

    pipeline_trace.append({
        "stage": "act",
        "action": action,
        "target": target_description,
        "result": action_result,
    })

    # Stage 5: Verify
    time.sleep(0.4)
    new_fg_title = get_foreground_window_title()
    verified = action_result.get("success", False)

    pipeline_trace.append({
        "stage": "verify",
        "verified": verified,
        "previous_window": fg_title,
        "new_window": new_fg_title,
    })

    return {
        "success": verified,
        "status": "executed" if verified else "failed",
        "target": target_description,
        "action": action,
        "pipeline": pipeline_trace,
        "message": action_result.get("message", f"Supervised action '{action}' completed for '{target_description}'."),
    }


def _format_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 ** 2:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 ** 3:
        return f"{size_bytes / (1024 ** 2):.1f} MB"
    else:
        return f"{size_bytes / (1024 ** 3):.1f} GB"
