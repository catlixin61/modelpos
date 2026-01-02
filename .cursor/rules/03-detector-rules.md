# 探测器端 (Detector) 开发规范

## 硬件规格

| 组件 | 规格 | 说明 |
|------|------|------|
| 主控芯片 | ESP32-S3 | **必须是 S3**，AI 指令集加速 |
| Flash | 16MB (推荐) | 存储固件 + LittleFS 日志 |
| PSRAM | 8MB (推荐) | AI 模型推理 |
| 传感器 | IMU (MPU6050/BMI270) | 姿态检测 |

## 技术栈

| 组件 | 框架/库 | 版本 |
|------|---------|------|
| 开发框架 | Arduino | 最新 |
| 构建工具 | PlatformIO | 最新 |
| BLE | NimBLE-Arduino | ≥ 1.4.0 |
| AI推理 | ESP-DL / TFLite Micro | - |
| 文件系统 | LittleFS | - |

## 目录结构

```
/detector
├── platformio.ini
├── src/
│   ├── main.cpp                    # 主程序入口
│   ├── config.h                    # 配置常量
│   ├── ble/
│   │   ├── ble_manager.h
│   │   ├── ble_manager.cpp         # BLE 管理
│   │   ├── ble_advertiser.h
│   │   └── ble_advertiser.cpp      # Extended Advertising
│   ├── sensor/
│   │   ├── imu_driver.h
│   │   └── imu_driver.cpp          # IMU 驱动
│   ├── ai/
│   │   ├── posture_model.h
│   │   └── posture_model.cpp       # AI 模型推理
│   ├── storage/
│   │   ├── log_storage.h
│   │   └── log_storage.cpp         # LittleFS 日志存储
│   └── utils/
│       └── binary_protocol.h       # 二进制协议
├── model/
│   └── posture_model.tflite        # TFLite 模型文件
├── data/                           # LittleFS 初始数据
└── test/
```

## PlatformIO 配置

```ini
; platformio.ini
[env:esp32-s3]
platform = espressif32
board = esp32-s3-devkitc-1
framework = arduino
board_build.mcu = esp32s3
board_build.f_cpu = 240000000L
board_build.flash_mode = qio
board_build.flash_size = 16MB
board_build.partitions = huge_app.csv

lib_deps = 
    h2zero/NimBLE-Arduino@^1.4.0
    bblanchon/ArduinoJson@^6.21.0

build_flags = 
    -DCONFIG_BT_NIMBLE_EXT_ADV=1
    -DCONFIG_BT_NIMBLE_MAX_CONNECTIONS=3
    -DBOARD_HAS_PSRAM
    -mfix-esp32-psram-cache-issue
```

## BLE Extended Advertising 规范

### 广播包结构

```cpp
// 触发包格式 (20 bytes max)
struct TriggerPacket {
    uint8_t header;           // 0xAA - 魔数
    uint8_t version;          // 协议版本
    uint8_t command;          // 命令类型: 0x01=驼背触发, 0x02=左倾, 0x03=右倾
    uint8_t intensity;        // 震动强度 0-100
    uint16_t duration_ms;     // 震动时长 (毫秒)
    uint8_t reserved[2];      // 保留
    uint32_t timestamp;       // Unix 时间戳
    uint8_t checksum;         // 校验和
} __attribute__((packed));
```

### 广播实现

```cpp
#include <NimBLEDevice.h>

class BLEAdvertiser {
public:
    void init() {
        NimBLEDevice::init("Posture-Detector");
        
        // 配置 Extended Advertising
        NimBLEExtAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
        
        NimBLEExtAdvertisement advData;
        advData.setLegacyAdvertising(false);  // 使用 Extended Adv
        advData.setConnectable(false);        // 不可连接
        advData.setScannable(false);          // 不可扫描
        
        pAdvertising->setInstanceData(0, advData);
    }
    
    void sendTrigger(uint8_t command, uint8_t intensity, uint16_t duration) {
        TriggerPacket packet = {
            .header = 0xAA,
            .version = 0x01,
            .command = command,
            .intensity = intensity,
            .duration_ms = duration,
            .reserved = {0, 0},
            .timestamp = (uint32_t)(millis() / 1000),
            .checksum = 0
        };
        packet.checksum = calculateChecksum(&packet);
        
        // 更新广播数据
        NimBLEExtAdvertisement advData;
        advData.setServiceData(POSTURE_SERVICE_UUID, 
            (uint8_t*)&packet, sizeof(packet));
        
        NimBLEDevice::getAdvertising()->setInstanceData(0, advData);
        NimBLEDevice::getAdvertising()->start(0);
    }
};
```

## GATT 服务规范 (手机连接模式)

