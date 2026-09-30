from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCHEMA = """
CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY,
  pin_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS profile_data (
  profile_id TEXT PRIMARY KEY,
  resume_text TEXT,
  job_text TEXT,
  voiceprint_b64 TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(profile_id) REFERENCES profiles(id)
);
"""


@dataclass
class Store:
    db_path: Path

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        return conn

    def init(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as conn:
            conn.executescript(SCHEMA)

    def get_profile(self, profile_id: str) -> dict[str, Any] | None:
        with self._connect() as conn:
            row = conn.execute("SELECT * FROM profiles WHERE id = ?", (profile_id,)).fetchone()
            return dict(row) if row else None

    def upsert_profile(self, profile_id: str, pin_hash: str, created_at: str) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO profiles(id, pin_hash, created_at)
                VALUES(?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET pin_hash=excluded.pin_hash
                """,
                (profile_id, pin_hash, created_at),
            )

    def upsert_profile_data(
        self,
        profile_id: str,
        updated_at: str,
        resume_text: str | None = None,
        job_text: str | None = None,
        voiceprint_b64: str | None = None,
    ) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO profile_data(profile_id, resume_text, job_text, voiceprint_b64, updated_at)
                VALUES(?, ?, ?, ?, ?)
                ON CONFLICT(profile_id) DO UPDATE SET
                  resume_text=COALESCE(excluded.resume_text, profile_data.resume_text),
                  job_text=COALESCE(excluded.job_text, profile_data.job_text),
                  voiceprint_b64=COALESCE(excluded.voiceprint_b64, profile_data.voiceprint_b64),
                  updated_at=excluded.updated_at
                """,
                (profile_id, resume_text, job_text, voiceprint_b64, updated_at),
            )

    def get_profile_data(self, profile_id: str) -> dict[str, Any] | None:
        with self._connect() as conn:
            row = conn.execute("SELECT * FROM profile_data WHERE profile_id = ?", (profile_id,)).fetchone()
            return dict(row) if row else None

