"""
认证相关模型
"""
from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    """登录请求"""
    phone: str = Field(..., min_length=11, max_length=11, description="手机号")
    password: str = Field(..., min_length=6, description="密码")


class RegisterRequest(BaseModel):
    """注册请求"""
    phone: str = Field(..., min_length=11, max_length=11, description="手机号")
    password: str = Field(..., min_length=6, description="密码")
    nickname: str = Field("用户", max_length=50, description="昵称")


class TokenResponse(BaseModel):
    """Token 响应"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # 秒


class RefreshTokenRequest(BaseModel):
    """刷新 Token 请求"""
    refresh_token: str
