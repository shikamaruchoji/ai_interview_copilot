from __future__ import annotations

import hashlib
import time
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from app.core.config import settings
from app.core.crypto import Crypto
from app.db.store import Store
from app.services.text_extract import extract_text_from_file


router = APIRouter(prefix="/setup", tags=["setup"])
store = Store(settings.data_dir / "app.sqlite3")
store.init()
crypto = Crypto.from_secret(settings.app_secret)


class SetupStatusResponse(BaseModel):
    has_voice: bool
    has_resume: bool
    has_job: bool


@router.get("/status", response_model=SetupStatusResponse)
def status(profile_id: str) -> SetupStatusResponse:
    data = store.get_profile_data(profile_id)
    if not data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return SetupStatusResponse(
        has_voice=bool(data.get("voiceprint_b64")),
        has_resume=bool((data.get("resume_text") or "").strip()),
        has_job=bool((data.get("job_text") or "").strip()),
    )


@router.post("/job-text")
def upload_job_text(profile_id: str = Form(...), job_text: str = Form(...)) -> dict:
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    store.upsert_profile_data(profile_id=profile_id, updated_at=now, job_text=job_text.strip())
    return {"ok": True}


@router.post("/resume-file")
async def upload_resume_file(profile_id: str = Form(...), file: UploadFile = File(...)) -> dict:
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in [".pdf", ".docx", ".txt"]:
        raise HTTPException(status_code=400, detail="Unsupported file type. Use PDF/DOCX/TXT.")

    profile_dir = settings.data_dir / "uploads" / profile_id
    profile_dir.mkdir(parents=True, exist_ok=True)
    dst = profile_dir / f"resume{suffix}"

    content = await file.read()
    dst.write_bytes(content)

    text = extract_text_from_file(dst)
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    store.upsert_profile_data(profile_id=profile_id, updated_at=now, resume_text=text)
    return {"ok": True, "chars": len(text)}


@router.post("/job-file")
async def upload_job_file(profile_id: str = Form(...), file: UploadFile = File(...)) -> dict:
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in [".pdf", ".docx", ".txt"]:
        raise HTTPException(status_code=400, detail="Unsupported file type. Use PDF/DOCX/TXT.")

    profile_dir = settings.data_dir / "uploads" / profile_id
    profile_dir.mkdir(parents=True, exist_ok=True)
    dst = profile_dir / f"job{suffix}"

    content = await file.read()
    dst.write_bytes(content)

    text = extract_text_from_file(dst)
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    store.upsert_profile_data(profile_id=profile_id, updated_at=now, job_text=text)
    return {"ok": True, "chars": len(text)}


@router.post("/voice-enroll")
async def voice_enroll(profile_id: str = Form(...), file: UploadFile = File(...)) -> dict:
    # MVP: store an encrypted "voiceprint" derived from raw bytes (placeholder).
    # This keeps the contract so you can later swap in ECAPA/pyannote embeddings.
    content = await file.read()
    if len(content) < 4000:
        raise HTTPException(status_code=400, detail="Audio too short. Record 15–20 seconds.")

    digest = hashlib.sha256(content).digest()
    voiceprint_b64 = crypto.encrypt_to_b64(digest, aad=profile_id.encode("utf-8"))

    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    store.upsert_profile_data(profile_id=profile_id, updated_at=now, voiceprint_b64=voiceprint_b64)
    return {"ok": True}

