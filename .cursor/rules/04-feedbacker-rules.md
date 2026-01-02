# 反馈器端 (Feedbacker) 开发规范

## 硬件规格

| 组件 | 规格 | 说明 |
|------|------|------|
| 主控芯片 | ESP32-C3 | 低功耗、低成本、小体积 |
| Flash | 4MB | 最小配置足够 |
| 震动马达 | ERM/LRA | PWM 控制 |
| 电池 | 锂电池 (可选) | 便携场景 |

## 技术栈

| 组件 | 框架/库 | 版本 |
|------|---------|------|
| 开发框架 | Arduino | 最新 |
| 构建工具 | PlatformIO | 最新 |
| BLE | NimBLE-Arduino | ≥ 1.4.0 |

## 目录结构

```
/feedbacker
├── platformio.ini
├── src/
│   ├── main.cpp                    # 主程序入口
│   ├── config.h                    # 配置常量
│   ├── ble/
│   │   ├── ble_scanner.h
│   │   └── ble_scanner.cpp         # 被动扫描模块
│   ├── motor/
│   │   ├── motor_driver.h
│   │   └── motor_driver.cpp        # PWM 马达控制
│   └── utils/
│       ├── binary_protocol.h       # 协议解析
│       └── power_manager.h         # 电源管理
└── test/
```

## PlatformIO 配置

```ini
; platformio.ini
[env:esp32-c3]
platform = espressif32
board = esp32-c3-devkitm-1
framework = arduino
board_build.mcu = esp32c3
board_build.f_cpu = 160000000L
board_build.flash_mode = qio

lib_deps = 
    h2zero/NimBLE-Arduino@^1.4.0

build_flags = 
    -DCONFIG_BT_NIMBLE_EXT_ADV=1
    -DCONFIG_BT_NIMBLE_ROLE_BROADCASTER_DISABLED
    -DCONFIG_BT_NIMBLE_ROLE_PERIPHERAL_DISABLED
    -DCONFIG_BT_NIMBLE_ROLE_CENTRAL_DISABLED
```

## BLE 被动扫描规范

### 扫描配置

```cpp
#include <NimBLEDevice.h>

class BLEScanner : public NimBLEScanCallbacks {
private:
    uint8_t targetMac[6];                 // 配对的探测器 MAC
    bool filterByMac = false;
    
public:
    void init() {
        NimBLEDevice::init("");
        NimBLEDevice::setPower(ESP_PWR_LVL_N12);  // 低功耗模式
        
        NimBLEScan* pScan = NimBLEDevice::getScan();
        pScan->setScanCallbacks(this);
        pScan->setActiveScan(false);       // **被动扫描**
        pScan->setInterval(100);           // 扫描间隔 100ms
        pScan->setWindow(80);              // 扫描窗口 80ms
        pScan->setDuplicateFilter(false);  // 允许重复包
    }
    
    void startScanning() {
        NimBLEDevice::getScan()->start(0, false);  // 永久扫描
    }
    
    void setTargetMac(const uint8_t* mac) {
        memcpy(targetMac, mac, 6);
        filterByMac = true;
    }
    
    // 扫描结果回调
    void onResult(NimBLEAdvertisedDevice* advertisedDevice) override {
        // 过滤 MAC 地址
        if (filterByMac) {
            NimBLEAddress addr = advertisedDevice->getAddress();
            if (memcmp(addr.getNative(), targetMac, 6) != 0) {
                return;
            }
        }
        
        // 检查 Service Data
        if (advertisedDevice->haveServiceData()) {
            std::string serviceData = advertisedDevice->getServiceData(
                NimBLEUUID(POSTURE_SERVICE_UUID)
            );
            
            if (serviceData.length() >= sizeof(TriggerPacket)) {
                handleTriggerPacket((const TriggerPacket*)serviceData.data());
            }
        }
    }
    
private:
    void handleTriggerPacket(const TriggerPacket* packet) {
        // 验证包头和校验和
        if (packet->header != 0xAA) return;
        if (!verifyChecksum(packet)) return;
        
        // 触发马达
        MotorDriver::getInstance().vibrate(
            packet->intensity,
            packet->duration_ms
        );
    }
};
```

### 触发包解析

```cpp
// 与探测器共用的协议定义
struct TriggerPacket {
    uint8_t header;           // 0xAA - 魔数
    uint8_t version;          // 协议版本
    uint8_t command;          // 命令类型
    uint8_t intensity;        // 震动强度 0-100
    uint16_t duration_ms;     // 震动时长
    uint8_t reserved[2];
    uint32_t timestamp;
    uint8_t checksum;
} __attribute__((packed));

bool verifyChecksum(const TriggerPacket* packet) {
    uint8_t sum = 0;
    const uint8_t* data = (const uint8_t*)packet;
    for (size_t i = 0; i < sizeof(TriggerPacket) - 1; i++) {
        sum ^= data[i];
    }
    return sum == packet->checksum;
}
```

## PWM 马达控制规范

