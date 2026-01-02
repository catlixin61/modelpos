"""
认证服务
"""
from __future__ import annotations
from datetime import datetime, timedelta
from typing import Optional, Tuple

import jwt
import bcrypt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.user import User

settings = get_settings()


class AuthService:
    """认证服务"""
    
    @staticmethod
    def hash_password(password: str) -> str:
        """密码加密"""
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
        return hashed.decode('utf-8')
    
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """验证密码"""
        try:
            return bcrypt.checkpw(
                plain_password.encode('utf-8'),
                hashed_password.encode('utf-8')
            )
        except Exception:
            return False
    
    @staticmethod
    def create_access_token(user_id: int, is_admin: bool = False) -> Tuple[str, int]:
        """
        创建访问令牌
        
        Returns:
            (token, expires_in_seconds)
        """
        expires_in = settings.jwt_access_token_expire_minutes * 60
        expire = datetime.utcnow() + timedelta(minutes=settings.jwt_access_token_expire_minutes)
        
        payload = {
            "sub": str(user_id),
            "is_admin": is_admin,
            "exp": expire,
            "type": "access",
        }
        
        token = jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
        return token, expires_in
    
    @staticmethod
    def create_refresh_token(user_id: int) -> str:
        """创建刷新令牌"""
        expire = datetime.utcnow() + timedelta(days=settings.jwt_refresh_token_expire_days)
        
        payload = {
            "sub": str(user_id),
            "exp": expire,
            "type": "refresh",
        }
        
        return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    
    @staticmethod
    def decode_token(token: str) -> Optional[dict]:
        """解码令牌"""
        try:
            payload = jwt.decode(
                token,
                settings.jwt_secret_key,
                algorithms=[settings.jwt_algorithm]
            )
            return payload
        except jwt.PyJWTError:
            return None
    
    @staticmethod
    async def authenticate_user(
        db: AsyncSession, 
        phone: str, 
        password: str
    ) -> Optional[User]:
        """验证用户"""
        result = await db.execute(
            select(User).where(User.phone == phone)
        )
        user = result.scalar_one_or_none()
        
        if not user:
            return None
        if not AuthService.verify_password(password, user.password_hash):
            return None
        if not user.is_active:
            return None
            
        return user
    
    @staticmethod
    async def get_user_by_id(db: AsyncSession, user_id: int) -> Optional[User]:
        """根据 ID 获取用户"""
        result = await db.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()
