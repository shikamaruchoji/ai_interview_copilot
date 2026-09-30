from __future__ import annotations

import asyncio
import json
import time
from dataclasses import dataclass

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.config import settings
from app.db.store import Store
from app.services.llm import LLM, fallback_answer
from app.services.question_detect import QuestionDetector
from app.services.rag import RAGIndex


router = APIRouter(prefix="/interview", tags=["interview"])
store = Store(settings.data_dir / "app.sqlite3")
store.init()


@dataclass
class SessionState:
    profile_id: str
    rag: RAGIndex
    question_detector: QuestionDetector
    short_memory: list[str]
    current_interviewer_text: str
    last_answer: str


async def _send_json(ws: WebSocket, payload: dict) -> None:
    await ws.send_text(json.dumps(payload, ensure_ascii=False))


@router.websocket("/ws")
async def interview_ws(ws: WebSocket) -> None:
    await ws.accept()

    # Protocol (client -> server):
    # - {"type":"hello","profile_id":"...","audio_format":"pcm16","sample_rate":16000}
    # - {"type":"audio","seq":1,"pcm16_b64":"..."}  # optional in this MVP
    # - {"type":"text","speaker":"interviewer","text":"..."} # test mode / provider mode
    #
    # Protocol (server -> client):
    # - {"type":"status","listening":true,"latency_ms":123}
    # - {"type":"interviewer_text","text":"..."}
    # - {"type":"suggested_answer","text":"..."}

    state: SessionState | None = None
    llm: LLM | None = None
    if settings.openai_api_key:
        llm = LLM.from_api_key(settings.openai_api_key, settings.openai_model)

    async def question_loop() -> None:
        nonlocal state
        while True:
            await asyncio.sleep(0.12)
            if not state:
                continue
            q = state.question_detector.maybe_finalize_question()
            if not q:
                continue

            t0 = time.time()
            retrieved = state.rag.retrieve(q, k=6)
            if llm:
                ans = llm.generate(question=q, retrieved=retrieved, short_memory=state.short_memory)
            else:
                ans = fallback_answer(question=q, retrieved=retrieved)

            state.last_answer = ans
            state.short_memory.append(f"Q: {q}")
            state.short_memory.append(f"A: {ans}")
            state.short_memory = state.short_memory[-6:]

            await _send_json(
                ws,
                {
                    "type": "suggested_answer",
                    "text": ans,
                    "latency_ms": int((time.time() - t0) * 1000),
                },
            )

    loop_task = asyncio.create_task(question_loop())

    try:
        while True:
            raw = await ws.receive_text()
            msg = json.loads(raw)
            mtype = msg.get("type")

            if mtype == "hello":
                profile_id = str(msg.get("profile_id") or "").strip()
                data = store.get_profile_data(profile_id) or {}
                state = SessionState(
                    profile_id=profile_id,
                    rag=RAGIndex.from_texts(data.get("resume_text"), data.get("job_text")),
                    question_detector=QuestionDetector(),
                    short_memory=[],
                    current_interviewer_text="",
                    last_answer="",
                )
                await _send_json(ws, {"type": "status", "listening": True})
                continue

            if not state:
                await _send_json(ws, {"type": "error", "message": "Send hello first."})
                continue

            if mtype == "text":
                speaker = (msg.get("speaker") or "interviewer").lower()
                text = str(msg.get("text") or "").strip()
                if not text:
                    continue

                # MVP: assume client/provider only forwards interviewer text.
                if speaker == "interviewer":
                    state.current_interviewer_text = text
                    state.question_detector.update_transcript(text)
                    await _send_json(ws, {"type": "interviewer_text", "text": text})
                continue

            # Audio streaming is provider-specific and not fully implemented here.
            if mtype == "audio":
                await _send_json(ws, {"type": "status", "listening": True})
                continue

            await _send_json(ws, {"type": "error", "message": f"Unknown type: {mtype}"})

    except WebSocketDisconnect:
        pass
    finally:
        loop_task.cancel()