```cpp
class MotorDriver {
private:
    static MotorDriver* instance;
    
    const int MOTOR_PIN = 5;              // GPIO5
    const int PWM_CHANNEL = 0;
    const int PWM_FREQ = 20000;           // 20kHz
    const int PWM_RESOLUTION = 8;         // 8-bit (0-255)
    
    bool isVibrating = false;
    unsigned long vibrateEndTime = 0;
    
public:
    static MotorDriver& getInstance() {
        if (!instance) instance = new MotorDriver();
        return *instance;
    }
    
    void init() {
        ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
        ledcAttachPin(MOTOR_PIN, PWM_CHANNEL);
        ledcWrite(PWM_CHANNEL, 0);
    }
    
    void vibrate(uint8_t intensity, uint16_t duration_ms) {
        // 防止过于频繁的触发
        if (isVibrating && millis() < vibrateEndTime) {
            return;
        }
        
        // 强度映射: 0-100 -> 0-255
        uint8_t pwmValue = map(intensity, 0, 100, 0, 255);
        
        ledcWrite(PWM_CHANNEL, pwmValue);
        isVibrating = true;
        vibrateEndTime = millis() + duration_ms;
    }
    
    void update() {
        if (isVibrating && millis() >= vibrateEndTime) {
            ledcWrite(PWM_CHANNEL, 0);
            isVibrating = false;
        }
    }
    
    // 震动模式：短-长-短
    void vibratePattern(uint8_t intensity) {
        vibrate(intensity, 100);
        delay(50);
        vibrate(intensity, 300);
        delay(50);
        vibrate(intensity, 100);
    }
};
```

## 电源管理规范

```cpp
#include "esp_sleep.h"

class PowerManager {
public:
    void enterLightSleep(uint32_t duration_ms) {
        esp_sleep_enable_timer_wakeup(duration_ms * 1000);
        esp_light_sleep_start();
    }
    
    void optimizePower() {
        // 关闭 WiFi
        WiFi.mode(WIFI_OFF);
        
        // 降低 CPU 频率 (可选)
        setCpuFrequencyMhz(80);
        
        // BLE 低功耗模式
        NimBLEDevice::setPower(ESP_PWR_LVL_N12);
    }
    
    float getBatteryLevel() {
        // 读取电池电压 ADC
        int adcValue = analogRead(BATTERY_ADC_PIN);
        float voltage = (adcValue / 4095.0) * 3.3 * 2;  // 分压电阻
        return mapVoltageToPercentage(voltage);
    }
    
private:
    float mapVoltageToPercentage(float voltage) {
        // 锂电池电压-电量映射
        if (voltage >= 4.2) return 100.0;
        if (voltage <= 3.0) return 0.0;
        return (voltage - 3.0) / (4.2 - 3.0) * 100.0;
    }
};
```

## 主循环逻辑

```cpp
BLEScanner bleScanner;
MotorDriver& motorDriver = MotorDriver::getInstance();
PowerManager powerManager;

void setup() {
    Serial.begin(115200);
    
    // 初始化组件
    motorDriver.init();
    bleScanner.init();
    powerManager.optimizePower();
    
    // 加载配对的探测器 MAC (从 EEPROM/NVS)
    loadPairedDetectorMac();
    
    // 开始被动扫描
    bleScanner.startScanning();
    
    Serial.println("Feedbacker Ready");
}

void loop() {
    // 更新马达状态
    motorDriver.update();
    
    // 低功耗：空闲时进入轻度睡眠
    // powerManager.enterLightSleep(10);
    
    delay(10);
}

void loadPairedDetectorMac() {
    // 从 NVS 加载配对的探测器 MAC
    Preferences prefs;
    prefs.begin("config", true);
    
    if (prefs.isKey("detector_mac")) {
        uint8_t mac[6];
        prefs.getBytes("detector_mac", mac, 6);
        bleScanner.setTargetMac(mac);
    }
    
    prefs.end();
}
```

## LED 状态指示

```cpp
class StatusLED {
private:
    const int LED_PIN = 8;  // ESP32-C3 内置 LED
    
public:
    void init() {
        pinMode(LED_PIN, OUTPUT);
    }
    
    void showStatus(Status status) {
        switch (status) {
            case Status::SCANNING:
                // 慢闪：扫描中
                blink(1000);
                break;
            case Status::TRIGGERED:
                // 快闪：收到触发
                blink(100);
                break;
            case Status::LOW_BATTERY:
                // 双闪：低电量
                doubleBlink();
                break;
        }
    }
    
private:
    void blink(int interval) {
        static unsigned long lastBlink = 0;
        static bool ledState = false;
        
        if (millis() - lastBlink >= interval) {
            ledState = !ledState;
            digitalWrite(LED_PIN, ledState);
            lastBlink = millis();
        }
    }
};
```

## 配置存储

```cpp
#include <Preferences.h>

struct FeedbackerConfig {
    uint8_t detectorMac[6];           // 配对的探测器 MAC
    uint8_t defaultIntensity = 80;    // 默认震动强度
    bool ledEnabled = true;           // LED 指示开关
};

void saveConfig(const FeedbackerConfig& config) {
    Preferences prefs;
    prefs.begin("config", false);
    prefs.putBytes("detector_mac", config.detectorMac, 6);
    prefs.putUChar("intensity", config.defaultIntensity);
    prefs.putBool("led_enabled", config.ledEnabled);
    prefs.end();
}
```
