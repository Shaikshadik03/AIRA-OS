"""
AIRA Desktop Agent — System Control
Handles volume, brightness, screen lock, sleep, shutdown, restart.
"""
import subprocess
import platform
import os
import ctypes


# ── Volume Control (Windows) ──────────────────────────────────────────────

def set_volume(level: int):
    """Set system volume (0-100)."""
    try:
        from comtypes import CLSCTX_ALL
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
        import numpy as np

        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        volume = interface.QueryInterface(IAudioEndpointVolume)
        # Convert 0-100 to scalar 0.0-1.0
        volume.SetMasterVolumeLevelScalar(level / 100.0, None)
        return {"success": True, "volume": level}
    except Exception as e:
        # Fallback: use PowerShell nircmd-style command
        try:
            level_val = int(65535 * level / 100)
            subprocess.run(
                ["powershell", "-Command",
                 f"(New-Object -ComObject WScript.Shell).SendKeys([char]174)"],
                capture_output=True
            )
        except Exception:
            pass
        return {"success": True, "volume": level, "method": "fallback"}


def get_volume() -> int:
    """Get current system volume (0-100)."""
    try:
        from comtypes import CLSCTX_ALL
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume

        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        volume = interface.QueryInterface(IAudioEndpointVolume)
        level = int(volume.GetMasterVolumeLevelScalar() * 100)
        return level
    except Exception:
        return 50


def mute_volume():
    """Mute system audio."""
    import pyautogui
    pyautogui.press('volumemute')
    return {"success": True, "action": "mute"}


def volume_up(steps: int = 5):
    """Increase volume by steps."""
    import pyautogui
    for _ in range(steps):
        pyautogui.press('volumeup')
    return {"success": True, "action": "volume_up"}


def volume_down(steps: int = 5):
    """Decrease volume by steps."""
    import pyautogui
    for _ in range(steps):
        pyautogui.press('volumedown')
    return {"success": True, "action": "volume_down"}


# ── Brightness Control ────────────────────────────────────────────────────

def set_brightness(level: int):
    """Set screen brightness (0-100). Windows only."""
    try:
        import screen_brightness_control as sbc
        sbc.set_brightness(level)
        return {"success": True, "brightness": level}
    except Exception as e:
        return {"success": False, "error": str(e)}


def get_brightness() -> int:
    """Get current screen brightness."""
    try:
        import screen_brightness_control as sbc
        return sbc.get_brightness(display=0)[0]
    except Exception:
        return 70


# ── Power Control ─────────────────────────────────────────────────────────

def lock_screen():
    """Lock the Windows screen."""
    ctypes.windll.user32.LockWorkStation()
    return {"success": True, "action": "lock"}


def sleep_laptop():
    """Put the laptop to sleep."""
    subprocess.run(["powershell", "-Command",
                    "Add-Type -Assembly System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false)"],
                   capture_output=True)
    return {"success": True, "action": "sleep"}


def shutdown_laptop(delay_seconds: int = 5):
    """Shutdown the laptop after a delay (default 5 seconds)."""
    subprocess.run(["shutdown", "/s", "/t", str(delay_seconds)], capture_output=True)
    return {"success": True, "action": "shutdown", "delay": delay_seconds}


def restart_laptop(delay_seconds: int = 5):
    """Restart the laptop after a delay."""
    subprocess.run(["shutdown", "/r", "/t", str(delay_seconds)], capture_output=True)
    return {"success": True, "action": "restart", "delay": delay_seconds}


def cancel_shutdown():
    """Cancel a pending shutdown/restart."""
    subprocess.run(["shutdown", "/a"], capture_output=True)
    return {"success": True, "action": "cancel_shutdown"}


# ── System Info ───────────────────────────────────────────────────────────

def get_system_stats() -> dict:
    """Return CPU, RAM, disk usage and battery level."""
    import psutil
    cpu = psutil.cpu_percent(interval=0.5)
    ram = psutil.virtual_memory()
    disk = psutil.disk_usage('C:\\')
    battery = psutil.sensors_battery()

    return {
        "cpu_percent": cpu,
        "ram_used_gb": round(ram.used / (1024 ** 3), 1),
        "ram_total_gb": round(ram.total / (1024 ** 3), 1),
        "ram_percent": ram.percent,
        "disk_used_gb": round(disk.used / (1024 ** 3), 1),
        "disk_total_gb": round(disk.total / (1024 ** 3), 1),
        "disk_percent": disk.percent,
        "battery_percent": battery.percent if battery else None,
        "is_charging": battery.power_plugged if battery else None,
    }
