"""
北岛 AI 姿态矫正器 - 后台配置
"""
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """应用配置"""
    
    # 数据库
    database_url: str = "postgresql+asyncpg://user:password@localhost:5432/modelpos"
    
    # JWT 配置
    jwt_secret_key: str = "dev-secret-key"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 10080  # 7 天
    jwt_refresh_token_expire_days: int = 30
    
    # 管理员初始账号
    admin_phone: str = "13810799940"
    admin_password: str = "123456"
    
    # 调试模式
    debug: bool = True
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    """获取配置单例"""
    return Settings()
