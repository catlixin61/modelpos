"""
设备服务
"""
from __future__ import annotations
from datetime import datetime
from typing import Optional, Tuple, List

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device import Device, DeviceType
from app.schemas.device import DeviceCreate, DeviceUpdate


class DeviceService:
    """设备服务"""
    
    @staticmethod
    async def create_device(db: AsyncSession, data: DeviceCreate) -> Device:
        """创建设备"""
        device = Device(
            mac_address=data.mac_address,
            device_type=data.device_type,
            name=data.name,
            firmware_version=data.firmware_version,
        )
        db.add(device)
        await db.flush()
        await db.refresh(device)
        return device
    
    @staticmethod
    async def get_device_by_mac(db: AsyncSession, mac_address: str) -> Optional[Device]:
        """根据 MAC 地址获取设备"""
        result = await db.execute(
            select(Device).where(Device.mac_address == mac_address)
        )
        return result.scalar_one_or_none()
    
    @staticmethod
    async def get_device_by_id(db: AsyncSession, device_id: int) -> Optional[Device]:
        """根据 ID 获取设备"""
        result = await db.execute(
            select(Device).where(Device.id == device_id)
        )
        return result.scalar_one_or_none()
    
    @staticmethod
    async def list_devices(
        db: AsyncSession,
        page: int = 1,
        page_size: int = 20,
        device_type: Optional[DeviceType] = None,
        user_id: Optional[int] = None,
        search: Optional[str] = None
    ) -> Tuple[List[Device], int]:
        """获取设备列表 (分页)"""
        query = select(Device)
        
        if device_type:
            query = query.where(Device.device_type == device_type)
        if user_id:
            query = query.where(Device.user_id == user_id)
        if search:
            query = query.where(
                Device.mac_address.contains(search) | Device.name.contains(search)
            )
        
        # 统计总数
        count_query = select(func.count()).select_from(query.subquery())
        total = (await db.execute(count_query)).scalar() or 0
        
        # 分页查询
        query = query.offset((page - 1) * page_size).limit(page_size)
        query = query.order_by(Device.created_at.desc())
        
        result = await db.execute(query)
        devices = list(result.scalars().all())
        
        return devices, total
    
    @staticmethod
    async def update_device(db: AsyncSession, device: Device, data: DeviceUpdate) -> Device:
        """更新设备"""
        update_data = data.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(device, key, value)
        
        await db.flush()
        await db.refresh(device)
        return device
    
    @staticmethod
    async def delete_device(db: AsyncSession, device: Device) -> None:
        """删除设备"""
        await db.delete(device)
    
    @staticmethod
    async def update_online_status(
        db: AsyncSession, 
        device: Device, 
        is_online: bool
    ) -> Device:
        """更新设备在线状态"""
        device.is_online = is_online
        if is_online:
            device.last_seen_at = datetime.utcnow()
        await db.flush()
        return device
    
    @staticmethod
    async def pair_devices(
        db: AsyncSession,
        detector: Device,
        feedbacker: Device
    ) -> Tuple[Device, Device]:
        """配对设备 (探测器 <-> 反馈器)"""
        if detector.device_type != DeviceType.DETECTOR:
            raise ValueError("第一个设备必须是探测器")
        if feedbacker.device_type != DeviceType.FEEDBACKER:
            raise ValueError("第二个设备必须是反馈器")
        
        detector.paired_device_id = feedbacker.id
        feedbacker.paired_device_id = detector.id
        
        await db.flush()
        await db.refresh(detector)
        await db.refresh(feedbacker)
        
        return detector, feedbacker
    
    @staticmethod
    async def get_devices_by_user(db: AsyncSession, user_id: int) -> List[Device]:
        """获取用户绑定的所有设备"""
        result = await db.execute(
            select(Device)
            .where(Device.user_id == user_id)
            .order_by(Device.created_at.desc())
        )
        return list(result.scalars().all())

