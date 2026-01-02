"""
设备管理 API
"""
from __future__ import annotations
from typing import Optional
from fastapi import APIRouter, HTTPException, status, Query

from app.api.deps import DbSession, AdminUser, CurrentUser
from app.schemas.common import ResponseModel, PaginatedResponse
from app.schemas.device import DeviceResponse, DeviceCreate, DeviceUpdate
from app.models.device import DeviceType
from app.services.device_service import DeviceService
from app.services.user_service import UserService

router = APIRouter(prefix="/devices", tags=["设备管理"])


def _build_device_response(device, user_phone: Optional[str] = None, paired_mac: Optional[str] = None) -> DeviceResponse:
    """构建设备响应"""
    return DeviceResponse(
        id=device.id,
        mac_address=device.mac_address,
        device_type=device.device_type,
        name=device.name,
        firmware_version=device.firmware_version,
        user_id=device.user_id,
        paired_device_id=device.paired_device_id,
        is_online=device.is_online,
        last_seen_at=device.last_seen_at,
        created_at=device.created_at,
        user_phone=user_phone,
        paired_device_mac=paired_mac,
    )


@router.get("/", response_model=ResponseModel[PaginatedResponse[DeviceResponse]], summary="设备列表")
async def list_devices(
    admin: AdminUser,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    device_type: Optional[DeviceType] = Query(None),
    user_id: Optional[int] = Query(None),
    search: Optional[str] = Query(None, description="搜索MAC地址或名称"),
):
    """
    获取设备列表 (管理员)
    """
    devices, total = await DeviceService.list_devices(
        db, page, page_size, device_type, user_id, search
    )
    
    items = []
    for device in devices:
        user_phone = None
        if device.user_id:
            user = await UserService.get_user_by_id(db, device.user_id)
            user_phone = user.phone if user else None
        
        paired_mac = None
        if device.paired_device_id:
            paired = await DeviceService.get_device_by_id(db, device.paired_device_id)
            paired_mac = paired.mac_address if paired else None
        
        items.append(_build_device_response(device, user_phone, paired_mac))
    
    return ResponseModel(data=PaginatedResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=(total + page_size - 1) // page_size,
    ))


@router.post("/", response_model=ResponseModel[DeviceResponse], summary="注册设备")
async def create_device(data: DeviceCreate, db: DbSession):
    """
    注册新设备
    """
    # 检查 MAC 地址是否已注册
    existing = await DeviceService.get_device_by_mac(db, data.mac_address)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="MAC地址已注册",
        )
    
    device = await DeviceService.create_device(db, data)
    
    return ResponseModel(data=_build_device_response(device))


@router.get("/{device_id}", response_model=ResponseModel[DeviceResponse], summary="设备详情")
async def get_device(device_id: int, admin: AdminUser, db: DbSession):
    """
    获取设备详情 (管理员)
    """
    device = await DeviceService.get_device_by_id(db, device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="设备不存在",
        )
    
    user_phone = None
    if device.user_id:
        user = await UserService.get_user_by_id(db, device.user_id)
        user_phone = user.phone if user else None
    
    paired_mac = None
    if device.paired_device_id:
        paired = await DeviceService.get_device_by_id(db, device.paired_device_id)
        paired_mac = paired.mac_address if paired else None
    
    return ResponseModel(data=_build_device_response(device, user_phone, paired_mac))


@router.put("/{device_id}", response_model=ResponseModel[DeviceResponse], summary="更新设备")
async def update_device(device_id: int, data: DeviceUpdate, admin: AdminUser, db: DbSession):
    """
    更新设备信息 (管理员)
    """
    device = await DeviceService.get_device_by_id(db, device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="设备不存在",
        )
    
    device = await DeviceService.update_device(db, device, data)
    
    return ResponseModel(data=_build_device_response(device))


@router.delete("/{device_id}", response_model=ResponseModel, summary="删除设备")
async def delete_device(device_id: int, admin: AdminUser, db: DbSession):
    """
    删除设备 (管理员)
    """
    device = await DeviceService.get_device_by_id(db, device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="设备不存在",
        )
    
    await DeviceService.delete_device(db, device)
    
    return ResponseModel(message="设备已删除")


@router.post("/{device_id}/pair", response_model=ResponseModel[DeviceResponse], summary="配对设备")
async def pair_device(
    device_id: int, 
    paired_device_id: int = Query(..., description="配对设备ID"),
    admin: AdminUser = None,
    db: DbSession = None,
):
    """
    配对探测器与反馈器 (管理员)
    """
    detector = await DeviceService.get_device_by_id(db, device_id)
    if not detector:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="探测器不存在",
        )
    
    feedbacker = await DeviceService.get_device_by_id(db, paired_device_id)
    if not feedbacker:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="反馈器不存在",
        )
    
    try:
        detector, feedbacker = await DeviceService.pair_devices(db, detector, feedbacker)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    
    return ResponseModel(
        message="配对成功",
        data=_build_device_response(detector, paired_mac=feedbacker.mac_address),
    )


@router.post("/{device_id}/online", response_model=ResponseModel[DeviceResponse], summary="更新在线状态")
async def update_online_status(
    device_id: int,
    is_online: bool = Query(...),
    db: DbSession = None,
):
    """
    更新设备在线状态 (设备端调用)
    """
    device = await DeviceService.get_device_by_id(db, device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="设备不存在",
        )
    
    device = await DeviceService.update_online_status(db, device, is_online)
    
    return ResponseModel(data=_build_device_response(device))
