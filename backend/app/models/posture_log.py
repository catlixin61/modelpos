"""
姿态日志模型
"""
from datetime import datetime
from sqlalchemy import String, Integer, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class PostureLog(Base):
    """姿态日志表"""
    __tablename__ = "posture_logs"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    
    # 关联
    device_id: Mapped[int] = mapped_column(ForeignKey("devices.id"), index=True, comment="设备ID")
    device = relationship("Device", back_populates="posture_logs")
    
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, comment="用户ID")
    user = relationship("User", back_populates="posture_logs")
    
    # 姿态数据
    posture_type: Mapped[str] = mapped_column(String(50), comment="姿态类型")
    duration: Mapped[int] = mapped_column(Integer, comment="持续时长(秒)")
    is_correct: Mapped[bool] = mapped_column(default=True, comment="是否正确姿态")
    
    # 记录时间
    recorded_at: Mapped[datetime] = mapped_column(index=True, comment="记录时间")
    created_at: Mapped[datetime] = mapped_column(default=func.now(), comment="入库时间")
    
    def __repr__(self) -> str:
        return f"<PostureLog(id={self.id}, type={self.posture_type}, duration={self.duration}s)>"
