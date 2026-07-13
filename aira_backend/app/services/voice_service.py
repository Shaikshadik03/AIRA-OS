"""Voice Service - Handles Speech-to-Text (Whisper) and Text-to-Speech (gTTS)."""

import logging
import os
import io
from gtts import gTTS
from groq import AsyncGroq
from app.config.settings import get_settings

logger = logging.getLogger("aira.voice")


class VoiceService:
    """Manages STT transcription via Groq/Whisper and TTS synthesis via gTTS."""

    def __init__(self) -> None:
        settings = get_settings()
        self.client = AsyncGroq(api_key=settings.groq_api_key)

    async def speech_to_text(self, audio_file_bytes: bytes, filename: str = "input.wav") -> str:
        """Transcribe uploaded audio bytes using Groq's whisper model."""
        try:
            logger.info("Transcribing audio file...")
            # Groq SDK requires a tuple (filename, bytes_file, mime_type) for files
            file_tuple = (filename, io.BytesIO(audio_file_bytes), "audio/wav")

            response = await self.client.audio.transcriptions.create(
                file=file_tuple,
                model="whisper-large-v3",
                response_format="json",
            )
            return response.text if hasattr(response, "text") else response.get("text", "")

        except Exception as e:
            logger.error(f"Speech to text failed: {e}")
            raise

    async def text_to_speech(self, text: str, lang: str = "en") -> bytes:
        """Convert text into MP3 audio bytes using gTTS."""
        try:
            logger.info(f"Synthesizing text: {text[:40]}...")
            
            # gTTS operates synchronously, so wrap it in an executor or execute directly
            # since gTTS is lightweight, a quick BytesIO write is fine.
            tts = gTTS(text=text, lang=lang, slow=False)
            
            fp = io.BytesIO()
            tts.write_to_fp(fp)
            fp.seek(0)
            
            return fp.read()

        except Exception as e:
            logger.error(f"Text to speech failed: {e}")
            raise


def get_voice_service() -> VoiceService:
    """Get voice service instance."""
    return VoiceService()
