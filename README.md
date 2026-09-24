# 🧠 AIRA-OS: Autonomous Cross-Device Agentic AI Operating System

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/FastAPI-0.110+-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI" />
  <img src="https://img.shields.io/badge/Groq-Llama--3.3%20%7C%20Llama--3.2--Vision-F05032?style=for-the-badge&logo=groq&logoColor=white" alt="Groq" />
  <img src="https://img.shields.io/badge/Agentic_AI-6--Phase%20Swarm-8A2BE2?style=for-the-badge" alt="Agentic AI" />
  <img src="https://img.shields.io/badge/Latency-0ms%20Win32%20ctypes-brightgreen?style=for-the-badge" alt="0ms Latency" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License" />
</p>

---

## 🌟 Overview

**AIRA-OS** is an autonomous, cross-device personal **AI Operating System** bridging an Android mobile device and a Windows laptop into a single, unified intelligent environment.

Unlike traditional reactive chatbots that merely generate text responses, or voice assistants that only execute single hardcoded commands, **AIRA-OS executes high-level missions**:
- Decomposes broad goals (*"Handle my morning"* or *"Prep for my OS exam"*) into atomic subtask graphs.
- Grounds and clicks visual UI elements on your laptop screen using **Multimodal Computer Vision**.
- Critiques its own drafts for tone and accuracy with a **Self-Check Reflection Loop**.
- Enforces strict **Human-in-the-Loop Guardrail Tiers** for sensitive actions (emails, SMS, calls, deletions).
- Calibrates its future behavior dynamically through **Adaptive Outcome Learning**.
- Orchestrates specialized **Sub-Agents** (Scheduler, Email, Memory, and Automation).

---

## 🏛️ System Architecture Topology

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              AIRA-OS SYSTEM TOPOLOGY                                   │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                        │
│   📱 LAYER 1: MOBILE CLIENT (Flutter / Dart / Android ARM64)                           │
│   • Presentation: Claude Design System (Playfair Display + Source Serif 4 + Fira Code) │
│   • Reactive State: Flutter Riverpod 2.6+ (Decoupled unidirectional data flow)         │
│   • Native Hardware Bridge: Android MethodChannels (Calls, SMS, Torch, Alarms, Apps)   │
│   • Real-Time Audio: speech_to_text + flutter_tts + Continuous Hands-Free Wake Word    │
│                                                                                        │
│                                      ▲  HTTP / WebSocket (Local Wi-Fi LAN Mesh)        │
│                                      ▼                                                 │
│                                                                                        │
│   💻 LAYER 2: DESKTOP AGENT (Python 3.10+ / FastAPI / Windows OS)                      │
│   • Fast Server: FastAPI + Uvicorn ASGI on Port 8765 (PIN-authenticated handshake)     │
│   • Multimodal Vision Agent: Groq Llama-3.2-11B-Vision + MSS screenshot capture        │
│   • 0ms Trackpad Acceleration: Win32 API via Python ctypes.windll.user32               │
│   • Automation Engine: PyAutoGUI, Windows Shell subprocess, System control             │
│                                                                                        │
│                                      ▲  REST APIs                                      │
│                                      ▼                                                 │
│                                                                                        │
│   🧠 LAYER 3: INTELLIGENCE & AGENTIC BRAIN (Cloud & Local)                             │
│   • Multi-Provider LLM Fallback: Groq (Llama-3 70B/120B) ➔ Gemini 1.5 ➔ OpenRouter    │
│   • 6-Phase Agentic Pipeline: Goal Planner ➔ Self-Check ➔ Guardrails ➔ Tools ➔ Swarm  │
│   • Adaptive Memory Engine: SharedPreferences + Cognitive Entity Graph + Outcomes      │
│                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 The 6-Phase Master Agentic AI Core

```
User Goal ("Handle my morning")
       │
       ▼
1. 🎯 GoalPlannerEngine ────────► Decomposes goal into structured JSON subtask graph (ReAct)
       │
       ▼
2. 👁️ SelfCheckReflector ───────► Scans drafts for robotic filler, placeholders, and tone flaws
       │
       ▼
3. 🛡️ ActionGuardrailManager ──► Free-Run Tier: Auto-executes (Reads, alarms, searches, notes)
                                 Approval-Required Tier: Pauses for interactive chat confirmation card
       │
       ▼
4. ⚡ AgentToolRegistry ────────► Schema-based auto-selector (Web search, n8n, apps, device, laptop)
       │
       ▼
5. 🧠 AdaptiveOutcomeLearner ───► Calibrates AI style based on user edits/approvals over time
       │
       ▼
6. 🤖 AgentOrchestrator ────────► Dispatches subtasks to Scheduler, Email, Memory, & Automation agents
```

