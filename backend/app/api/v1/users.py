"""
用户管理 API
"""
from __future__ import annotations
from typing import Optional
from fastapi import APIRouter, HTTPException, status, Query

from app.api.deps import DbSession, AdminUser, CurrentUser
from app.schemas.common import ResponseModel, PaginatedResponse
from app.schemas.user import UserResponse, UserUpdate
from app.schemas.device import DeviceResponse, DeviceCreate
from app.services.user_service import UserService
from app.services.device_service import DeviceService

router = APIRouter(prefix="/users", tags=["用户管理"])


@router.get("/me", response_model=ResponseModel[UserResponse], summary="获取当前用户信息")
async def get_me(current_user: CurrentUser, db: DbSession):
    """获取当前登录用户信息"""
    device_count = await UserService.get_user_device_count(db, current_user.id)
    
    return ResponseModel(data=UserResponse(
        id=current_user.id,
        phone=current_user.phone,
        nickname=current_user.nickname,
        avatar_url=current_user.avatar_url,
        is_admin=current_user.is_admin,
        is_active=current_user.is_active,
        created_at=current_user.created_at,
        last_login_at=current_user.last_login_at,
        device_count=device_count,
    ))


@router.put("/me", response_model=ResponseModel[UserResponse], summary="更新当前用户信息")
async def update_me(data: UserUpdate, current_user: CurrentUser, db: DbSession):
    """更新当前用户信息"""
    # 不允许修改 is_active
    data.is_active = None
    
    user = await UserService.update_user(db, current_user, data)
    device_count = await UserService.get_user_device_count(db, user.id)
    
    return ResponseModel(data=UserResponse(
        id=user.id,
        phone=user.phone,
        nickname=user.nickname,
        avatar_url=user.avatar_url,
        is_admin=user.is_admin,
        is_active=user.is_active,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
        device_count=device_count,
    ))


@router.get("/", response_model=ResponseModel[PaginatedResponse[UserResponse]], summary="用户列表")
async def list_users(
    admin: AdminUser,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None, description="搜索手机号或昵称"),
):
    """
    获取用户列表 (管理员)
    """
    users, total = await UserService.list_users(db, page, page_size, search)
    
    items = []
    for user in users:
        device_count = await UserService.get_user_device_count(db, user.id)
        items.append(UserResponse(
            id=user.id,
            phone=user.phone,
            nickname=user.nickname,
            avatar_url=user.avatar_url,
            is_admin=user.is_admin,
            is_active=user.is_active,
            created_at=user.created_at,
            last_login_at=user.last_login_at,
            device_count=device_count,
        ))
    
    return ResponseModel(data=PaginatedResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=(total + page_size - 1) // page_size,
    ))


@router.get("/{user_id}", response_model=ResponseModel[UserResponse], summary="用户详情")
async def get_user(user_id: int, admin: AdminUser, db: DbSession):
    """
    获取用户详情 (管理员)
    """
    user = await UserService.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在",
        )
    
    device_count = await UserService.get_user_device_count(db, user.id)
    
    return ResponseModel(data=UserResponse(
        id=user.id,
        phone=user.phone,
        nickname=user.nickname,
        avatar_url=user.avatar_url,
        is_admin=user.is_admin,
        is_active=user.is_active,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
        device_count=device_count,
    ))


@router.put("/{user_id}", response_model=ResponseModel[UserResponse], summary="更新用户")
async def update_user(user_id: int, data: UserUpdate, admin: AdminUser, db: DbSession):
    """
    更新用户信息 (管理员)
    """
    user = await UserService.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在",
        )
    
    user = await UserService.update_user(db, user, data)
    device_count = await UserService.get_user_device_count(db, user.id)
    
    return ResponseModel(data=UserResponse(
        id=user.id,
        phone=user.phone,
        nickname=user.nickname,
        avatar_url=user.avatar_url,
        is_admin=user.is_admin,
        is_active=user.is_active,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
        device_count=device_count,
    ))


@router.delete("/{user_id}", response_model=ResponseModel, summary="删除用户")
async def delete_user(user_id: int, admin: AdminUser, db: DbSession):
    """
    删除用户 (管理员)
    """
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="不能删除自己",
        )
    
    user = await UserService.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在",
        )
    
    await UserService.delete_user(db, user)
    
    return ResponseModel(message="用户已删除")


# ==================== 用户设备管理 API (供 iOS 客户端使用) ====================


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


@router.get("/me/devices", response_model=ResponseModel[list[DeviceResponse]], summary="获取我的设备列表")
async def get_my_devices(current_user: CurrentUser, db: DbSession):
    """
    获取当前用户绑定的设备列表
    """
    devices = await DeviceService.get_devices_by_user(db, current_user.id)
    
    items = []
    for device in devices:
        paired_mac = None
        if device.paired_device_id:
            paired = await DeviceService.get_device_by_id(db, device.paired_device_id)
            paired_mac = paired.mac_address if paired else None
        
        items.append(_build_device_response(device, current_user.phone, paired_mac))
    
    return ResponseModel(data=items)


@router.post("/me/devices", response_model=ResponseModel[DeviceResponse], summary="绑定设备")
async def bind_device(data: DeviceCreate, current_user: CurrentUser, db: DbSession):
    """
    绑定设备到当前用户
    
    - 如果设备 MAC 地址已存在但无所属用户，则绑定到当前用户
    - 如果设备 MAC 地址不存在，则创建新设备并绑定
    - 如果设备已被其他用户绑定，则返回错误
    """
    # 检查设备是否已存在
    existing = await DeviceService.get_device_by_mac(db, data.mac_address)
    
    if existing:
        if existing.user_id is not None and existing.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="该设备已被其他用户绑定",
            )
        
        if existing.user_id == current_user.id:
            # 已经绑定到当前用户
            return ResponseModel(data=_build_device_response(existing, current_user.phone))
        
        # 绑定到当前用户
        from app.schemas.device import DeviceUpdate
        existing = await DeviceService.update_device(db, existing, DeviceUpdate(
            user_id=current_user.id,
            name=data.name if data.name else existing.name,
        ))
        
        return ResponseModel(data=_build_device_response(existing, current_user.phone))
    
    # 创建新设备并绑定
    device = await DeviceService.create_device(db, data)
    
    # 绑定到当前用户
    from app.schemas.device import DeviceUpdate
    device = await DeviceService.update_device(db, device, DeviceUpdate(
        user_id=current_user.id,
    ))
    
    return ResponseModel(data=_build_device_response(device, current_user.phone))


@router.delete("/me/devices/{device_id}", response_model=ResponseModel, summary="解绑设备")
async def unbind_device(device_id: int, current_user: CurrentUser, db: DbSession):
    """
    解绑当前用户的设备
    """
    device = await DeviceService.get_device_by_id(db, device_id)
    
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="设备不存在",
        )
    
    if device.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="无权操作此设备",
        )
    
    # 解绑设备（将 user_id 设为 None）
    from app.schemas.device import DeviceUpdate
    await DeviceService.update_device(db, device, DeviceUpdate(user_id=None))
    
    return ResponseModel(message="设备已解绑")

