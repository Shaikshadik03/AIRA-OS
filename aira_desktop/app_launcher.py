"""
AIRA Desktop Agent — App Launcher
Opens and closes Windows applications by name.
"""
import subprocess
import psutil
import os


# Common app aliases → executable paths / commands
APP_ALIASES = {
    "chrome": r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    "google chrome": r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    "firefox": r"C:\Program Files\Mozilla Firefox\firefox.exe",
    "vscode": r"C:\Users\{user}\AppData\Local\Programs\Microsoft VS Code\Code.exe",
    "vs code": r"C:\Users\{user}\AppData\Local\Programs\Microsoft VS Code\Code.exe",
    "visual studio code": r"C:\Users\{user}\AppData\Local\Programs\Microsoft VS Code\Code.exe",
    "notepad": "notepad.exe",
    "calculator": "calc.exe",
    "terminal": "wt.exe",
    "windows terminal": "wt.exe",
    "powershell": "powershell.exe",
    "cmd": "cmd.exe",
    "command prompt": "cmd.exe",
    "file explorer": "explorer.exe",
    "explorer": "explorer.exe",
    "task manager": "taskmgr.exe",
    "spotify": r"C:\Users\{user}\AppData\Roaming\Spotify\Spotify.exe",
    "discord": r"C:\Users\{user}\AppData\Local\Discord\app-*\Discord.exe",
    "word": r"C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
    "excel": r"C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE",
    "powerpoint": r"C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE",
    "teams": r"C:\Users\{user}\AppData\Local\Microsoft\Teams\current\Teams.exe",
    "zoom": r"C:\Users\{user}\AppData\Roaming\Zoom\bin\Zoom.exe",
    "vlc": r"C:\Program Files\VideoLAN\VLC\vlc.exe",
    "paint": "mspaint.exe",
    "settings": "ms-settings:",
    "snipping tool": "snippingtool.exe",
    "pycharm": r"C:\Program Files\JetBrains\PyCharm Community Edition*\bin\pycharm64.exe",
}


def _resolve_path(path: str) -> str:
    """Replace {user} placeholder and expand wildcards."""
    username = os.environ.get("USERNAME", "user")
    path = path.replace("{user}", username)
    if '*' in path:
        import glob
        matches = glob.glob(path)
        if matches:
            return matches[-1]  # take latest version
    return path


def open_app(app_name: str) -> dict:
    """
    Open an application by its friendly name.
    Falls back to searching Windows Start Menu if alias not found.
    """
    key = app_name.lower().strip()
    exe_path = APP_ALIASES.get(key)

    if exe_path:
        resolved = _resolve_path(exe_path)
        if resolved.startswith("ms-"):
            # Windows settings URI
            subprocess.Popen(["start", resolved], shell=True)
            return {"success": True, "app": app_name, "method": "uri"}
        if os.path.exists(resolved):
            subprocess.Popen([resolved])
            return {"success": True, "app": app_name, "path": resolved}
        else:
            # Try running by exe name directly (if in PATH)
            try:
                subprocess.Popen([os.path.basename(resolved)])
                return {"success": True, "app": app_name, "method": "basename"}
            except FileNotFoundError:
                pass

    # Fallback: try running the name directly (works for system apps)
    try:
        subprocess.Popen([key + ".exe"])
        return {"success": True, "app": app_name, "method": "direct"}
    except Exception:
        pass

    # Last fallback: use Windows 'start' command (searches PATH + default associations)
    try:
        subprocess.Popen(f'start "" "{app_name}"', shell=True)
        return {"success": True, "app": app_name, "method": "start_shell"}
    except Exception as e:
        return {"success": False, "error": f"Could not find or open '{app_name}'. Error: {e}"}


def close_app(app_name: str) -> dict:
    """Kill a process by its display name or exe name."""
    key = app_name.lower().strip()
    killed = []

    for proc in psutil.process_iter(['pid', 'name']):
        try:
            proc_name = proc.info['name'].lower()
            if key in proc_name or proc_name.startswith(key):
                proc.kill()
                killed.append(proc.info['name'])
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    if killed:
        return {"success": True, "killed": killed}
    return {"success": False, "error": f"No running process found matching '{app_name}'."}


def list_running_apps() -> list:
    """Return a list of currently running foreground-visible applications."""
    seen = set()
    apps = []
    for proc in psutil.process_iter(['pid', 'name', 'status']):
        try:
            name = proc.info['name']
            if name and name not in seen and proc.info['status'] == 'running':
                seen.add(name)
                apps.append({
                    "pid": proc.info['pid'],
                    "name": name,
                })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return sorted(apps, key=lambda x: x['name'].lower())
