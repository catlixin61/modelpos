"""
设备相关模型
"""
from __future__ import annotations
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field

from app.models.device import DeviceType


class DeviceBase(BaseModel):
    """设备基础模型"""
    mac_address: str = Field(..., min_length=17, max_length=17, description="MAC地址")
    device_type: DeviceType
    name: str = Field("", max_length=50)


class DeviceCreate(DeviceBase):
    """设备创建"""
    firmware_version: str = "1.0.0"


class DeviceUpdate(BaseModel):
    """设备更新"""
    name: Optional[str] = None
    firmware_version: Optional[str] = None
    user_id: Optional[int] = None
    paired_device_id: Optional[int] = None


class DeviceResponse(BaseModel):
    """设备响应"""
    id: int
    mac_address: str
    device_type: DeviceType
    name: str
    firmware_version: str
    user_id: Optional[int] = None
    paired_device_id: Optional[int] = None
    is_online: bool
    last_seen_at: Optional[datetime] = None
    created_at: datetime
    
    # 关联信息
    user_phone: Optional[str] = None
    paired_device_mac: Optional[str] = None
    
    class Config:
        from_attributes = True
