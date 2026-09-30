from __future__ import annotations

import hashlib
import time
import uuid

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.config import settings
from app.db.store import Store


router = APIRouter(prefix="/profiles", tags=["profiles"])
store = Store(settings.data_dir / "app.sqlite3")
store.init()


def _hash_pin(pin: str) -> str:
    if len(pin) != 4 or not pin.isdigit():
        raise ValueError("PIN must be 4 digits")
    return hashlib.sha256((settings.app_secret + ":" + pin).encode("utf-8")).hexdigest()


class PinLoginRequest(BaseModel):
    pin: str = Field(min_length=4, max_length=4)


class PinLoginResponse(BaseModel):
    profile_id: str


@router.post("/pin-login", response_model=PinLoginResponse)
def pin_login(body: PinLoginRequest) -> PinLoginResponse:
    try:
        pin_hash = _hash_pin(body.pin)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # One local device can have multiple profiles; for MVP create one profile per PIN.
    profile_id = str(uuid.uuid5(uuid.NAMESPACE_OID, pin_hash))
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    store.upsert_profile(profile_id=profile_id, pin_hash=pin_hash, created_at=now)
    store.upsert_profile_data(profile_id=profile_id, updated_at=now)
    return PinLoginResponse(profile_id=profile_id)

