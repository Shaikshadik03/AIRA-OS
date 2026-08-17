"""
AIRA Desktop Agent — Mouse & Keyboard Control
Uses pyautogui for mouse movement, clicks, scrolling, and keyboard input.
"""
import pyautogui
import time

# Safety: disable pyautogui fail-safe (top-left corner stops it if True)
pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0


def move_mouse(dx: int, dy: int):
    """Move mouse by relative offset (dx, dy) — used for trackpad mode."""
    x, y = pyautogui.position()
    target_x = max(0, min(x + dx, pyautogui.size().width - 1))
    target_y = max(0, min(y + dy, pyautogui.size().height - 1))
    pyautogui.moveTo(target_x, target_y, duration=0.0)


def move_mouse_absolute(x: int, y: int):
    """Move mouse to absolute screen coordinates."""
    pyautogui.moveTo(x, y, duration=0.1)


def left_click(x: int = None, y: int = None):
    """Left click at current position or at (x, y)."""
    if x is not None and y is not None:
        pyautogui.click(x, y)
    else:
        pyautogui.click()


def right_click(x: int = None, y: int = None):
    """Right click at current or specified position."""
    if x is not None and y is not None:
        pyautogui.rightClick(x, y)
    else:
        pyautogui.rightClick()


def double_click(x: int = None, y: int = None):
    """Double left click."""
    if x is not None and y is not None:
        pyautogui.doubleClick(x, y)
    else:
        pyautogui.doubleClick()


def scroll(amount: int):
    """Scroll vertically. Positive = up, Negative = down."""
    pyautogui.scroll(amount)


def type_text(text: str):
    """Type a string of text on the laptop keyboard."""
    pyautogui.write(text, interval=0.02)


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
    pos = pyautogui.position()
    return {"x": pos.x, "y": pos.y}


def get_screen_size():
    """Return screen resolution."""
    size = pyautogui.size()
    return {"width": size.width, "height": size.height}


def drag(start_x: int, start_y: int, end_x: int, end_y: int):
    """Click and drag from start to end coordinates."""
    pyautogui.moveTo(start_x, start_y)
    pyautogui.dragTo(end_x, end_y, duration=0.3, button='left')
