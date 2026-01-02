# BLE 通信协议规范

## UUID 定义

| 名称 | UUID | 属性 |
|------|------|------|
| 姿态服务 | `0000AAAA-0000-1000-8000-00805F9B34FB` | 主服务 |
| 实时数据 | `0000AAAB-...` | Read, Notify |
| 日志读取 | `0000AAAC-...` | Read, Indicate |
| 配置写入 | `0000AAAD-...` | Write |

## 广播包格式 (Detector → Feedbacker)

```
Offset | Size | Field        | Description
-------|------|--------------|------------------
0      | 1    | header       | 0xAA (魔数)
1      | 1    | version      | 协议版本 (0x01)
2      | 4    | user_hash    | 用户ID哈希 (区分账号)
6      | 1    | command      | 命令类型
7      | 1    | intensity    | 震动强度 (0-100)
8      | 2    | duration_ms  | 震动时长 (ms)
10     | 4    | timestamp    | Unix 时间戳
14     | 2    | reserved     | 保留
16     | 1    | checksum     | XOR 校验和
```

### 命令类型

- `0x01` TRIGGER_HUNCHED (驼背)
- `0x02` TRIGGER_LEAN_LEFT (左倾)
- `0x03` TRIGGER_LEAN_RIGHT (右倾)
- `0x10` HEARTBEAT
- `0xFF` STOP

## GATT 日志读取协议

### 单条日志 (8 bytes)

```
Offset | Size | Field        | Description
-------|------|--------------|------------------
0      | 4    | timestamp    | Unix 时间戳
4      | 1    | posture_type | 姿态类型
5      | 2    | duration_sec | 持续时间
7      | 1    | triggered    | 是否触发反馈
```

## 配置命令

| 值 | 命令 | 说明 |
|----|------|------|
| 0x01 | SET_VIBRATION | 设置震动参数 |
| 0x02 | SET_THRESHOLD | 设置触发阈值 |
| 0x03 | SET_USER_HASH | 设置当前用户哈希 (用于广播匹配) |
| 0x04 | CLEAR_LOGS    | 清空日志 |
| 0x10 | SET_TIME      | 同步时间 |

## PostureType

- 0: NORMAL
- 1: HUNCHED
- 2: LEAN_LEFT
- 3: LEAN_RIGHT

## 字节序: Little-Endian
