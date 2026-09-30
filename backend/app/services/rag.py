from __future__ import annotations

import re
from dataclasses import dataclass

from rank_bm25 import BM25Okapi


def _chunk_text(text: str, max_chars: int = 800) -> list[str]:
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return []
    chunks: list[str] = []
    i = 0
    while i < len(text):
        chunks.append(text[i : i + max_chars].strip())
        i += max_chars
    return [c for c in chunks if c]


def _tokenize(text: str) -> list[str]:
    return re.findall(r"[a-zA-Z0-9_+#.-]{2,}", text.lower())


@dataclass
class RAGIndex:
    chunks: list[str]
    bm25: BM25Okapi

    @classmethod
    def from_texts(cls, resume_text: str | None, job_text: str | None) -> "RAGIndex":
        chunks = []
        if resume_text:
            chunks += [f"[RESUME] {c}" for c in _chunk_text(resume_text)]
        if job_text:
            chunks += [f"[JOB] {c}" for c in _chunk_text(job_text)]
        tokenized = [_tokenize(c) for c in chunks]
        bm25 = BM25Okapi(tokenized or [["empty"]])
        return cls(chunks=chunks, bm25=bm25)

    def retrieve(self, query: str, k: int = 5) -> list[str]:
        if not self.chunks:
            return []
        scores = self.bm25.get_scores(_tokenize(query))
        ranked = sorted(range(len(self.chunks)), key=lambda i: float(scores[i]), reverse=True)[:k]
        return [self.chunks[i] for i in ranked]

