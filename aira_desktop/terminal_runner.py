"""
AIRA Desktop Agent — Safe Terminal Runner
Executes whitelisted shell commands on the laptop and returns output.
Security: Only safe, whitelisted command prefixes are allowed.
"""
import subprocess
import shlex
import os

# Safe command whitelist — only these command prefixes are allowed
SAFE_PREFIXES = [
    "python", "py", "pip", "node", "npm", "git", "dart", "flutter",
    "dir", "ls", "echo", "type", "cat", "cd", "where", "which",
    "ipconfig", "ping", "curl", "whoami", "hostname", "date", "time",
    "systeminfo", "tasklist", "netstat", "cls", "clear",
    "code", "notepad", "calc", "start",
]

# Blocked commands — never allow these (safety)
BLOCKED_KEYWORDS = [
    "rm -rf", "del /f /s", "format c:", "shutdown /s /f",
    "rmdir /s", "rd /s", "drop table", ":(){:|:&};:",
    "mkfs", "dd if=", "chmod 777 /", "> /dev/sda",
]


def is_safe_command(command: str) -> bool:
    """Check if a command is in the safe whitelist."""
    cmd_lower = command.strip().lower()

    # Block dangerous commands
    for blocked in BLOCKED_KEYWORDS:
        if blocked in cmd_lower:
            return False

    # Allow if starts with a safe prefix
    first_word = cmd_lower.split()[0] if cmd_lower.split() else ""
    return first_word in SAFE_PREFIXES


def run_command(command: str, working_dir: str = None, timeout: int = 15) -> dict:
    """
    Execute a shell command safely on the laptop.
    Returns stdout/stderr and exit code.

    Args:
        command: Shell command string (e.g. 'python --version')
        working_dir: Working directory for the command. Defaults to user home.
        timeout: Maximum execution time in seconds.

    Returns:
        dict with stdout, stderr, exit_code, success.
    """
    if not is_safe_command(command):
        return {
            "success": False,
            "error": f"Command '{command.split()[0]}' is not in AIRA's safe command list for security reasons.",
            "stdout": "",
            "stderr": "",
            "exit_code": -1,
        }

    cwd = working_dir or os.path.expanduser("~")

    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd,
            encoding='utf-8',
            errors='replace',
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout[:4000],  # Limit output for mobile
            "stderr": result.stderr[:1000],
            "exit_code": result.returncode,
            "command": command,
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "error": f"Command timed out after {timeout} seconds.",
            "stdout": "",
            "stderr": "",
            "exit_code": -1,
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "stdout": "",
            "stderr": "",
            "exit_code": -1,
        }


def get_python_version() -> str:
    """Return installed Python version."""
    result = run_command("python --version")
    return result.get("stdout", "").strip() or result.get("stderr", "").strip()


def run_python_snippet(code: str, timeout: int = 10) -> dict:
    """
    Run a short Python code snippet on the laptop.
    Writes to a temp file and runs it safely.
    """
    import tempfile

    with tempfile.NamedTemporaryFile(suffix='.py', mode='w', delete=False, encoding='utf-8') as f:
        f.write(code)
        temp_path = f.name

    try:
        result = run_command(f'python "{temp_path}"', timeout=timeout)
    finally:
        try:
            os.unlink(temp_path)
        except Exception:
            pass

    return result