| Phase | Core Component | Responsibility |
|---|---|---|
| **Phase 1** | `GoalPlannerEngine` | Takes natural language goals and generates an ordered subtask graph. Streams live step progress in the UI via `PlanExecutionCard`. |
| **Phase 2** | `SelfCheckReflector` | Pre-action critique engine. Eliminates placeholder brackets `[Insert Date]` and robotic phrases before user presentation. Persists audit records. |
| **Phase 3** | `ActionGuardrailManager` | Strict Two-Tier Safety System. Read actions run free; write/send/delete actions pause at an interactive `ActionApprovalCard` (`[Approve]`, `[Edit]`, `[Reject]`). |
| **Phase 4** | `AgentToolRegistry` | Schema-based dynamic tool dispatcher mapping subtasks to native Android services, Web Search, n8n webhooks, and laptop actions. |
| **Phase 5** | `AdaptiveOutcomeLearner` | Computes character and tone deltas on user edits. Injects persistent `<adaptive_learned_preferences>` directives into future system prompts. |
| **Phase 6** | `AgentOrchestrator` | Coordinates specialized role-based sub-agents (`SchedulerSubAgent`, `EmailCommsSubAgent`, `MemoryLearningSubAgent`, `AutomationDeviceSubAgent`). |

---

## 🗺️ 12-Stage Master Blueprint Architecture

AIRA OS has completed all 12 stages defined in the Master Blueprint, creating a reliable, privacy-preserving, cross-device operating environment:

| Stage | Pillar | Core Deliverables | Automated Tests | Status |
|---|---|---|---|---|
| **Stage 1** | **Core UI & Baseline Stability** | Claude warm dark/light theme, typography, chat viewport stabilization | Unit & Regression | ✅ Complete |
| **Stage 2** | **Personalization & Memory Vault** | Persistent cognitive memory, semantic fact extraction, user profile context | Unit & Persistence | ✅ Complete |
| **Stage 3** | **Tasks & Commitments** | TickTick sync, local tasks, Schedule Autopilot, bilingual task creation | Autopilot Tests | ✅ Complete |
| **Stage 4** | **Proactive Engine & Check-ins** | Contextual background scans, agreed follow-ups, daily routine check-ins | Routine Scans | ✅ Complete |
| **Stage 5** | **Natural Voice & Wake Word** | Hands-free "Hey AIRA", TTS/STT, Indian English (`en-IN`) acoustic tuning | Speech Tests | ✅ Complete |
| **Stage 6** | **Google Workspace Assistant** | Human-in-the-loop email drafts, agenda briefings, calendar preview cards | Workspace Mock | ✅ Complete |
| **Stage 7** | **Android Notification Assistant** | `NotificationListenerService`, OTP redaction, app allowlist, smart digest | Digest Tests | ✅ Complete |
| **Stage 8** | **Laptop Pairing & Device Bridge (Stage I)** | 6-digit PIN handshake, Bearer token auth, 30s TTL durable command envelope | 10 / 10 Passed | ✅ Complete |
| **Stage 9** | **Windows Digital Tasks (Stage J)** | Scoped file operations, reversible downloads organization, screen action safety | 15 / 15 Passed | ✅ Complete |
| **Stage 10** | **Android Actions (Stage K)** | Safe app launch allowlist, guided handoffs, sensitive boundary protection | 13 / 13 Passed | ✅ Complete |
| **Stage 11** | **Multi-Step Problem Solving (Stage L)** | Bounded 2–8 step goal planner, parallel read-only execution, resumable state | 14 / 14 Passed | ✅ Complete |
| **Stage 12** | **Daily Reliability & Release (Stage M)** | Emergency kill switch, connection diagnostics, redacted logger, GDPR wipe | 7 / 7 Passed | ✅ Complete |

---

## 💻 Laptop Computer Vision & 0ms Trackpad

- **Multimodal Visual Grounding (`vision_agent.py`)**: Uses Groq's `llama-3.2-11b-vision-preview` to detect normalized $(x, y)$ coordinates of requested UI buttons (e.g. search bars, menus) and physically clicks them with pixel precision.
- **Self-Healing ReAct Action Loop (`agent_runner.py`)**: If any step encounters an error or popup, an autonomous reflection engine analyzes the failure, requests an alternative recovery plan, and retries automatically.
- **0ms Win32 ctypes Trackpad (`main.py` & `mouse_control.py`)**: Bypasses slow high-level wrappers by executing direct C-level Windows Kernel calls (`ctypes.windll.user32.mouse_event`) for instant, lag-free cursor glide and vertical scrolling.

---

## 📡 Superpower: Notification Intelligence & Social World Radar

AIRA-OS includes dedicated on-device intelligence for capturing and synthesizing incoming alerts and public web signals:

1. **Android Notification Interceptor & Smart Digest (`AiraNotificationListenerService.kt` & `notification_monitor_service.dart`)**:
   - Intercepts incoming Android notifications across all apps (WhatsApp, Telegram, Gmail, SMS, Banking, Swiggy, Instagram).
   - Real-time categorizer groups alerts into 5 dedicated buckets: `💬 Chats`, `📧 Email & Work`, `💳 Finance & OTPs`, `🍔 Delivery`, and `📢 Social`.
   - On-demand AI synthesis: Turn 50+ messy notifications into a structured 4-bullet executive briefing with one tap or chat command (*"Summarize my notifications"*).

2. **Social World & Tech Radar (`social_world_monitor_service.dart`)**:
   - Zero-auth public feed aggregator streaming live signals from **Hacker News Firebase API**, **Reddit r/technology / r/artificial**, and **National Tech Feeds**.
   - Generates daily 4-bullet executive briefings covering AI breakthroughs, India tech ecosystem updates, and actionable takeaways for developers.

3. **Intelligence & Monitor Command Center (`MonitorScreen`)**:
   - Dedicated 2D Serif dual-tab command center accessible via Settings or the Chat `+` sheet.

---

## 📂 Project Directory Structure

```
aira/
├── aira_app/                               # Flutter Android Mobile Application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── agent/                      # ── AGENTIC AI CORE ENGINE ──
│   │   │   │   ├── plan_models.dart        # Goal, step, and action tier models
│   │   │   │   ├── goal_planner_engine.dart# Goal decomposition & ReAct planner
│   │   │   │   ├── self_check_reflector.dart# Pre-action reflection critique
│   │   │   │   ├── action_guardrail_manager.dart# Human-in-the-loop safety tiers
│   │   │   │   ├── agent_tool_registry.dart# Dynamic tool auto-selection & schemas
│   │   │   │   ├── adaptive_outcome_learner.dart# Outcome learning from user edits
│   │   │   │   └── agent_orchestrator.dart # Multi-agent swarm orchestrator
│   │   │   ├── services/                   # Android bridges, LLM fallback, voice, memory
│   │   │   ├── theme/                      # Claude terracotta & warm dark theme
│   │   │   └── widgets/                    # Reusable tactile UI components
│   │   ├── features/
│   │   │   ├── chat/                       # Chat workspace, live cards, and intent detectors
│   │   │   ├── laptop/                     # 0ms Trackpad, AI Agent tab, and quick prompts
│   │   │   ├── planner/                    # TickTick task manager & Schedule Autopilot
│   │   │   ├── briefing/                   # Daily news, India hackathons, and CSE tips
│   │   │   └── settings/                   # Mode selector, API keys, and memory inspector
│   │   └── main.dart                       # App entry point & service initialization
│   └── test/                               # Automated proof-of-work test suites
│
├── aira_desktop/                           # Python Windows Desktop Agent
│   ├── main.py                             # FastAPI server (Port 8765, PIN auth)
│   ├── vision_agent.py                     # Multimodal screen grounding (Groq Vision)
│   ├── agent_runner.py                     # Self-healing ReAct Windows action runner
│   ├── mouse_control.py                    # 0ms Win32 ctypes mouse simulation
│   ├── screen_capture.py                   # High-speed screen grabber (MSS)
│   ├── start_aira_desktop.bat              # One-click desktop startup script
│   └── requirements.txt                    # Python dependencies
│
└── README.md                               # Master technical documentation
```

---

## ⚡ Getting Started & Installation

### 1. 💻 Start Desktop Agent (Windows Laptop)
1. Navigate to the `aira_desktop` directory:
   ```cmd
   cd aira_desktop
   pip install -r requirements.txt
   ```
2. Launch the desktop companion:
   ```cmd
   start_aira_desktop.bat
   ```
   *Or for a persistent background system tray companion:*
   ```cmd
   python tray_companion.py
   ```
   *To automatically start AIRA Desktop whenever Windows boots:*
   ```cmd
   install_startup.bat
   ```
3. The terminal or tray notification will display your **Local IP Address** (e.g. `192.168.1.5`), **Port `8765`**, and default **PIN `123456`**.

---

### 2. 📱 Run or Install Mobile App (Android)

#### Option A: Install Standalone Latest APK
Transfer and install the pre-compiled debug APK directly to your phone:
- Path: `AIRA-OS-Real-Latest.apk` *(~198.2 MB)*

```powershell
adb install -r "AIRA-OS-Real-Latest.apk"
```

#### Option B: Run from Source
```bash
cd aira_app
flutter pub get
flutter run --debug
```

---

### 3. 🔗 Pair Phone to Laptop
1. Open **AIRA-OS** on your Android phone.
2. In chat, type:
   > *"Pair with my laptop at 192.168.x.x with PIN 123456"*
   *(or open Settings ⚙️ ➔ Laptop Companion).*
3. Verify the pairing confirmation card and begin executing remote Windows tasks!

---

