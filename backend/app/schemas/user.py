"""
用户相关模型
"""
from __future__ import annotations
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class UserBase(BaseModel):
    """用户基础模型"""
    phone: str = Field(..., min_length=11, max_length=11)
    nickname: str = Field("用户", max_length=50)


class UserCreate(UserBase):
    """用户创建"""
    password: str = Field(..., min_length=6)
    is_admin: bool = False


class UserUpdate(BaseModel):
    """用户更新"""
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None
    is_active: Optional[bool] = None


class UserResponse(BaseModel):
    """用户响应"""
    id: int
    phone: str
    nickname: str
    avatar_url: Optional[str] = None
    is_admin: bool
    is_active: bool
    created_at: datetime
    last_login_at: Optional[datetime] = None
    device_count: int = 0
    
    class Config:
        from_attributes = True
