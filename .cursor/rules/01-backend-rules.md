# 后台管理端 (Backend) 开发规范

## 技术栈要求

| 组件 | 版本/框架 | 说明 |
|------|-----------|------|
| Python | 3.11+ | 使用新特性：TypeAlias、更强类型提示 |
| Web框架 | FastAPI | 异步高性能，自动 OpenAPI 文档 |
| ORM | SQLAlchemy 2.0 | 异步模式 (asyncio) |
| 数据库 | PostgreSQL | 主数据存储 |
| 认证 | PyJWT | 手机端 Token 认证 |
| 部署 | Docker + Docker Compose + Nginx | 容器化部署 |

## 目录结构

```
/backend
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI 应用入口
│   ├── config.py               # 配置管理
│   ├── database.py             # 数据库连接
│   ├── api/
│   │   ├── __init__.py
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   ├── router.py       # API 路由汇总
│   │   │   ├── users.py        # 用户相关接口
│   │   │   ├── devices.py      # 设备管理接口
│   │   │   └── postures.py     # 姿态数据接口
│   │   └── deps.py             # 依赖注入
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py             # 用户模型
│   │   ├── device.py           # 设备模型 (探测器/反馈器)
│   │   └── posture_log.py      # 姿态日志模型
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user.py             # Pydantic 验证模型
│   │   ├── device.py
│   │   └── posture.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth.py             # JWT 认证服务
│   │   ├── user_service.py
│   │   └── device_service.py
│   └── utils/
│       ├── __init__.py
│       └── security.py         # 加密工具
├── alembic/                    # 数据库迁移
├── tests/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── .env.example
```

## 编码规范

### 类型提示 (必须使用 Python 3.11+ 特性)

```python
from typing import TypeAlias

# 定义类型别名
DeviceId: TypeAlias = str
UserId: TypeAlias = int

# 使用 | 替代 Union
async def get_device(device_id: DeviceId) -> Device | None:
    ...
```

### 异步编程

```python
# 使用 async/await
async def get_user_devices(user_id: UserId) -> list[Device]:
    async with async_session() as session:
        result = await session.execute(
            select(Device).where(Device.user_id == user_id)
        )
        return result.scalars().all()
```

### API 端点命名

- 使用 RESTful 风格
- 资源名使用复数形式
- 示例: `GET /api/v1/devices`, `POST /api/v1/devices/{device_id}/logs`

### 响应格式

```python
class ResponseModel(BaseModel):
    code: int = 0
    message: str = "success"
    data: Any = None
```

## 数据库模型规范

### 设备模型示例

```python
from sqlalchemy.orm import Mapped, mapped_column
from enum import Enum

class DeviceType(str, Enum):
    DETECTOR = "detector"      # 探测器
    FEEDBACKER = "feedbacker"  # 反馈器

class Device(Base):
    __tablename__ = "devices"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    mac_address: Mapped[str] = mapped_column(String(17), unique=True)
    device_type: Mapped[DeviceType]
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"))
    paired_device_id: Mapped[int | None] = mapped_column(ForeignKey("devices.id"))
    created_at: Mapped[datetime] = mapped_column(default=func.now())
```

## API 接口规范

### 用户认证

| 端点 | 方法 | 描述 |
|------|------|------|
| `/api/v1/auth/register` | POST | 手机号注册 |
| `/api/v1/auth/login` | POST | 登录获取JWT Token |
| `/api/v1/auth/refresh` | POST | 刷新 Token |

### 设备管理

| 端点 | 方法 | 描述 |
|------|------|------|
| `/api/v1/devices` | GET | 获取用户设备列表 |
| `/api/v1/devices` | POST | 注册新设备 |
| `/api/v1/devices/{id}` | PUT | 更新设备配置 |
| `/api/v1/devices/{id}/pair` | POST | 配对探测器与反馈器 |

### 姿态数据

| 端点 | 方法 | 描述 |
|------|------|------|
| `/api/v1/postures/logs` | POST | 上传姿态日志(批量) |
| `/api/v1/postures/stats` | GET | 获取统计数据 |
| `/api/v1/postures/weekly` | GET | 周统计图表数据 |

## 安全规范

- JWT Token 过期时间: 7 天
- 刷新 Token 过期时间: 30 天
- 密码使用 bcrypt 加密
- 敏感配置使用环境变量

## 部署配置

### Docker Compose 服务

- `api`: FastAPI 应用
- `db`: PostgreSQL 数据库
- `nginx`: 反向代理
- `redis`: 缓存(可选)
