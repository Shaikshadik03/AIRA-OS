"""Tool definitions for Groq function calling."""

AIRA_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "create_task",
            "description": "Create a new task in the user's planner and sync it to Google Tasks.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "The title or name of the task.",
                    },
                    "description": {
                        "type": "string",
                        "description": "Detailed description of the task.",
                    },
                    "due_date": {
                        "type": "string",
                        "description": "Due date in YYYY-MM-DD format (optional).",
                    },
                },
                "required": ["title"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "draft_email",
            "description": "Draft an email in the user's Gmail account.",
            "parameters": {
                "type": "object",
                "properties": {
                    "to": {
                        "type": "string",
                        "description": "Recipient email address.",
                    },
                    "subject": {
                        "type": "string",
                        "description": "Email subject.",
                    },
                    "body": {
                        "type": "string",
                        "description": "Email body content.",
                    },
                },
                "required": ["to", "subject", "body"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_calendar_events",
            "description": "Get upcoming events from the user's Google Calendar.",
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {
                        "type": "integer",
                        "description": "Number of days ahead to look for events (default 7).",
                    }
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_web",
            "description": "Search the web for current information, news, or technical queries.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "The search query to look up.",
                    }
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "ticktick_create_task",
            "description": "Create a task in TickTick account via MCP connector.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "The title or action of the task (e.g. 'Buy groceries')",
                    },
                    "content": {
                        "type": "string",
                        "description": "Optional notes or details.",
                    },
                    "due_date": {
                        "type": "string",
                        "description": "Optional target due date or date time string.",
                    },
                },
                "required": ["title"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "ticktick_get_tasks",
            "description": "Get current or pending tasks from TickTick account via MCP connector.",
            "parameters": {
                "type": "object",
                "properties": {
                    "filter": {
                        "type": "string",
                        "description": "Filter criteria: 'today', 'all', 'upcoming'.",
                    }
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "ticktick_complete_task",
            "description": "Mark a task complete in TickTick via MCP connector.",
            "parameters": {
                "type": "object",
                "properties": {
                    "task_id": {
                        "type": "string",
                        "description": "Task ID or title to complete.",
                    }
                },
                "required": ["task_id"],
            },
        },
    },
]
