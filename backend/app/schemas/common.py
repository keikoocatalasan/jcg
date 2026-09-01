from pydantic import BaseModel, Field


class SuccessResponse(BaseModel):
    success: bool = True
    data: dict = Field(default_factory=dict)
    message: str = "OK"


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: dict = Field(default_factory=dict)


class ErrorResponse(BaseModel):
    success: bool = False
    error: ErrorDetail
