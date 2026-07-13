"""Voice processing API endpoints."""

from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status
from fastapi.responses import Response
from pydantic import BaseModel
from app.core.middleware import get_current_user
from app.services.voice_service import get_voice_service

router = APIRouter(prefix="/voice", tags=["Voice"])


class TTSRequest(BaseModel):
    text: str
    lang: str = "en"


@router.post("/stt")
async def speech_to_text(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user),
) -> dict:
    """Transcribe uploaded audio files to text."""
    if not file.filename.lower().endswith((".wav", ".mp3", ".m4a", ".ogg", ".webm")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported audio format. Use WAV, MP3, or M4A",
        )
    
    contents = await file.read()
    service = get_voice_service()
    transcript = await service.speech_to_text(contents, file.filename)
    return {"transcript": transcript}


@router.post("/tts")
async def text_to_speech(
    body: TTSRequest,
    user_id: str = Depends(get_current_user),
):
    """Convert text into spoken voice audio bytes."""
    if not body.text.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Text cannot be empty",
        )
    
    service = get_voice_service()
    audio_bytes = await service.text_to_speech(body.text, body.lang)
    
    return Response(
        content=audio_bytes,
        media_type="audio/mpeg",
        headers={"Content-Disposition": "attachment; filename=voice.mp3"},
    )
