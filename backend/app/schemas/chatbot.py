from typing import Literal
from pydantic import BaseModel, Field


class ChatTurn(BaseModel):
    role: Literal['user', 'assistant']
    content: str = Field(max_length=4000)


class ChatContext(BaseModel):
    fitness_goal: str | None = None
    remaining_budget_php: float | None = None
    remaining_calories: int | None = None
    remaining_protein_g: float | None = None
    allergies: list[str] = []
    dietary_restrictions: list[str] = []


class ChatRequest(BaseModel):
    chat_session_id: str
    client_message_id: str
    message: str
    context: ChatContext | None = None
    history: list[ChatTurn] = Field(default_factory=list, max_length=12)


class ChatResponse(BaseModel):
    assistant_message_id: str
    reply: str
    safety_status: str