## 🧪 Automated Cross-Platform Test Suite (176 / 176 Tests Passing — 100%)

AIRA-OS includes an exhaustive automated verification suite validating both the mobile application (`aira_app`) and the desktop companion (`aira_desktop`):

### 1. 📱 Mobile Test Suite (`aira_app` — 156 Tests)
Run the complete mobile test suite:
```bash
cd aira_app
flutter test --no-pub
```

- **Google Workspace Milestone 1**: 7/7 passed (dual-mode live OAuth2 & offline sandbox for Gmail, Calendar, Docs, Drive, Sheets, and People API).
- **Supabase Chat Persistence**: 3/3 passed (Hive offline-first hybrid message caching, cold restart recovery, zero message loss).
- **Agentic Multi-Modal & Intent Audit**: 13/13 passed (AIRA Vision, Meeting Summarizer, Proactive Reminders, Routines, Approval Cards, Context Preservation).
- **Google Drive File Picker**: 1/1 passed (visual bottom-sheet picker integrated into chat attachment menu).
- **Stage M (Daily Reliability & Kill Switch)**: 7/7 passed (emergency pause, setup checklist, connection diagnostics, redacted logger, GDPR wipe).
- **Stage L (Multi-Step Problem Solving)**: 14/14 passed (bounded 2–8 step planner, concurrency, crash resumption, evidence synthesis).
- **Stage K (Android Actions)**: 13/13 passed (app allowlist, messaging/calendar/navigation intents, sensitive boundary halts).
- **Stage J (Windows Digital Tasks)**: 15/15 passed (scoped path security, reversible downloads organization, screen action safety).
- **Stage I (Laptop Pairing & Bridge)**: 10/10 passed (6-digit PIN handshake, Bearer token auth, 30s TTL commands, idempotency receipts).
- **Stage H (Notification Assistant)**: 6/6 passed (real-time classification, OTP redaction, allowlist, AI digest generation).
- **6-Phase Agentic AI Engine**: 20/20 passed (Goal Planner, Pre-Action Reflection, Guardrail tiers, Tool Registry, Adaptive Outcome Learner, Swarm Orchestrator).
- **Smart Reply & Anti-Bot**: 8/8 passed (strict Review-Before-Send guarantee, randomized human-like delay, zero auto-send).
- **Offline Auth & Session Persistence**: 6/6 passed (instant guest demo, cold-start session restore, sign-out cleanup, local credentials).
- **LLM Fallback & Diagnostics**: 6/6 passed (Groq ➔ Gemini ➔ OpenRouter fallback, key sanitization, 401/429 diagnostics).
- **Device & Phone Intents**: 27/27 passed (voice notes, briefing feed, device hardware triggers).

### 2. 💻 Desktop Companion Test Suite (`aira_desktop` — 20 Tests)
Run the desktop companion test suite:
```bash
cd aira_desktop
python -m pytest test_aira_desktop.py
```

- **API & Health**: 2/2 passed (`/health` endpoint, `/automation/status` reporting).
- **Pairing & Security Handshake**: 5/5 passed (6-digit PIN generation with 5-min TTL, invalid PIN rejection, Bearer token issuance, 423 locked state when remote is paused, 403 rejection on revoked tokens).
- **Durable Command Receipts**: 1/1 passed (idempotent receipt tracking and 250-receipt circular buffer bounding).
- **File Manager Safety & System Boundaries**: 10/10 passed (human size formatting, safe listing, path traversal blocking, Windows system prefix lockouts, read/delete safety guardrails, rename traversal defense, FastAPI endpoint enforcement).
- **WebSocket 0ms Trackpad**: 2/2 passed (PIN/Bearer token WebSocket handshake, ping-pong liveness, ctypes direct hardware mouse glide).

### 3. 🔍 Static Analysis
- Mobile: `flutter analyze lib/ --no-pub` reports **0 errors, 0 warnings, 0 lints**.
- Desktop: `python -m py_compile` reports **0 syntax or import errors across all 9 modules**.

---

## 🏆 Smart India Hackathon (SIH) Demo Flow

1. **Step 1 — Hands-Free Wake Word & AppBar Pill**: Tap the mic or speak *"Hey AIRA"*. Point to the live date and TickTick agenda pill.
2. **Step 2 — High-Level Goal Execution**: Say *"Handle my morning: check my agenda, time-block my day, and check tech news."* Show the live `PlanExecutionCard` dynamically checking off steps.
3. **Step 3 — Self-Check & Approval Guardrail**: Say *"Draft an email to the team regarding our submission deadline."* Show how the reflection engine cleans placeholders and **pauses at the interactive Action Approval Card**.
4. **Step 4 — Laptop Vision & 0ms Trackpad**: Open Laptop Remote, show zero-latency cursor glide on your monitor, and execute an autonomous laptop goal (*"Open YouTube and search hackathon projects"*).

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
