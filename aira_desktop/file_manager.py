"""
AIRA Desktop Agent — File Manager
Browse directories, read file metadata, and open files on the laptop.
"""
import os
import subprocess
import json
from pathlib import Path
from typing import Tuple, Optional

DISALLOWED_SYSTEM_PREFIXES = [
    os.environ.get("WINDIR", r"C:\Windows").lower(),
    os.environ.get("SystemRoot", r"C:\Windows").lower(),
    os.environ.get("ProgramFiles", r"C:\Program Files").lower(),
    os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)").lower(),
    os.environ.get("ProgramData", r"C:\ProgramData").lower(),
]


def is_safe_path(path: Optional[str], allow_read_only: bool = False) -> Tuple[bool, str]:
    """
    Validates and resolves a path to ensure it does not access or modify
    sensitive Windows system directories or perform path traversal.
    """
    if not path or not path.strip():
        return True, str(Path.home())

    expanded = os.path.expandvars(os.path.expanduser(path.strip()))
    resolved = os.path.abspath(expanded)
    resolved_lower = resolved.lower()

    for prefix in DISALLOWED_SYSTEM_PREFIXES:
        if resolved_lower == prefix or resolved_lower.startswith(prefix + os.sep) or resolved_lower.startswith(prefix + "/"):
            return False, f"Access to system folder '{prefix}' is blocked for security."

    # Block root drive direct deletion or modification
    if resolved_lower in ["c:\\", "c:/", "d:\\", "d:/", "e:\\", "e:/"]:
        if not allow_read_only:
            return False, f"Modification of root drive '{resolved}' is blocked for security."

    return True, resolved


def list_directory(path: str = None) -> dict:
    """
    List contents of a directory.
    Defaults to the user's home directory if no path given.
    """
    safe, resolved = is_safe_path(path, allow_read_only=True)
    if not safe:
        return {"success": False, "error": resolved}

    expanded = resolved

    if not os.path.exists(expanded):
        return {"success": False, "error": f"Path does not exist: {expanded}"}

    if not os.path.isdir(expanded):
        return {"success": False, "error": f"Not a directory: {expanded}"}

    try:
        entries = []
        for entry in os.scandir(expanded):
            try:
                stat = entry.stat()
                entries.append({
                    "name": entry.name,
                    "is_dir": entry.is_dir(),
                    "size_bytes": stat.st_size if not entry.is_dir() else None,
                    "size_human": _human_size(stat.st_size) if not entry.is_dir() else None,
                    "modified": int(stat.st_mtime),
                    "path": entry.path,
                })
            except PermissionError:
                pass

        # Sort: directories first, then files alphabetically
        entries.sort(key=lambda e: (not e['is_dir'], e['name'].lower()))

        return {
            "success": True,
            "path": expanded,
            "parent": str(Path(expanded).parent),
            "entries": entries,
            "count": len(entries),
        }
    except PermissionError:
        return {"success": False, "error": f"Permission denied: {expanded}"}


def open_file(path: str) -> dict:
    """
    Open a file or folder with its default Windows application.
    Example: open_file('C:/Users/arsha/report.pdf') opens it in Adobe Reader.
    """
    safe, resolved = is_safe_path(path, allow_read_only=False)
    if not safe:
        return {"success": False, "error": resolved}

    expanded = resolved

    if not os.path.exists(expanded):
        return {"success": False, "error": f"File not found: {expanded}"}

    try:
        os.startfile(expanded)
        return {"success": True, "path": expanded}
    except Exception as e:
        return {"success": False, "error": str(e)}


def open_in_explorer(path: str) -> dict:
    """Open Windows Explorer at the given folder path."""
    safe, resolved = is_safe_path(path, allow_read_only=True)
    if not safe:
        return {"success": False, "error": resolved}

    expanded = resolved
    try:
        subprocess.Popen(["explorer", expanded])
        return {"success": True, "path": expanded}
    except Exception as e:
        return {"success": False, "error": str(e)}


def read_text_file(path: str, max_chars: int = 5000) -> dict:
    """
    Read and return the text content of a file (e.g. .txt, .py, .md).
    Limited to max_chars characters for mobile display.
    """
    safe, resolved = is_safe_path(path, allow_read_only=True)
    if not safe:
        return {"success": False, "error": resolved}

    expanded = resolved

    if not os.path.exists(expanded):
        return {"success": False, "error": f"File not found: {expanded}"}

    try:
        with open(expanded, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read(max_chars)
        truncated = os.path.getsize(expanded) > max_chars
        return {
            "success": True,
            "path": expanded,
            "content": content,
            "truncated": truncated,
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def delete_file(path: str) -> dict:
    """Delete a file (moves to Recycle Bin on Windows via shell command)."""
    safe, resolved = is_safe_path(path, allow_read_only=False)
    if not safe:
        return {"success": False, "error": resolved}

    home_dir = str(Path.home()).lower()
    # Prevent deleting outside user space or secondary drives
    if not (resolved.lower().startswith(home_dir + os.sep) or resolved.lower().startswith("d:\\") or resolved.lower().startswith("e:\\")):
        return {"success": False, "error": f"Deletion of files outside user workspace ('{resolved}') is blocked for security."}

    expanded = resolved

    if not os.path.exists(expanded):
        return {"success": False, "error": "File not found."}

    try:
        # Use PowerShell to send to Recycle Bin safely (not permanent delete)
        subprocess.run(
            ["powershell", "-Command",
             f"Add-Type -AssemblyName Microsoft.VisualBasic; "
             f"[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('{expanded}', 'OnlyErrorDialogs', 'SendToRecycleBin')"],
            capture_output=True
        )
        return {"success": True, "deleted": expanded}
    except Exception as e:
        return {"success": False, "error": str(e)}


def rename_file(path: str, new_name: str) -> dict:
    """Rename a file or folder."""
    safe, resolved = is_safe_path(path, allow_read_only=False)
    if not safe:
        return {"success": False, "error": resolved}

    # Disallow path separators in new_name to prevent directory traversal
    if "/" in new_name or "\\" in new_name or ".." in new_name:
        return {"success": False, "error": "Invalid file name: directory separators and traversal are not allowed."}

    expanded = resolved
    parent = str(Path(expanded).parent)
    new_path = os.path.join(parent, new_name)

    try:
        os.rename(expanded, new_path)
        return {"success": True, "old_path": expanded, "new_path": new_path}
    except Exception as e:
        return {"success": False, "error": str(e)}


def get_quick_access_paths() -> dict:
    """Return common quick-access locations on this Windows PC."""
    username = os.environ.get("USERNAME", "user")
    home = str(Path.home())
    return {
        "home": home,
        "desktop": os.path.join(home, "Desktop"),
        "documents": os.path.join(home, "Documents"),
        "downloads": os.path.join(home, "Downloads"),
        "pictures": os.path.join(home, "Pictures"),
        "music": os.path.join(home, "Music"),
        "videos": os.path.join(home, "Videos"),
        "c_drive": "C:\\",
    }


def _human_size(size_bytes: int) -> str:
    """Convert bytes to human-readable size string."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 ** 2:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 ** 3:
        return f"{size_bytes / (1024 ** 2):.1f} MB"
    else:
        return f"{size_bytes / (1024 ** 3):.1f} GB"
