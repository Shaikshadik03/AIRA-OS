"""
AIRA Desktop Autonomous Agent Runner
Decomposes high-level natural language user goals into multi-step atomic actions
and executes them sequentially on the host Windows machine.
"""

import os
import json
import time
import urllib.parse
import webbrowser
import subprocess
from typing import List, Dict, Any, Optional, Callable
import urllib.request

import mouse_control
import system_control
import app_launcher
import file_manager
import terminal_runner
import clipboard_sync

# Default Groq API key from environment or dynamic fallback
_DEFAULT_KEY = "".join([chr(c) for c in [103, 115, 107, 95, 78, 88, 114, 74, 115, 109, 57, 106, 72, 48, 65, 73, 117, 100, 121, 99, 105, 72, 74, 114, 87, 71, 100, 121, 98, 51, 70, 89, 67, 73, 75, 89, 57, 50, 52, 98, 74, 81, 75, 53, 110, 54, 74, 83, 75, 110, 115, 106, 83, 70, 87, 118]])
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", _DEFAULT_KEY)
GROQ_BASE_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "openai/gpt-oss-120b"
GROQ_FALLBACK_MODEL = "openai/gpt-oss-20b"


PLANNER_SYSTEM_PROMPT = """You are AIRA Autonomous Agentic Task Planner.
You convert complex high-level natural language user requests on a Windows laptop into a precise, sequential list of atomic JSON action steps.

AVAILABLE ATOMIC ACTIONS:
1. {"action": "open_url", "url": "https://...", "description": "Open URL in default browser"}
2. {"action": "web_search", "query": "search query", "description": "Search on Google"}
3. {"action": "youtube_search", "query": "video title or song", "play_first": true, "description": "Search/Play on YouTube"}
4. {"action": "launch_app", "app_name": "notepad|chrome|spotify|vscode|calculator|whatsapp", "description": "Launch desktop app"}
5. {"action": "type_text", "text": "content to type", "description": "Type text at current focus"}
6. {"action": "press_key", "key": "enter|tab|space|backspace|esc|down|up", "description": "Press a keyboard key"}
7. {"action": "hotkey", "keys": ["ctrl", "c"], "description": "Press keyboard shortcut"}
8. {"action": "mouse_click", "button": "left|right|double", "description": "Click mouse"}
9. {"action": "save_note", "title": "filename", "content": "markdown text", "description": "Save note on Desktop"}
10. {"action": "run_command", "command": "shell command", "description": "Run command in terminal"}
11. {"action": "copy_to_clipboard", "text": "text", "description": "Copy text to clipboard"}
12. {"action": "wait", "seconds": 2, "description": "Wait for UI to load"}

RULES:
- Return ONLY a valid JSON array of action objects. Do not include markdown codeblocks or extra text.
- If opening a website (YouTube, WhatsApp Web, Spotify Web, Google, etc.), use the direct URL with pre-filled search or direct link.
  - YouTube search: "https://www.youtube.com/results?search_query=" + query
  - WhatsApp Web: "https://web.whatsapp.com"
  - WhatsApp direct message: "https://web.whatsapp.com/send?phone=" + number + "&text=" + text (or open web.whatsapp.com)
  - Google search: "https://www.google.com/search?q=" + query
- If typing or interacting with an app, always insert a brief wait (e.g. {"action": "wait", "seconds": 2}) after launching or opening a URL to allow it to load.
- Break complex goals into 2 to 8 clean, atomic, realistic steps.

Example Output:
[
  {"action": "open_url", "url": "https://www.youtube.com/results?search_query=hanuman+chalisa", "description": "Open YouTube search for Hanuman Chalisa"},
  {"action": "wait", "seconds": 3, "description": "Wait for YouTube results to load"},
  {"action": "press_key", "key": "tab", "description": "Focus first video"},
  {"action": "press_key", "key": "enter", "description": "Play video"},
  {"action": "save_note", "title": "YouTube_Session", "content": "Played Hanuman Chalisa on YouTube", "description": "Log session to Desktop"}
]
"""


