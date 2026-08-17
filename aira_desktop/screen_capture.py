"""
AIRA Desktop Agent — Screenshot Capture
Captures the laptop screen as a JPEG image and returns it as base64.
"""
import io
import base64
import pyautogui
from PIL import Image


def capture_screenshot(quality: int = 60, scale: float = 0.5) -> str:
    """
    Capture a screenshot of the full screen.
    Returns a base64-encoded JPEG string for sending to the mobile app.

    Args:
        quality: JPEG quality (1-95). Lower = smaller file, faster transfer.
        scale: Scale factor for downscaling. 0.5 = half resolution.

    Returns:
        Base64-encoded JPEG string.
    """
    # Capture full screen using pyautogui
    screenshot = pyautogui.screenshot()

    # Downscale for faster mobile transfer
    if scale != 1.0:
        new_w = int(screenshot.width * scale)
        new_h = int(screenshot.height * scale)
        screenshot = screenshot.resize((new_w, new_h), Image.LANCZOS)

    # Convert to RGB (removes alpha channel if any)
    screenshot = screenshot.convert("RGB")

    # Save to in-memory bytes buffer as JPEG
    buffer = io.BytesIO()
    screenshot.save(buffer, format="JPEG", quality=quality, optimize=True)
    buffer.seek(0)

    # Encode to base64 string
    encoded = base64.b64encode(buffer.read()).decode("utf-8")
    return encoded


def capture_region(x: int, y: int, width: int, height: int, quality: int = 75) -> str:
    """
    Capture a specific region of the screen.
    Useful for showing just one window or panel.
    """
    screenshot = pyautogui.screenshot(region=(x, y, width, height))
    screenshot = screenshot.convert("RGB")

    buffer = io.BytesIO()
    screenshot.save(buffer, format="JPEG", quality=quality, optimize=True)
    buffer.seek(0)

    return base64.b64encode(buffer.read()).decode("utf-8")
