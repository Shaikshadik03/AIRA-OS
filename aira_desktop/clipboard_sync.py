"""
AIRA Desktop Agent — Clipboard Sync
Read from and write to the Windows clipboard.
"""
import pyperclip


def get_clipboard() -> dict:
    """Read current clipboard content."""
    try:
        content = pyperclip.paste()
        return {
            "success": True,
            "content": content,
            "length": len(content),
        }
    except Exception as e:
        return {"success": False, "error": str(e), "content": ""}


def set_clipboard(text: str) -> dict:
    """Write text to the Windows clipboard."""
    try:
        pyperclip.copy(text)
        return {"success": True, "copied": text[:100] + "..." if len(text) > 100 else text}
    except Exception as e:
        return {"success": False, "error": str(e)}
