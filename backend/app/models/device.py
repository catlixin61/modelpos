"""
设备模型
"""
from __future__ import annotations
from datetime import datetime
from enum import Enum
from typing import Optional
from sqlalchemy import String, Boolean, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class DeviceType(str, Enum):
    """设备类型"""
    DETECTOR = "detector"      # 探测器 (ESP32-S3)
    FEEDBACKER = "feedbacker"  # 反馈器 (ESP32-C3)


class Device(Base, TimestampMixin):
    """设备表"""
    __tablename__ = "devices"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    mac_address: Mapped[str] = mapped_column(String(17), unique=True, index=True, comment="MAC地址")
    device_type: Mapped[DeviceType] = mapped_column(comment="设备类型")
    name: Mapped[str] = mapped_column(String(50), default="", comment="设备名称")
    firmware_version: Mapped[str] = mapped_column(String(20), default="1.0.0", comment="固件版本")
    
    # 绑定用户
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True, comment="绑定用户ID")
    user = relationship("User", back_populates="devices")
    
    # 配对设备 (探测器 <-> 反馈器)
    paired_device_id: Mapped[Optional[int]] = mapped_column(ForeignKey("devices.id"), nullable=True, comment="配对设备ID")
    
    # 状态
    is_online: Mapped[bool] = mapped_column(Boolean, default=False, comment="在线状态")
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(nullable=True, comment="最后在线时间")
    
    # 姿态日志关联
    posture_logs = relationship("PostureLog", back_populates="device", lazy="selectin")
    
    def __repr__(self) -> str:
        return f"<Device(id={self.id}, mac={self.mac_address}, type={self.device_type})>"
