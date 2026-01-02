"""
北岛 AI 姿态矫正器 - FastAPI 应用入口
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import get_settings
from app.database import engine
from app.models.base import Base
from app.models import User  # 导入模型以创建表
from app.api.v1.router import router as api_router
from app.services.auth import AuthService

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期"""
    # 启动时: 初始化数据库
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # 创建默认管理员
    from app.database import async_session
    async with async_session() as db:
        from sqlalchemy import select
        result = await db.execute(
            select(User).where(User.phone == settings.admin_phone)
        )
        admin = result.scalar_one_or_none()
        
        if not admin:
            admin = User(
                phone=settings.admin_phone,
                password_hash=AuthService.hash_password(settings.admin_password),
                nickname="管理员",
                is_admin=True,
            )
            db.add(admin)
            await db.commit()
            print(f"✅ 创建默认管理员: {settings.admin_phone}")
    
    yield
    
    # 关闭时: 清理资源
    await engine.dispose()


# 创建 FastAPI 应用
app = FastAPI(
    title="北岛 AI 姿态矫正器",
    description="后台管理 API",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 挂载 API 路由
app.include_router(api_router)

# 挂载静态文件 (管理前端)
import os
admin_path = os.path.join(os.path.dirname(__file__), "..", "admin")
if os.path.exists(admin_path):
    app.mount("/admin", StaticFiles(directory=admin_path, html=True), name="admin")


@app.get("/", tags=["健康检查"])
async def root():
    """健康检查"""
    return {"status": "ok", "message": "北岛 AI 姿态矫正器后台服务"}


@app.get("/health", tags=["健康检查"])
async def health():
    """健康检查"""
    return {"status": "healthy"}
