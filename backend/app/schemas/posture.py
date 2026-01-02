"""
姿态数据相关模型
"""
from datetime import datetime, date
from pydantic import BaseModel, Field


class PostureLogBase(BaseModel):
    """姿态日志基础模型"""
    posture_type: str = Field(..., max_length=50)
    duration: int = Field(..., ge=0, description="持续时长(秒)")
    is_correct: bool = True
    recorded_at: datetime


class PostureLogCreate(PostureLogBase):
    """姿态日志创建 (批量上传)"""
    device_id: int


class PostureLogResponse(PostureLogBase):
    """姿态日志响应"""
    id: int
    device_id: int
    user_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class PostureStats(BaseModel):
    """姿态统计"""
    date: date
    total_duration: int  # 总时长(秒)
    correct_duration: int  # 正确姿态时长
    incorrect_duration: int  # 不良姿态时长
    correct_rate: float  # 正确率 (0-1)
    posture_breakdown: dict[str, int]  # 各姿态时长


class WeeklyStats(BaseModel):
    """周统计"""
    start_date: date
    end_date: date
    daily_stats: list[PostureStats]
    total_correct_duration: int
    total_incorrect_duration: int
    average_correct_rate: float