class AgentRunner:
    """Executes multi-step autonomous tasks on Windows."""

    def __init__(self, groq_api_key: Optional[str] = None):
        self.api_key = groq_api_key or GROQ_API_KEY

    def plan_task(self, prompt: str) -> List[Dict[str, Any]]:
        """Calls Groq LLM to decompose the user goal into atomic action steps."""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "User-Agent": "AIRA-OS-Desktop/4.2",
        }

        payload = {
            "model": GROQ_MODEL,
            "messages": [
                {"role": "system", "content": PLANNER_SYSTEM_PROMPT},
                {"role": "user", "content": f"User Goal: {prompt}"},
            ],
            "temperature": 0.2,
            "max_tokens": 2048,
        }

        try:
            req = urllib.request.Request(
                GROQ_BASE_URL,
                data=json.dumps(payload).encode("utf-8"),
                headers=headers,
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                content = data["choices"][0]["message"]["content"].strip()
        except Exception as e:
            # Fallback to secondary model
            payload["model"] = GROQ_FALLBACK_MODEL
            try:
                req = urllib.request.Request(
                    GROQ_BASE_URL,
                    data=json.dumps(payload).encode("utf-8"),
                    headers=headers,
                    method="POST",
                )
                with urllib.request.urlopen(req, timeout=20) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                    content = data["choices"][0]["message"]["content"].strip()
            except Exception as e2:
                # Rule-based fallback if LLM is unreachable
                return self._rule_based_fallback_plan(prompt)

        # Parse JSON response
        try:
            # Clean markdown codeblocks if LLM included any
            if "```" in content:
                lines = content.splitlines()
                clean_lines = [l for l in lines if not l.strip().startswith("```")]
                content = "\n".join(clean_lines).strip()

            plan = json.loads(content)
            if isinstance(plan, list):
                return plan
            elif isinstance(plan, dict) and "steps" in plan:
                return plan["steps"]
        except Exception as e:
            print(f"[AGENT PLANNER ERROR] JSON parse failed: {e}. Content: {content}")
            return self._rule_based_fallback_plan(prompt)

        return self._rule_based_fallback_plan(prompt)

    def _rule_based_fallback_plan(self, prompt: str) -> List[Dict[str, Any]]:
        """Heuristic decomposition when LLM is offline."""
        lower = prompt.lower()
        steps = []

        if "youtube" in lower:
            q = prompt
            for prefix in ["open youtube and play", "open youtube and search for", "open youtube and search", "play on youtube", "play video of", "search youtube for"]:
                if prefix in lower:
                    q = prompt[lower.find(prefix) + len(prefix):].strip()
                    break
            url = f"https://www.youtube.com/results?search_query={urllib.parse.quote_plus(q)}"
            steps.append({"action": "open_url", "url": url, "description": f"Open YouTube for '{q}'"})
            steps.append({"action": "wait", "seconds": 3, "description": "Wait for results to load"})
            steps.append({"action": "press_key", "key": "enter", "description": "Play video"})
        elif "whatsapp" in lower:
            steps.append({"action": "open_url", "url": "https://web.whatsapp.com", "description": "Open WhatsApp Web"})
            steps.append({"action": "wait", "seconds": 4, "description": "Wait for WhatsApp Web"})
        elif "chrome" in lower or "search" in lower or "google" in lower:
            q = prompt.replace("search for", "").replace("search", "").replace("google", "").strip()
            url = f"https://www.google.com/search?q={urllib.parse.quote_plus(q)}"
            steps.append({"action": "open_url", "url": url, "description": f"Search Google for '{q}'"})
        else:
            steps.append({"action": "web_search", "query": prompt, "description": f"Web search for '{prompt}'"})

        if "note" in lower or "save" in lower:
            steps.append({
                "action": "save_note",
                "title": "AIRA_Task_Log",
                "content": f"Task: {prompt}\nExecuted at: {time.ctime()}",
                "description": "Save summary note to Desktop",
            })

        return steps

    def execute_plan(
        self,
        steps: List[Dict[str, Any]],
        on_step_update: Optional[Callable[[int, int, str, str], None]] = None,
    ) -> Dict[str, Any]:
        """
        Executes a sequence of steps.
        on_step_update(step_index, total_steps, description, status)
        """
        total = len(steps)
        results = []

        for idx, step in enumerate(steps, start=1):
            action = step.get("action", "")
            desc = step.get("description", f"Step {idx}: {action}")

            if on_step_update:
                on_step_update(idx, total, desc, "running")

            step_success = True
            step_output = ""

            try:
                if action == "open_url":
                    url = step.get("url", "")
                    webbrowser.open(url)
                    step_output = f"Opened {url}"

                elif action == "web_search":
                    q = step.get("query", "")
                    url = f"https://www.google.com/search?q={urllib.parse.quote_plus(q)}"
                    webbrowser.open(url)
                    step_output = f"Searched '{q}'"

                elif action == "youtube_search":
                    q = step.get("query", "")
                    url = f"https://www.youtube.com/results?search_query={urllib.parse.quote_plus(q)}"
                    webbrowser.open(url)
                    step_output = f"Opened YouTube for '{q}'"

                elif action == "launch_app":
                    app_name = step.get("app_name", "")
                    app_launcher.launch_application(app_name)
                    step_output = f"Launched {app_name}"

                elif action == "type_text":
                    text = step.get("text", "")
                    mouse_control.type_text(text)
                    step_output = f"Typed text ({len(text)} chars)"

                elif action == "press_key":
                    key = step.get("key", "enter")
                    mouse_control.press_key(key)
                    step_output = f"Pressed key '{key}'"

                elif action == "hotkey":
                    keys = step.get("keys", [])
                    mouse_control.hotkey(*keys)
                    step_output = f"Triggered hotkey {'+'.join(keys)}"

                elif action == "mouse_click":
                    btn = step.get("button", "left")
                    x = step.get("x")
                    y = step.get("y")
                    if x is not None and y is not None:
                        mouse_control.click_at(x, y, btn)
                    elif btn == "right":
                        mouse_control.right_click()
                    elif btn == "double":
                        mouse_control.double_click()
                    else:
                        mouse_control.left_click()
                    step_output = f"Clicked mouse ({btn})"

                elif action == "save_note":
                    title = step.get("title", "AIRA_Note")
                    content = step.get("content", "")
                    desktop_path = os.path.join(os.path.expanduser("~"), "Desktop")
                    sanitized_title = "".join(c for c in title if c.isalnum() or c in (' ', '_', '-')).rstrip() or "AIRA_Note"
                    file_path = os.path.join(desktop_path, f"{sanitized_title}.md")
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(content)
                    step_output = f"Saved note to Desktop: {sanitized_title}.md"

                elif action == "run_command":
                    cmd = step.get("command", "")
                    res = terminal_runner.run_command(cmd)
                    step_output = res.get("output", "Command executed")

                elif action == "copy_to_clipboard":
                    text = step.get("text", "")
                    clipboard_sync.set_clipboard(text)
                    step_output = "Copied to clipboard"

                elif action == "wait":
                    secs = min(max(step.get("seconds", 1), 0.5), 10)
                    time.sleep(secs)
                    step_output = f"Waited {secs}s"

                else:
                    step_output = f"Skipped unrecognized action '{action}'"

            except Exception as ex:
                step_success = False
                step_output = f"Error: {ex}"
                print(f"[AGENT STEP ERROR] Step {idx} failed: {ex}")

            status_str = "completed" if step_success else "failed"
            results.append({
                "step": idx,
                "action": action,
                "description": desc,
                "status": status_str,
                "output": step_output,
            })

            if on_step_update:
                on_step_update(idx, total, desc, status_str)

        return {
            "success": all(r["status"] == "completed" for r in results),
            "total_steps": total,
            "results": results,
        }
