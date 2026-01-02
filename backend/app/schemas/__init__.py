"""
Pydantic Schemas
"""
from app.schemas.common import ResponseModel
from app.schemas.auth import TokenResponse, LoginRequest, RegisterRequest
from app.schemas.user import UserResponse, UserCreate, UserUpdate
from app.schemas.device import DeviceResponse, DeviceCreate, DeviceUpdate
from app.schemas.posture import PostureLogResponse, PostureLogCreate, PostureStats

__all__ = [
    "ResponseModel",
    "TokenResponse", "LoginRequest", "RegisterRequest",
    "UserResponse", "UserCreate", "UserUpdate",
    "DeviceResponse", "DeviceCreate", "DeviceUpdate",
    "PostureLogResponse", "PostureLogCreate", "PostureStats",
]
