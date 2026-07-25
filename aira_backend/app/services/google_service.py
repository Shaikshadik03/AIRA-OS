"""Google Workspace API Integration Service."""

import logging
from datetime import datetime
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from app.config.database import get_supabase_admin_client

logger = logging.getLogger("aira.google_service")

# Required scopes for AIRA
SCOPES = [
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/gmail.send'
]


class GoogleService:
    """Handles Google Workspace integrations (Tasks, Calendar, Gmail)."""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = get_supabase_admin_client()
        self.creds = self._get_credentials()

    def _get_credentials(self) -> Credentials | None:
        """Fetch and refresh user's Google credentials from the database."""
        result = (
            self.db.table("user_integrations")
            .select("*")
            .eq("user_id", self.user_id)
            .eq("provider", "google")
            .single()
            .execute()
        )

        if not result.data:
            return None

        # Build credentials object
        import os
        client_id = os.getenv("GOOGLE_CLIENT_ID", "dummy_client_id")
        client_secret = os.getenv("GOOGLE_CLIENT_SECRET", "dummy_client_secret")

        creds = Credentials(
            token=result.data.get("access_token"),
            refresh_token=result.data.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=client_id,
            client_secret=client_secret,
            scopes=result.data.get("scopes", SCOPES),
        )

        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
                # Update DB with new access token
                self.db.table("user_integrations").update(
                    {"access_token": creds.token}
                ).eq("user_id", self.user_id).eq("provider", "google").execute()
            except Exception as e:
                logger.error(f"Failed to refresh Google token for user {self.user_id}: {e}")
                return None

        return creds

    def is_connected(self) -> bool:
        """Check if the user has a valid Google connection."""
        return self.creds is not None and self.creds.valid

    # --- Google Tasks ---
    
    def sync_task(self, local_task_id: str, title: str, description: str | None, due_date: str | None, completed: bool) -> dict | None:
        """Create or update a task in Google Tasks."""
        if not self.is_connected():
            return None

        try:
            service = build('tasks', 'v1', credentials=self.creds)
            
            # Check if mapping exists
            mapping = self.db.table("google_task_mappings").select("*").eq("local_task_id", local_task_id).execute()
            
            task_body = {
                "title": title,
                "notes": description or "",
                "status": "completed" if completed else "needsAction",
            }
            if due_date:
                # Format: YYYY-MM-DDTHH:MM:SS.000Z
                task_body["due"] = f"{due_date}T00:00:00.000Z"

            if mapping.data:
                # Update existing
                g_task_id = mapping.data[0]["google_task_id"]
                g_list_id = mapping.data[0]["google_task_list_id"]
                result = service.tasks().update(tasklist=g_list_id, task=g_task_id, body=task_body).execute()
                return result
            else:
                # Create new
                # Get default task list
                lists = service.tasklists().list().execute()
                if not lists.get('items'):
                    return None
                g_list_id = lists['items'][0]['id']
                
                result = service.tasks().insert(tasklist=g_list_id, body=task_body).execute()
                
                # Save mapping
                self.db.table("google_task_mappings").insert({
                    "user_id": self.user_id,
                    "local_task_id": local_task_id,
                    "google_task_list_id": g_list_id,
                    "google_task_id": result['id']
                }).execute()
                
                return result
                
        except Exception as e:
            logger.error(f"Google Tasks sync failed: {e}")
            return None

    def delete_task(self, local_task_id: str) -> bool:
        """Delete a task from Google Tasks if it exists."""
        if not self.is_connected():
            return False

        try:
            mapping = self.db.table("google_task_mappings").select("*").eq("local_task_id", local_task_id).execute()
            if not mapping.data:
                return True
                
            g_task_id = mapping.data[0]["google_task_id"]
            g_list_id = mapping.data[0]["google_task_list_id"]
            
            service = build('tasks', 'v1', credentials=self.creds)
            service.tasks().delete(tasklist=g_list_id, task=g_task_id).execute()
            
            # Remove mapping
            self.db.table("google_task_mappings").delete().eq("local_task_id", local_task_id).execute()
            return True
            
        except Exception as e:
            logger.error(f"Google Tasks delete failed: {e}")
            return False

    # --- Google Calendar ---
    
    def get_upcoming_events(self, max_results: int = 10) -> list[dict]:
        """Fetch upcoming calendar events."""
        if not self.is_connected():
            return []

        try:
            service = build('calendar', 'v3', credentials=self.creds)
            now = datetime.utcnow().isoformat() + 'Z'
            events_result = service.events().list(
                calendarId='primary', timeMin=now,
                maxResults=max_results, singleEvents=True,
                orderBy='startTime'
            ).execute()
            
            return events_result.get('items', [])
        except Exception as e:
            logger.error(f"Google Calendar fetch failed: {e}")
            return []

    # --- Gmail ---
    
    def send_email(self, to: str, subject: str, body: str) -> bool:
        """Send an email using Gmail API."""
        if not self.is_connected():
            return False

        try:
            service = build('gmail', 'v1', credentials=self.creds)
            from email.message import EmailMessage
            import base64

            message = EmailMessage()
            message.set_content(body)
            message['To'] = to
            message['Subject'] = subject

            encoded_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
            create_message = {'raw': encoded_message}

            service.users().messages().send(userId="me", body=create_message).execute()
            return True
        except Exception as e:
            logger.error(f"Gmail send failed: {e}")
            return False
