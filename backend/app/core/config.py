from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


load_dotenv()


@dataclass(frozen=True)
class Settings:
    app_env: str = os.getenv("APP_ENV", "dev")
    app_secret: str = os.getenv("APP_SECRET", "change_me")
    data_dir: Path = Path(os.getenv("DATA_DIR", "./data")).resolve()

    openai_api_key: str | None = os.getenv("OPENAI_API_KEY") or None
    openai_model: str = os.getenv("OPENAI_MODEL", "gpt-4.1-mini")

    deepgram_api_key: str | None = os.getenv("DEEPGRAM_API_KEY") or None
    deepgram_model: str = os.getenv("DEEPGRAM_MODEL", "nova-2")
    deepgram_language: str = os.getenv("DEEPGRAM_LANGUAGE", "en-US")
    deepgram_diarize: bool = (os.getenv("DEEPGRAM_DIARIZE", "true").lower() == "true")


settings = Settings()
settings.data_dir.mkdir(parents=True, exist_ok=True)

