from __future__ import annotations

from pathlib import Path

from docx import Document
from pypdf import PdfReader


def extract_text_from_file(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".pdf":
        reader = PdfReader(str(path))
        parts: list[str] = []
        for page in reader.pages:
            parts.append(page.extract_text() or "")
        return "\n".join(parts).strip()

    if suffix == ".docx":
        doc = Document(str(path))
        return "\n".join(p.text for p in doc.paragraphs).strip()

    # Fallback to plain text
    return path.read_text(encoding="utf-8", errors="ignore").strip()

