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
2. Launch the desktop server:
   ```cmd
   start_aira_desktop.bat
   ```
3. The terminal will display your **Local IP Address** (e.g. `192.168.1.5`), **Port `8765`**, and default **PIN `123456`**.

---

### 2. 📱 Run or Install Mobile App (Android)

#### Option A: Install Standalone Release APK
Transfer and install the pre-compiled release APK directly to your phone:
- Path: `aira_app/build/app/outputs/flutter-apk/app-release.apk` *(65.3 MB)*

#### Option B: Run from Source
```bash
cd aira_app
flutter pub get
flutter run --release
```

---

### 3. 🔗 Pair Phone to Laptop
1. Open **AIRA-OS** on your Android phone.
2. Tap **`+`** ➔ **Laptop Remote** (or top-right Settings ⚙️).
3. Enter your laptop's Local IP and PIN `123456`, then tap **Connect**.

---

## 🧪 Proof-of-Work Automated Test Suite

Verify all 6 Agentic AI phases and safety guardrails by running the automated test suite:

```bash
cd aira_app
flutter test test/phase1_proof_of_work_test.dart test/phase2_and_3_proof_of_work_test.dart test/phase4_5_6_proof_of_work_test.dart
```

### ✅ Verification Matrix
- **Phase 1 (Goal Planning)**: 3 distinct multi-step goals planned and executed end-to-end.
- **Phase 2 (Self-Check Reflection)**: Detected unfilled `[Insert Date]` placeholders & robotic phrases, auto-corrected drafts, and logged audit records.
- **Phase 3 (Human Guardrails)**: 5/5 approval-tier actions (`send_email`, `send_sms`, `make_call`, `workspace_delete`, `payment_send`) paused for confirmation.
- **Phase 4 (Tool Auto-Selection)**: Dynamically resolved 5 distinct tools without keyword hardcoding.
- **Phase 5 (Adaptive Memory)**: 10 interactions generated learned prompt constraint: `• USER PREFERENCE (LEARNED): User prefers ultra-concise emails`.
- **Phase 6 (Multi-Agent Swarm)**: Multi-domain goal successfully orchestrated across `Scheduler`, `EmailComms`, and `MemoryLearning` sub-agents.

---

## 🏆 Smart India Hackathon (SIH) Demo Flow

1. **Step 1 — Hands-Free Wake Word & AppBar Pill**: Tap the mic or speak *"Hey AIRA"*. Point to the live date and TickTick agenda pill.
2. **Step 2 — High-Level Goal Execution**: Say *"Handle my morning: check my agenda, time-block my day, and check tech news."* Show the live `PlanExecutionCard` dynamically checking off steps.
3. **Step 3 — Self-Check & Approval Guardrail**: Say *"Draft an email to the team regarding our submission deadline."* Show how the reflection engine cleans placeholders and **pauses at the interactive Action Approval Card**.
4. **Step 4 — Laptop Vision & 0ms Trackpad**: Open Laptop Remote, show zero-latency cursor glide on your monitor, and execute an autonomous laptop goal (*"Open YouTube and search hackathon projects"*).

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
