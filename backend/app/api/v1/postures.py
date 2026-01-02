"""
姿态数据 API
"""
from datetime import date, timedelta
from fastapi import APIRouter, Query

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import DbSession, CurrentUser
from app.schemas.common import ResponseModel
from app.schemas.posture import PostureLogCreate, PostureLogResponse, PostureStats, WeeklyStats
from app.models.posture_log import PostureLog

router = APIRouter(prefix="/postures", tags=["姿态数据"])


@router.post("/logs", response_model=ResponseModel, summary="上传姿态日志")
async def upload_logs(
    logs: list[PostureLogCreate],
    current_user: CurrentUser,
    db: DbSession,
):
    """
    批量上传姿态日志
    """
    for log_data in logs:
        log = PostureLog(
            device_id=log_data.device_id,
            user_id=current_user.id,
            posture_type=log_data.posture_type,
            duration=log_data.duration,
            is_correct=log_data.is_correct,
            recorded_at=log_data.recorded_at,
        )
        db.add(log)
    
    await db.flush()
    
    return ResponseModel(message=f"成功上传 {len(logs)} 条日志")


@router.get("/stats", response_model=ResponseModel[PostureStats], summary="获取统计数据")
async def get_stats(
    current_user: CurrentUser,
    db: DbSession,
    target_date: date = Query(None, description="统计日期，默认今天"),
):
    """
    获取指定日期的姿态统计
    """
    if target_date is None:
        target_date = date.today()
    
    # 查询当天数据
    result = await db.execute(
        select(PostureLog)
        .where(PostureLog.user_id == current_user.id)
        .where(func.date(PostureLog.recorded_at) == target_date)
    )
    logs = result.scalars().all()
    
    # 计算统计
    total_duration = sum(log.duration for log in logs)
    correct_duration = sum(log.duration for log in logs if log.is_correct)
    incorrect_duration = total_duration - correct_duration
    correct_rate = correct_duration / total_duration if total_duration > 0 else 0
    
    # 按姿态类型分组
    posture_breakdown = {}
    for log in logs:
        posture_breakdown[log.posture_type] = posture_breakdown.get(log.posture_type, 0) + log.duration
    
    return ResponseModel(data=PostureStats(
        date=target_date,
        total_duration=total_duration,
        correct_duration=correct_duration,
        incorrect_duration=incorrect_duration,
        correct_rate=round(correct_rate, 4),
        posture_breakdown=posture_breakdown,
    ))


@router.get("/weekly", response_model=ResponseModel[WeeklyStats], summary="获取周统计")
async def get_weekly_stats(
    current_user: CurrentUser,
    db: DbSession,
    start_date: date = Query(None, description="周开始日期，默认本周一"),
):
    """
    获取一周的姿态统计
    """
    if start_date is None:
        today = date.today()
        start_date = today - timedelta(days=today.weekday())
    
    end_date = start_date + timedelta(days=6)
    
    # 查询一周数据
    result = await db.execute(
        select(PostureLog)
        .where(PostureLog.user_id == current_user.id)
        .where(func.date(PostureLog.recorded_at) >= start_date)
        .where(func.date(PostureLog.recorded_at) <= end_date)
    )
    logs = result.scalars().all()
    
    # 按日期分组
    daily_data: dict[date, list[PostureLog]] = {}
    for log in logs:
        log_date = log.recorded_at.date()
        if log_date not in daily_data:
            daily_data[log_date] = []
        daily_data[log_date].append(log)
    
    # 构建每日统计
    daily_stats = []
    total_correct = 0
    total_incorrect = 0
    
    for i in range(7):
        current_date = start_date + timedelta(days=i)
        day_logs = daily_data.get(current_date, [])
        
        day_total = sum(log.duration for log in day_logs)
        day_correct = sum(log.duration for log in day_logs if log.is_correct)
        day_incorrect = day_total - day_correct
        day_rate = day_correct / day_total if day_total > 0 else 0
        
        posture_breakdown = {}
        for log in day_logs:
            posture_breakdown[log.posture_type] = posture_breakdown.get(log.posture_type, 0) + log.duration
        
        daily_stats.append(PostureStats(
            date=current_date,
            total_duration=day_total,
            correct_duration=day_correct,
            incorrect_duration=day_incorrect,
            correct_rate=round(day_rate, 4),
            posture_breakdown=posture_breakdown,
        ))
        
        total_correct += day_correct
        total_incorrect += day_incorrect
    
    total_all = total_correct + total_incorrect
    avg_rate = total_correct / total_all if total_all > 0 else 0
    
    return ResponseModel(data=WeeklyStats(
        start_date=start_date,
        end_date=end_date,
        daily_stats=daily_stats,
        total_correct_duration=total_correct,
        total_incorrect_duration=total_incorrect,
        average_correct_rate=round(avg_rate, 4),
    ))
