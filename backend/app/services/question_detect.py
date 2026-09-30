from __future__ import annotations

import re
import time
from dataclasses import dataclass


QUESTION_RE = re.compile(r".*(\?|(^|\s)(what|why|how|when|where|tell me|walk me|could you|can you|describe)\b).*", re.I)


@dataclass
class QuestionDetector:
    min_pause_ms: int = 900

    last_text: str = ""
    last_update_ms: int = 0
    last_question_emitted: str = ""

    def update_transcript(self, text: str) -> None:
        now = int(time.time() * 1000)
        self.last_text = text.strip()
        self.last_update_ms = now

    def maybe_finalize_question(self) -> str | None:
        now = int(time.time() * 1000)
        if not self.last_text:
            return None
        if now - self.last_update_ms < self.min_pause_ms:
            return None

        candidate = self.last_text
        # Heuristic: only emit if it looks like a question.
        if not QUESTION_RE.match(candidate):
            return None
        if candidate == self.last_question_emitted:
            return None
        self.last_question_emitted = candidate
        return candidate

