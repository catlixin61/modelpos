"""
认证 API
"""
from fastapi import APIRouter, HTTPException, status

from app.api.deps import DbSession
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse, RefreshTokenRequest
from app.schemas.common import ResponseModel
from app.services.auth import AuthService
from app.services.user_service import UserService

router = APIRouter(prefix="/auth", tags=["认证"])


@router.post("/register", response_model=ResponseModel[TokenResponse], summary="用户注册")
async def register(data: RegisterRequest, db: DbSession):
    """
    用户注册
    
    - **phone**: 手机号 (11位)
    - **password**: 密码 (至少6位)
    - **nickname**: 昵称 (可选)
    """
    # 检查手机号是否已注册
    existing = await UserService.get_user_by_phone(db, data.phone)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="手机号已注册",
        )
    
    # 创建用户
    from app.schemas.user import UserCreate
    user = await UserService.create_user(db, UserCreate(
        phone=data.phone,
        password=data.password,
        nickname=data.nickname,
    ))
    
    # 生成令牌
    access_token, expires_in = AuthService.create_access_token(user.id, user.is_admin)
    refresh_token = AuthService.create_refresh_token(user.id)
    
    return ResponseModel(data=TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
    ))


@router.post("/login", response_model=ResponseModel[TokenResponse], summary="用户登录")
async def login(data: LoginRequest, db: DbSession):
    """
    用户登录
    
    - **phone**: 手机号
    - **password**: 密码
    """
    user = await AuthService.authenticate_user(db, data.phone, data.password)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="手机号或密码错误",
        )
    
    # 更新最后登录时间
    await UserService.update_last_login(db, user)
    
    # 生成令牌
    access_token, expires_in = AuthService.create_access_token(user.id, user.is_admin)
    refresh_token = AuthService.create_refresh_token(user.id)
    
    return ResponseModel(data=TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
    ))


@router.post("/admin/login", response_model=ResponseModel[TokenResponse], summary="管理员登录")
async def admin_login(data: LoginRequest, db: DbSession):
    """
    管理员登录
    """
    user = await AuthService.authenticate_user(db, data.phone, data.password)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="手机号或密码错误",
        )
    
    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="非管理员账号",
        )
    
    # 更新最后登录时间
    await UserService.update_last_login(db, user)
    
    # 生成令牌
    access_token, expires_in = AuthService.create_access_token(user.id, user.is_admin)
    refresh_token = AuthService.create_refresh_token(user.id)
    
    return ResponseModel(data=TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
    ))


@router.post("/refresh", response_model=ResponseModel[TokenResponse], summary="刷新令牌")
async def refresh_token(data: RefreshTokenRequest, db: DbSession):
    """
    刷新访问令牌
    """
    payload = AuthService.decode_token(data.refresh_token)
    
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的刷新令牌",
        )
    
    user_id = int(payload.get("sub", 0))
    user = await AuthService.get_user_by_id(db, user_id)
    
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在或已禁用",
        )
    
    # 生成新令牌
    access_token, expires_in = AuthService.create_access_token(user.id, user.is_admin)
    new_refresh_token = AuthService.create_refresh_token(user.id)
    
    return ResponseModel(data=TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        expires_in=expires_in,
    ))
