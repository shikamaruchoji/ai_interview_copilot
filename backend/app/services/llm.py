from __future__ import annotations

from dataclasses import dataclass

from openai import OpenAI


SYSTEM_PROMPT = """You are an AI Interview Copilot.
You assist a candidate during a real interview.

Rules:
- Use ONLY facts that appear in the provided resume context.
- Align wording with the provided job description keywords.
- Do NOT invent employers, titles, dates, or metrics. If missing, keep it generic.
- Output must be readable in under 3 seconds.
- Output format must be either:
  (A) 3 bullet points, OR
  (B) one short paragraph (max 4 lines).
No preamble, no headings.
"""


@dataclass
class LLM:
    client: OpenAI
    model: str

    @classmethod
    def from_api_key(cls, api_key: str, model: str) -> "LLM":
        return cls(client=OpenAI(api_key=api_key), model=model)

    def generate(self, question: str, retrieved: list[str], short_memory: list[str]) -> str:
        context = "\n\n".join(retrieved[:6])
        memory = "\n".join(short_memory[-3:])
        user = f"""INTERVIEWER_QUESTION:
{question}

SHORT_MEMORY_LAST_EXCHANGES:
{memory}

RETRIEVED_CONTEXT:
{context}
"""
        resp = self.client.responses.create(
            model=self.model,
            input=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user},
            ],
            temperature=0.3,
            max_output_tokens=180,
        )
        return (resp.output_text or "").strip()


def fallback_answer(question: str, retrieved: list[str]) -> str:
    # Deterministic, non-hallucinating fallback when no LLM key is configured.
    # Uses only retrieved text snippets as a basis.
    basis = ""
    if retrieved:
        basis = retrieved[0][:220].strip()
    if basis:
        return f"• I’ve worked on similar areas ({basis}…). \n• I’d focus on the key requirements and clarify constraints. \n• I’d deliver an incremental solution and validate impact with measurable outcomes."
    return "• I’d clarify the goal and constraints. \n• I’d outline a concrete approach and trade-offs. \n• I’d execute iteratively, validating results with measurable outcomes."

