"""
用户服务
"""
from __future__ import annotations
from datetime import datetime
from typing import Optional, Tuple, List

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.user import User
from app.models.device import Device
from app.schemas.user import UserCreate, UserUpdate
from app.services.auth import AuthService


class UserService:
    """用户服务"""
    
    @staticmethod
    async def create_user(db: AsyncSession, data: UserCreate) -> User:
        """创建用户"""
        user = User(
            phone=data.phone,
            password_hash=AuthService.hash_password(data.password),
            nickname=data.nickname,
            is_admin=data.is_admin,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)
        return user
    
    @staticmethod
    async def get_user_by_phone(db: AsyncSession, phone: str) -> Optional[User]:
        """根据手机号获取用户"""
        result = await db.execute(
            select(User).where(User.phone == phone)
        )
        return result.scalar_one_or_none()
    
    @staticmethod
    async def get_user_by_id(db: AsyncSession, user_id: int) -> Optional[User]:
        """根据 ID 获取用户"""
        result = await db.execute(
            select(User).where(User.id == user_id).options(selectinload(User.devices))
        )
        return result.scalar_one_or_none()
    
    @staticmethod
    async def list_users(
        db: AsyncSession, 
        page: int = 1, 
        page_size: int = 20,
        search: Optional[str] = None
    ) -> Tuple[List[User], int]:
        """获取用户列表 (分页)"""
        query = select(User)
        
        if search:
            query = query.where(
                User.phone.contains(search) | User.nickname.contains(search)
            )
        
        # 统计总数
        count_query = select(func.count()).select_from(query.subquery())
        total = (await db.execute(count_query)).scalar() or 0
        
        # 分页查询
        query = query.offset((page - 1) * page_size).limit(page_size)
        query = query.order_by(User.created_at.desc())
        
        result = await db.execute(query)
        users = list(result.scalars().all())
        
        return users, total
    
    @staticmethod
    async def update_user(db: AsyncSession, user: User, data: UserUpdate) -> User:
        """更新用户"""
        update_data = data.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(user, key, value)
        
        await db.flush()
        await db.refresh(user)
        return user
    
    @staticmethod
    async def delete_user(db: AsyncSession, user: User) -> None:
        """删除用户"""
        await db.delete(user)
    
    @staticmethod
    async def update_last_login(db: AsyncSession, user: User) -> None:
        """更新最后登录时间"""
        user.last_login_at = datetime.utcnow()
        await db.flush()
    
    @staticmethod
    async def get_user_device_count(db: AsyncSession, user_id: int) -> int:
        """获取用户设备数量"""
        result = await db.execute(
            select(func.count()).where(Device.user_id == user_id)
        )
        return result.scalar() or 0
