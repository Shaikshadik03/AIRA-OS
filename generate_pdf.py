import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Times-Roman", 9)
        self.setFillColor(colors.HexColor("#6B655D"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, 11 * 72 - 36, "AIRA-OS — Master Technical Architecture & Hackathon Guide")
            self.setStrokeColor(colors.HexColor("#D8D2C4"))
            self.setLineWidth(0.5)
            self.line(54, 11 * 72 - 42, 8.5 * 72 - 54, 11 * 72 - 42)
            
        # Footer
        footer_text = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(8.5 * 72 - 54, 36, footer_text)
        self.drawString(54, 36, "Smart India Hackathon (SIH) Technical Master Reference")
        self.setStrokeColor(colors.HexColor("#D8D2C4"))
        self.setLineWidth(0.5)
        self.line(54, 48, 8.5 * 72 - 54, 48)
        self.restoreState()

def build_pdf(filename):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    # Serif Typography Styles
    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Times-Bold',
        fontSize=26,
        leading=30,
        textColor=colors.HexColor('#1E1C1A'),
        alignment=0,
        spaceAfter=8
    )

    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Times-Italic',
        fontSize=13,
        leading=17,
        textColor=colors.HexColor('#C45532'),
        spaceAfter=18
    )

    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Normal'],
        fontName='Times-Bold',
        fontSize=17,
        leading=21,
        textColor=colors.HexColor('#1E1C1A'),
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )

    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Normal'],
        fontName='Times-Bold',
        fontSize=12.5,
        leading=16,
        textColor=colors.HexColor('#8C4328'),
        spaceBefore=10,
        spaceAfter=5,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'SerifBody',
        parent=styles['Normal'],
        fontName='Times-Roman',
        fontSize=10,
        leading=14.5,
        textColor=colors.HexColor('#2C2825'),
        spaceAfter=6
    )

    bullet_style = ParagraphStyle(
        'SerifBullet',
        parent=styles['Normal'],
        fontName='Times-Roman',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor('#2C2825'),
        leftIndent=14,
        firstLineIndent=-10,
        spaceAfter=4
    )

    code_style = ParagraphStyle(
        'CodeSnippet',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor('#1A1816')
    )

    callout_style = ParagraphStyle(
        'CalloutText',
        parent=styles['Normal'],
        fontName='Times-Italic',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor('#1E1C1A')
    )

    story = []

    # Title & Metadata Banner
    story.append(Paragraph("AIRA-OS: Autonomous Agentic Operating System", title_style))
    story.append(Paragraph("Complete Technical Architecture, Codebase Specification & SIH Presentation Guide", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor('#C45532'), spaceAfter=14))

    # Executive Overview
    overview_text = (
        "<b>AIRA-OS</b> is an autonomous, cross-device personal AI Operating System bridging an Android mobile device "
        "and a Windows laptop into a unified intelligent environment. Unlike traditional reactive chatbots that merely "
        "generate text responses, AIRA decomposes high-level goals into multi-step execution plans, grounds visual UI elements "
        "via multimodal vision, enforces human-in-the-loop safety guardrails, and continuously calibrates its behavior via adaptive learning."
    )
    
    callout_data = [[Paragraph(overview_text, callout_style)]]
    callout_table = Table(callout_data, colWidths=[504])
    callout_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8F5EE')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#E2DACE')),
        ('LINELEFT', (0,0), (0,0), 3.5, colors.HexColor('#C45532')),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
    ]))
    story.append(callout_table)
    story.append(Spacer(1, 14))

    # Section 1: Architecture Layers
    story.append(Paragraph("1. Three-Tier System Architecture", h1_style))
    story.append(Paragraph(
        "The system operates across three tightly integrated layers communicating over secure local network protocols and cloud API fallback chains:",
        body_style
    ))

    arch_table_data = [
        [
            Paragraph("<b>Layer</b>", body_style),
            Paragraph("<b>Core Technologies</b>", body_style),
            Paragraph("<b>Primary Responsibilities</b>", body_style)
        ],
        [
            Paragraph("<b>1. Mobile Client</b><br/>(Android)", body_style),
            Paragraph("Flutter, Dart, Riverpod, MethodChannels, SpeechToText, FlutterTTS", body_style),
            Paragraph("User interface, live plan execution streaming, voice interaction, Android hardware controls (alarms, torch, calls, app launcher).", body_style)
        ],
        [
            Paragraph("<b>2. Desktop Agent</b><br/>(Windows)", body_style),
            Paragraph("Python 3.10+, FastAPI, Uvicorn, Win32 ctypes, PyAutoGUI, MSS", body_style),
            Paragraph("Zero-latency mouse trackpad acceleration, multimodal visual screen grounding, terminal execution, file system management.", body_style)
        ],
        [
            Paragraph("<b>3. Intelligence Brain</b><br/>(AI & Cloud)", body_style),
            Paragraph("Groq (Llama-3), Gemini 1.5, OpenRouter, SharedPreferences, Supabase pgvector", body_style),
            Paragraph("Goal planning, self-check reflection critic, guardrail action tiers, adaptive memory learning, and multi-agent role orchestration.", body_style)
        ]
    ]

    t_arch = Table(arch_table_data, colWidths=[110, 160, 234])
    t_arch.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFECE4')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#D8D2C4')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_arch)
    story.append(Spacer(1, 14))

    # Section 2: Complete Codebase Tree
    story.append(Paragraph("2. Complete Codebase Structure & File Inventory", h1_style))
    story.append(Paragraph(
        "Below is the complete structural breakdown of all directories and key functional modules in the AIRA repository:",
        body_style
    ))

    tree_data = [
        [
            Paragraph("<b>Path / Module</b>", body_style),
            Paragraph("<b>Component Role & Implementation Details</b>", body_style)
        ],
        [
            Paragraph("<code>lib/core/agent/goal_planner_engine.dart</code>", code_style),
            Paragraph("Decomposes natural language user goals into structured JSON ReAct subtask graphs. Assigns tool mappings and execution tiers.", body_style)
        ],
        [
            Paragraph("<code>lib/core/agent/self_check_reflector.dart</code>", code_style),
            Paragraph("Pre-action reflection critic. Scans generated drafts for corporate filler, placeholder brackets, and tone inaccuracies. Persists audit logs.", body_style)
        ],
        [
            Paragraph("<code>lib/core/agent/action_guardrail_manager.dart</code>", code_style),
            Paragraph("Enforces safety tiers (Free-Run vs. Approval-Required). Halts execution for sensitive actions (emails, SMS, calls, deletions) until approved.", body_style)
        ],
        [
            Paragraph("<code>lib/core/agent/agent_tool_registry.dart</code>", code_style),
            Paragraph("Dynamic tool registry with JSON schemas. Auto-selects between live web search, native alarms, n8n workflows, and laptop actions.", body_style)
        ],
        [
            Paragraph("<code>lib/core/agent/adaptive_outcome_learner.dart</code>", code_style),
            Paragraph("Monitors user edits and approval decisions. Dynamically injects learned brevity and style rules into system prompts.", body_style)
        ],
        [
            Paragraph("<code>lib/core/agent/agent_orchestrator.dart</code>", code_style),
            Paragraph("Multi-agent swarm router delegating across SchedulerSubAgent, EmailCommsSubAgent, MemoryLearningSubAgent, and AutomationDeviceSubAgent.", body_style)
        ],
        [
            Paragraph("<code>lib/features/chat/presentation/widgets/</code>", code_style),
            Paragraph("Contains <code>PlanExecutionCard</code> (live animated progress card), <code>ActionApprovalCard</code> (interactive approval modal), and <code>MessageBubble</code>.", body_style)
        ],
        [
            Paragraph("<code>aira_desktop/vision_agent.py</code>", code_style),
            Paragraph("Multimodal screen grounding using Groq Llama-3.2-11B-Vision. Calculates exact (x, y) coordinates of UI elements and verifies screen state.", body_style)
        ],
        [
            Paragraph("<code>aira_desktop/agent_runner.py</code>", code_style),
            Paragraph("Autonomous self-healing ReAct action loop on Windows. Diagnoses execution failures and generates dynamic recovery steps.", body_style)
        ],
        [
            Paragraph("<code>aira_desktop/main.py</code>", code_style),
            Paragraph("FastAPI server hosting endpoints for trackpad ctypes acceleration, clipboard synchronization, terminal shell execution, and PIN auth.", body_style)
        ]
    ]

    t_tree = Table(tree_data, colWidths=[190, 314])
    t_tree.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFECE4')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#D8D2C4')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_tree)
    story.append(Spacer(1, 14))

    # Page Break for Deep Dive
    story.append(PageBreak())

    # Section 3: The 6-Phase Agentic Execution Pipeline
    story.append(Paragraph("3. The 6-Phase Agentic Execution Pipeline", h1_style))
    story.append(Paragraph(
        "AIRA's intelligence core operates through a rigorous 6-phase sequential pipeline designed to maximize autonomy while guaranteeing safety:",
        body_style
    ))

    phases = [
        ("Phase 1: Goal Planning Layer (ReAct Decomposition)", 
         "Accepts an unstructured, high-level goal (e.g., 'Handle my morning'). Instead of executing blindly, it prompts the LLM to return an ordered dependency graph of subtasks with assigned tools and safety tiers. Streams live state updates to the UI."),
        
        ("Phase 2: Reflection & Self-Check Loop", 
         "Acts as an internal critic. Before sensitive communications (emails, SMS, messages) are dispatched, the reflector scans the draft for robotic filler phrases ('I hope this finds you well'), unresolved placeholder brackets ('[Insert Date]'), and tone mismatches. Emits a refined draft and logs the audit record."),
        
        ("Phase 3: Human-in-the-Loop Guardrail Tiers", 
         "Strictly partitions actions into two categories:\n"
         "• Free-Run Tier: Safe queries, calendar reads, note creations, alarms, web searches.\n"
         "• Approval-Required Tier: External emails, phone calls, SMS messages, file deletions, payment triggers.\n"
         "For approval actions, execution pauses and renders an interactive card with Approve, Edit, and Reject buttons."),
        
        ("Phase 4: Tool Registry & Dynamic Auto-Selection", 
         "Replaces brittle regex keywords with a schema-based tool dispatcher. Matches subtask intent against tool descriptions to invoke web search, native Android services, laptop automation, or external n8n workflows automatically."),
        
        ("Phase 5: Adaptive Memory & Outcome Learning", 
         "Tracks the history of user decisions (accepted, edited, rejected). When a user repeatedly edits drafts (e.g., trimming long emails), the engine computes character deltas and injects persistent XML directives (&lt;adaptive_learned_preferences&gt;) into future prompts."),
        
        ("Phase 6: Multi-Agent Role Split & Swarm Orchestrator", 
         "Decomposes complex multi-domain instructions across specialized sub-agents: SchedulerSubAgent (agenda & deadlines), EmailCommsSubAgent (communication & drafting), MemoryLearningSubAgent (preference tracking), and AutomationDeviceSubAgent (hardware execution).")
    ]

    for p_title, p_desc in phases:
        story.append(Paragraph(p_title, h2_style))
        story.append(Paragraph(p_desc.replace('\n', '<br/>'), body_style))
        story.append(Spacer(1, 4))

    story.append(Spacer(1, 10))

    # Section 4: Comprehensive Technical Glossary
    story.append(Paragraph("4. Technical Glossary & Key Concepts Dictionary", h1_style))
    story.append(Paragraph(
        "Essential technical terms used across AIRA-OS that every team member should know and explain at hackathons:",
        body_style
    ))

    glossary_data = [
        [
            Paragraph("<b>Term</b>", body_style),
            Paragraph("<b>Definition & Context in AIRA-OS</b>", body_style)
        ],
        [
            Paragraph("<b>Agentic AI</b>", body_style),
            Paragraph("An AI system capable of autonomous goal pursuit, multi-step planning, tool usage, environment perception, and self-correction, rather than simple single-turn conversation.", body_style)
        ],
        [
            Paragraph("<b>ReAct Pattern</b>", body_style),
            Paragraph("<b>Reason + Act</b>: A prompting paradigm where the LLM interleaves chain-of-thought reasoning with tool execution actions to solve complex multi-step problems.", body_style)
        ],
        [
            Paragraph("<b>MethodChannel</b>", body_style),
            Paragraph("The native communication bridge in Flutter that allows Dart code to invoke platform-specific Java/Kotlin methods on Android (e.g., hardware camera, flashlight, alarms).", body_style)
        ],
        [
            Paragraph("<b>Win32 ctypes</b>", body_style),
            Paragraph("Python foreign function library used to call Windows C-kernel APIs (<code>user32.dll</code>) directly, enabling 0-millisecond trackpad cursor movements without overhead.", body_style)
        ],
        [
            Paragraph("<b>Visual Grounding</b>", body_style),
            Paragraph("The process of taking a screen image, parsing UI elements through a multimodal Vision LLM, and predicting normalized (x, y) coordinates to physically click buttons.", body_style)
        ],
        [
            Paragraph("<b>Human-in-the-Loop</b>", body_style),
            Paragraph("A safety architecture where high-risk AI actions are halted in a pending state until a human user explicitly reviews and approves the execution.", body_style)
        ],
        [
            Paragraph("<b>State Management (Riverpod)</b>", body_style),
            Paragraph("A reactive, compile-safe state management framework for Flutter that decouples business logic from UI widgets and manages data streams cleanly.", body_style)
        ],
        [
            Paragraph("<b>LLM Fallback Chain</b>", body_style),
            Paragraph("A resilient multi-provider pipeline that routes requests from Primary (Groq) to Fallback 1 (Gemini) to Fallback 2 (OpenRouter) to prevent system downtime.", body_style)
        ]
    ]

    t_gloss = Table(glossary_data, colWidths=[140, 364])
    t_gloss.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFECE4')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#D8D2C4')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_gloss)
    story.append(Spacer(1, 14))

    # Page Break for Hackathon Strategy
    story.append(PageBreak())

    # Section 5: Smart India Hackathon (SIH) Presentation Strategy
    story.append(Paragraph("5. Smart India Hackathon (SIH) Presentation Guide", h1_style))
    story.append(Paragraph(
        "Strategic presentation flow designed to captivate judges within 3 minutes and demonstrate clear novelty:",
        body_style
    ))

    story.append(Paragraph("A. The 60-Second Opening Pitch", h2_style))
    pitch_text = (
        "\"Most AI tools today are reactive chatbots that only output text, while traditional voice assistants like Siri "
        "are rigid command executors. We built <b>AIRA-OS</b> — a unified Agentic Operating System connecting your phone "
        "and laptop into a single autonomous mind. You give one goal, AIRA decomposes the plan, sees your laptop screen, "
        "executes native actions, self-checks for errors, guards sensitive actions with approval modals, and learns your preferences over time.\""
    )
    story.append(Paragraph(pitch_text, callout_style))
    story.append(Spacer(1, 8))

    story.append(Paragraph("B. 3-Minute Live Demonstration Flow", h2_style))
    story.append(Paragraph("• <b>Step 1 — Hands-Free Trigger & Laptop Connection:</b> Open AIRA, show the TickTick agenda pill and live date in the AppBar. Speak <i>'Hey AIRA'</i> or tap the AppBar mic.", bullet_style))
    story.append(Paragraph("• <b>Step 2 — Goal Decomposition & Live Card:</b> Say <i>'Handle my morning: check my agenda, time-block my day, and check tech headlines.'</i> Point to the live <code>PlanExecutionCard</code> showing animated step spinners and checkmarks.", bullet_style))
    story.append(Paragraph("• <b>Step 3 — Self-Check & Approval Guardrail:</b> Say <i>'Draft an email to the team regarding our submission deadline.'</i> Show how the reflection engine cleans placeholders and <b>pauses at the interactive Action Approval Card</b> awaiting your tap.", bullet_style))
    story.append(Paragraph("• <b>Step 4 — Laptop Vision & 0ms Trackpad:</b> Open Laptop Remote, demonstrate seamless 0ms cursor glide via Win32 ctypes, and run an autonomous laptop task (<i>'Open YouTube and search hackathon projects'</i>).", bullet_style))
    story.append(Spacer(1, 8))

    story.append(Paragraph("C. Judge Q&A Defense Matrix", h2_style))

    qa_data = [
        [
            Paragraph("<b>Potential Judge Question</b>", body_style),
            Paragraph("<b>Definitive Technical Answer</b>", body_style)
        ],
        [
            Paragraph("<b>Q: How do you prevent hallucinated or dangerous actions?</b>", body_style),
            Paragraph("<b>A:</b> We implemented a two-tier guardrail architecture (<code>ActionGuardrailManager</code>). Read-only actions run free, while write/send/delete actions are held in a pending state. Our Self-Check Reflector verifies accuracy before presenting an interactive approval card.", body_style)
        ],
        [
            Paragraph("<b>Q: Why not use existing cloud assistants?</b>", body_style),
            Paragraph("<b>A:</b> Commercial assistants cannot see your computer screen, run local terminal scripts, or time-block academic schedules dynamically. AIRA provides true multimodal computer use and cross-device symbiosis over local Wi-Fi with zero external cloud latency.", body_style)
        ],
        [
            Paragraph("<b>Q: How does AIRA adapt to user habits?</b>", body_style),
            Paragraph("<b>A:</b> Our Adaptive Outcome Learner logs decisions (accept/edit/reject) and computes length/tone deltas. Over time, it injects calibrated behavioral directives into the personality system prompt.", body_style)
        ]
    ]

    t_qa = Table(qa_data, colWidths=[170, 334])
    t_qa.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFECE4')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#D8D2C4')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_qa)

    # Build document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF successfully generated at: {filename}")

if __name__ == "__main__":
    output_path = r"C:\Users\arsha\.gemini\antigravity\scratch\aira\AIRA_OS_Master_Technical_Architecture.pdf"
    build_pdf(output_path)
