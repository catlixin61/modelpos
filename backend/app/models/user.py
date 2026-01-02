"""
用户模型
"""
from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Boolean, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class User(Base, TimestampMixin):
    """用户表"""
    __tablename__ = "users"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True, comment="手机号")
    password_hash: Mapped[str] = mapped_column(String(128), comment="密码哈希")
    nickname: Mapped[str] = mapped_column(String(50), default="用户", comment="昵称")
    avatar_url: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, comment="头像URL")
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, comment="是否管理员")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, comment="是否启用")
    last_login_at: Mapped[Optional[datetime]] = mapped_column(nullable=True, comment="最后登录时间")
    
    # 关联
    devices = relationship("Device", back_populates="user", lazy="selectin")
    posture_logs = relationship("PostureLog", back_populates="user", lazy="selectin")
    
    def __repr__(self) -> str:
        return f"<User(id={self.id}, phone={self.phone}, is_admin={self.is_admin})>"
