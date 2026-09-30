from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes import interview, profiles, setup


def create_app() -> FastAPI:
    app = FastAPI(title="AI Interview Copilot (MVP)", version="0.1.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(profiles.router)
    app.include_router(setup.router)
    app.include_router(interview.router)

    return app


app = create_app()

