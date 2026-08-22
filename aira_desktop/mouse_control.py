"""
AIRA Desktop Agent — High-Performance Mouse & Keyboard Control
Uses native Win32 ctypes API on Windows for 0ms latency hardware-accelerated
trackpad mouse movement, clicks, and scrolling, with pyautogui as safe fallback.
"""
import ctypes
import pyautogui

# Safety: disable pyautogui fail-safe delay
pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0

# Check for Windows native User32
try:
    user32 = ctypes.windll.user32
    IS_WINDOWS = True
except Exception:
    IS_WINDOWS = False

# Win32 Mouse Event Flags
MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_WHEEL = 0x0800
WHEEL_DELTA = 120


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


def move_mouse(dx: int, dy: int):
    """Move mouse relative by (dx, dy) with 0ms lag."""
    if IS_WINDOWS:
        user32.mouse_event(MOUSEEVENTF_MOVE, int(dx), int(dy), 0, 0)
    else:
        pyautogui.moveRel(dx, dy, duration=0.0)


def move_mouse_absolute(x: int, y: int):
    """Move mouse to absolute screen coordinates."""
    if IS_WINDOWS:
        user32.SetCursorPos(int(x), int(y))
    else:
        pyautogui.moveTo(x, y, duration=0.0)


def left_click(x: int = None, y: int = None):
    """Left click at current position or at (x, y)."""
    if x is not None and y is not None:
        move_mouse_absolute(x, y)
    if IS_WINDOWS:
        user32.mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    else:
        pyautogui.click()


def right_click(x: int = None, y: int = None):
    """Right click at current or specified position."""
    if x is not None and y is not None:
        move_mouse_absolute(x, y)
    if IS_WINDOWS:
        user32.mouse_event(MOUSEEVENTF_RIGHTDOWN | MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)
    else:
        pyautogui.rightClick()


def double_click(x: int = None, y: int = None):
    """Double left click."""
    if x is not None and y is not None:
        move_mouse_absolute(x, y)
    if IS_WINDOWS:
        user32.mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
        user32.mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    else:
        pyautogui.doubleClick()


def scroll(amount: int):
    """Scroll vertically. Positive = up, Negative = down."""
    if IS_WINDOWS:
        user32.mouse_event(MOUSEEVENTF_WHEEL, 0, 0, int(amount * WHEEL_DELTA), 0)
    else:
        pyautogui.scroll(amount)


def type_text(text: str):
    """Type a string of text on the laptop keyboard."""
    pyautogui.write(text, interval=0.01)


def press_key(key: str):
    """Press a single key (e.g. 'enter', 'space', 'backspace', 'escape')."""
    pyautogui.press(key)


def hotkey(*keys):
    """
    Press a keyboard shortcut (e.g. hotkey('ctrl', 'c')).
    Supports all pyautogui key names.
    """
    pyautogui.hotkey(*keys)


def get_mouse_position():
    """Return current mouse position as dict."""
    if IS_WINDOWS:
        pt = POINT()
        user32.GetCursorPos(ctypes.byref(pt))
        return {"x": pt.x, "y": pt.y}
    pos = pyautogui.position()
    return {"x": pos.x, "y": pos.y}


def get_screen_size():
    """Return screen resolution."""
    if IS_WINDOWS:
        return {
            "width": user32.GetSystemMetrics(0),
            "height": user32.GetSystemMetrics(1)
        }
    size = pyautogui.size()
    return {"width": size.width, "height": size.height}


def drag(start_x: int, start_y: int, end_x: int, end_y: int):
    """Click and drag from start to end coordinates."""
    pyautogui.moveTo(start_x, start_y)
    pyautogui.dragTo(end_x, end_y, duration=0.2, button='left')

