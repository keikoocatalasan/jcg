from typing import Literal
from pydantic import BaseModel, Field, field_validator


class ChatTurn(BaseModel):
    role: Literal['user', 'assistant']
    content: str = Field(min_length=1, max_length=4000)


class ChatFoodRecord(BaseModel):
    food_name: str
    serving_label: str
    serving_grams: float
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    estimated_price_php: float | None = None


class ChatContext(BaseModel):
    fitness_goal: str | None = None
    calorie_target: int | None = None
    protein_target_g: float | None = None
    carbs_target_g: float | None = None
    fat_target_g: float | None = None
    calories_consumed_today: float | None = None
    protein_consumed_today_g: float | None = None
    carbs_consumed_today_g: float | None = None
    fat_consumed_today_g: float | None = None
    remaining_budget_php: float | None = None
    remaining_calories: int | None = None
    remaining_protein_g: float | None = None
    remaining_carbs_g: float | None = None
    remaining_fat_g: float | None = None
    allergies: list[str] = Field(default_factory=list)
    dietary_restrictions: list[str] = Field(default_factory=list)
    food_records: list[ChatFoodRecord] = Field(default_factory=list)


class ChatRequest(BaseModel):
    chat_session_id: str = Field(min_length=1, max_length=100)
    client_message_id: str = Field(min_length=1, max_length=100)
    message: str = Field(min_length=1, max_length=4000)
    context: ChatContext | None = None
    history: list[ChatTurn] = Field(default_factory=list, max_length=12)

    @field_validator("message")
    @classmethod
    def message_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Message must not be blank")
        return value


class ChatResponse(BaseModel):
    assistant_message_id: str
    reply: str
    safety_status: str