```cpp
// 服务和特征 UUID
#define POSTURE_SERVICE_UUID        "0000AAAA-0000-1000-8000-00805F9B34FB"
#define POSTURE_DATA_CHAR_UUID      "0000AAAB-0000-1000-8000-00805F9B34FB"  // Notify
#define LOG_READ_CHAR_UUID          "0000AAAC-0000-1000-8000-00805F9B34FB"  // Read/Indicate
#define CONFIG_WRITE_CHAR_UUID      "0000AAAD-0000-1000-8000-00805F9B34FB"  // Write

class GATTServer {
public:
    void setupServices() {
        NimBLEServer* pServer = NimBLEDevice::createServer();
        NimBLEService* pService = pServer->createService(POSTURE_SERVICE_UUID);
        
        // 实时姿态数据 (Notify)
        pPostureChar = pService->createCharacteristic(
            POSTURE_DATA_CHAR_UUID,
            NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
        );
        
        // 日志读取 (分包传输)
        pLogReadChar = pService->createCharacteristic(
            LOG_READ_CHAR_UUID,
            NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::INDICATE
        );
        
        // 配置写入
        pConfigChar = pService->createCharacteristic(
            CONFIG_WRITE_CHAR_UUID,
            NIMBLE_PROPERTY::WRITE
        );
        pConfigChar->setCallbacks(new ConfigWriteCallback());
        
        pService->start();
    }
};
```

## AI 姿态检测规范

```cpp
#include "tensorflow/lite/micro/micro_interpreter.h"

class PostureModel {
private:
    static constexpr int kTensorArenaSize = 32 * 1024;
    uint8_t tensor_arena[kTensorArenaSize] __attribute__((aligned(16)));
    
    tflite::MicroInterpreter* interpreter;
    
public:
    enum PostureType {
        POSTURE_NORMAL = 0,
        POSTURE_HUNCHED = 1,      // 驼背
        POSTURE_LEAN_LEFT = 2,    // 左倾
        POSTURE_LEAN_RIGHT = 3    // 右倾
    };
    
    PostureType detect(float* imu_data, size_t len) {
        // 1. 预处理数据
        // 2. 推理
        // 3. 后处理返回结果
        TfLiteTensor* input = interpreter->input(0);
        memcpy(input->data.f, imu_data, len * sizeof(float));
        
        interpreter->Invoke();
        
        TfLiteTensor* output = interpreter->output(0);
        int maxIndex = 0;
        float maxValue = output->data.f[0];
        for (int i = 1; i < 4; i++) {
            if (output->data.f[i] > maxValue) {
                maxValue = output->data.f[i];
                maxIndex = i;
            }
        }
        return static_cast<PostureType>(maxIndex);
    }
};
```

## LittleFS 日志存储规范

```cpp
#include <LittleFS.h>
#include <ArduinoJson.h>

// 日志条目结构 (紧凑二进制格式)
struct LogEntry {
    uint32_t timestamp;       // Unix 时间戳
    uint8_t posture_type;     // 姿态类型
    uint16_t duration_sec;    // 持续时间(秒)
    uint8_t triggered;        // 是否触发了反馈器
} __attribute__((packed));

class LogStorage {
public:
    void init() {
        if (!LittleFS.begin(true)) {
            Serial.println("LittleFS Mount Failed");
        }
    }
    
    void appendLog(const LogEntry& entry) {
        File file = LittleFS.open("/logs.bin", FILE_APPEND);
        if (file) {
            file.write((uint8_t*)&entry, sizeof(entry));
            file.close();
        }
    }
    
    size_t readLogs(uint8_t* buffer, size_t maxSize, uint32_t sinceTimestamp) {
        File file = LittleFS.open("/logs.bin", FILE_READ);
        size_t bytesRead = 0;
        
        while (file.available() && bytesRead + sizeof(LogEntry) <= maxSize) {
            LogEntry entry;
            file.read((uint8_t*)&entry, sizeof(entry));
            
            if (entry.timestamp >= sinceTimestamp) {
                memcpy(buffer + bytesRead, &entry, sizeof(entry));
                bytesRead += sizeof(entry);
            }
        }
        file.close();
        return bytesRead;
    }
    
    void clearOldLogs(uint32_t beforeTimestamp) {
        // 清理过期日志逻辑
    }
};
```

## 主循环逻辑

```cpp
void loop() {
    // 1. 读取 IMU 数据
    imuDriver.readData(imuBuffer);
    
    // 2. AI 模型推理
    PostureModel::PostureType posture = postureModel.detect(imuBuffer, IMU_BUFFER_SIZE);
    
    // 3. 判断是否需要触发
    if (posture != PostureModel::POSTURE_NORMAL && shouldTrigger(posture)) {
        // 4. 发送广播包给反馈器
        bleAdvertiser.sendTrigger(
            static_cast<uint8_t>(posture),
            config.vibrationIntensity,
            config.vibrationDuration
        );
        
        // 5. 记录日志
        LogEntry entry = {
            .timestamp = getUnixTimestamp(),
            .posture_type = static_cast<uint8_t>(posture),
            .duration_sec = currentPostureDuration,
            .triggered = 1
        };
        logStorage.appendLog(entry);
    }
    
    // 6. 处理 GATT 连接请求 (如有)
    gattServer.handleConnections();
    
    delay(100); // 10Hz 检测频率
}
```

## 配置参数

```cpp
// config.h
struct DeviceConfig {
    char deviceName[32] = "Posture-Detector-001";
    uint8_t vibrationIntensity = 80;      // 震动强度 0-100
    uint16_t vibrationDuration = 500;     // 震动时长 ms
    uint16_t detectionInterval = 100;     // 检测间隔 ms
    uint16_t triggerThreshold = 3000;     // 触发阈值 (持续 3 秒)
    uint8_t feedbackerMac[6];             // 配对的反馈器 MAC
};
```
