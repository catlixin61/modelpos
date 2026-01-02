import asyncio
import sys
import os
from datetime import datetime

# 将项目根目录添加到 python 路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import async_session
from app.models.device import Device, DeviceType

async def seed_devices():
    async with async_session() as session:
        # 准备数据
        devices_data = [
            # 3个探测器
            {
                "mac_address": "AA:BB:CC:DD:EE:01",
                "device_type": DeviceType.DETECTOR,
                "name": "卧室探测器-01",
                "firmware_version": "1.0.2",
                "is_online": True,
                "last_seen_at": datetime.now()
            },
            {
                "mac_address": "AA:BB:CC:DD:EE:02",
                "device_type": DeviceType.DETECTOR,
                "name": "办公桌探测器-02",
                "firmware_version": "1.0.2",
                "is_online": False,
                "last_seen_at": datetime.now()
            },
            {
                "mac_address": "AA:BB:CC:DD:EE:03",
                "device_type": DeviceType.DETECTOR,
                "name": "书房探测器-03",
                "firmware_version": "1.0.1",
                "is_online": True,
                "last_seen_at": datetime.now()
            },
            # 2个反馈器
            {
                "mac_address": "FF:EE:DD:CC:BB:01",
                "device_type": DeviceType.FEEDBACKER,
                "name": "智能反馈器-01",
                "firmware_version": "1.0.0",
                "is_online": True,
                "last_seen_at": datetime.now()
            },
            {
                "mac_address": "FF:EE:DD:CC:BB:02",
                "device_type": DeviceType.FEEDBACKER,
                "name": "备用反馈器-02",
                "firmware_version": "1.0.0",
                "is_online": False,
                "last_seen_at": datetime.now()
            }
        ]
        
        for data in devices_data:
            # 检查 MAC 地址是否已存在
            from sqlalchemy import select
            stmt = select(Device).where(Device.mac_address == data["mac_address"])
            result = await session.execute(stmt)
            existing_device = result.scalar_one_or_none()
            
            if existing_device:
                print(f"设备 {data['mac_address']} 已存在，跳过。")
                continue
            
            device = Device(**data)
            session.add(device)
            print(f"已添加设备: {data['name']} ({data['mac_address']})")
        
        await session.commit()
        print("数据填充完成！")

if __name__ == "__main__":
    asyncio.run(seed_devices())
