/**
 * 探测器配置管理模块
 * 管理探测器的各项配置参数
 */

// 默认配置
const DEFAULT_CONFIG = {
    // 设备信息
    deviceName: 'Posture-Detector-001',
    deviceId: generateDeviceId(),

    // 震动配置
    vibrationIntensity: 80,     // 震动强度 0-100
    vibrationDuration: 500,     // 震动时长 ms

    // 检测配置
    detectionInterval: 100,     // 检测间隔 ms
    triggerThreshold: 3,        // 触发阈值 (秒)

    // 反馈器配置
    feedbackerMac: '',          // 配对的反馈器 MAC

    // BLE 配置
    ble: {
        serviceUUID: '0000AAAA-0000-1000-8000-00805F9B34FB',
        postureDataCharUUID: '0000AAAB-0000-1000-8000-00805F9B34FB',
        logReadCharUUID: '0000AAAC-0000-1000-8000-00805F9B34FB',
        configWriteCharUUID: '0000AAAD-0000-1000-8000-00805F9B34FB',
    },

    // 姿态类型定义
    postureTypes: {
        NORMAL: 0,
        HUNCHED: 1,
        LEAN_LEFT: 2,
        LEAN_RIGHT: 3
    },

    // 命令类型
    commands: {
        TRIGGER_HUNCHED: 0x01,
        TRIGGER_LEAN_LEFT: 0x02,
        TRIGGER_LEAN_RIGHT: 0x03,
        HEARTBEAT: 0x10,
        STOP: 0xFF
    },

    // 配置命令
    configCommands: {
        SET_VIBRATION: 0x01,
        SET_THRESHOLD: 0x02,
        SET_FEEDBACKER_MAC: 0x03,
        CLEAR_LOGS: 0x04,
        SET_TIME: 0x10
    }
};

// 生成设备ID
function generateDeviceId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let id = 'PD-';
    for (let i = 0; i < 6; i++) {
        id += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return id;
}

/**
 * 配置管理器类
 */
class ConfigManager {
    constructor() {
        this.config = { ...DEFAULT_CONFIG };
        this.listeners = [];
        this.loadFromStorage();
    }

    /**
     * 从本地存储加载配置
     */
    loadFromStorage() {
        try {
            const saved = localStorage.getItem('detector_config');
            if (saved) {
                const parsed = JSON.parse(saved);
                this.config = { ...DEFAULT_CONFIG, ...parsed };
                console.log('[Config] 已从本地存储加载配置');
            }
        } catch (e) {
            console.error('[Config] 加载配置失败:', e);
        }
    }

    /**
     * 保存配置到本地存储
     */
    saveToStorage() {
        try {
            const toSave = {
                deviceName: this.config.deviceName,
                vibrationIntensity: this.config.vibrationIntensity,
                vibrationDuration: this.config.vibrationDuration,
                detectionInterval: this.config.detectionInterval,
                triggerThreshold: this.config.triggerThreshold,
                feedbackerMac: this.config.feedbackerMac
            };
            localStorage.setItem('detector_config', JSON.stringify(toSave));
            console.log('[Config] 配置已保存');
        } catch (e) {
            console.error('[Config] 保存配置失败:', e);
        }
    }

    /**
     * 获取配置值
     */
    get(key) {
        return key ? this.config[key] : this.config;
    }

    /**
     * 设置配置值
     */
    set(key, value) {
        if (typeof key === 'object') {
            // 批量设置
            Object.assign(this.config, key);
        } else {
            this.config[key] = value;
        }
        this.notifyListeners();
    }

    /**
     * 重置为默认配置
     */
    reset() {
        this.config = { ...DEFAULT_CONFIG };
        this.config.deviceId = generateDeviceId();
        this.saveToStorage();
        this.notifyListeners();
    }

    /**
     * 添加配置变更监听器
     */
    addListener(callback) {
        this.listeners.push(callback);
    }

    /**
     * 移除配置变更监听器
     */
    removeListener(callback) {
        const index = this.listeners.indexOf(callback);
        if (index > -1) {
            this.listeners.splice(index, 1);
        }
    }

    /**
     * 通知所有监听器
     */
    notifyListeners() {
        this.listeners.forEach(cb => cb(this.config));
    }

    /**
     * 应用来自 iOS 的配置
     */
    applyRemoteConfig(remoteConfig) {
        console.log('[Config] 应用远程配置:', remoteConfig);

        if (remoteConfig.deviceName !== undefined) {
            this.config.deviceName = remoteConfig.deviceName;
        }
        if (remoteConfig.vibrationIntensity !== undefined) {
            this.config.vibrationIntensity = remoteConfig.vibrationIntensity;
        }
        if (remoteConfig.vibrationDuration !== undefined) {
            this.config.vibrationDuration = remoteConfig.vibrationDuration;
        }
        if (remoteConfig.triggerThreshold !== undefined) {
            this.config.triggerThreshold = remoteConfig.triggerThreshold;
        }
        if (remoteConfig.feedbackerMac !== undefined) {
            this.config.feedbackerMac = remoteConfig.feedbackerMac;
        }

        this.saveToStorage();
        this.notifyListeners();

        return true;
    }

    /**
     * 导出配置为二进制格式 (模拟 ESP32 存储格式)
     */
    exportBinary() {
        const buffer = new ArrayBuffer(64);
        const view = new DataView(buffer);

        // 写入配置
        view.setUint8(0, 0xAA);  // 魔数
        view.setUint8(1, 0x01);  // 版本
        view.setUint8(2, this.config.vibrationIntensity);
        view.setUint16(3, this.config.vibrationDuration, true);
        view.setUint16(5, this.config.detectionInterval, true);
        view.setUint16(7, Math.floor(this.config.triggerThreshold * 1000), true);

        // 写入设备名称 (最多32字节)
        const nameBytes = new TextEncoder().encode(this.config.deviceName);
        for (let i = 0; i < Math.min(nameBytes.length, 32); i++) {
            view.setUint8(9 + i, nameBytes[i]);
        }

        return new Uint8Array(buffer);
    }

    /**
     * 从二进制格式导入配置
     */
    importBinary(data) {
        const view = new DataView(data.buffer);

        if (view.getUint8(0) !== 0xAA) {
            throw new Error('无效的配置格式');
        }

        this.config.vibrationIntensity = view.getUint8(2);
        this.config.vibrationDuration = view.getUint16(3, true);
        this.config.detectionInterval = view.getUint16(5, true);
        this.config.triggerThreshold = view.getUint16(7, true) / 1000;

        // 读取设备名称
        const nameBytes = [];
        for (let i = 0; i < 32; i++) {
            const byte = view.getUint8(9 + i);
            if (byte === 0) break;
            nameBytes.push(byte);
        }
        if (nameBytes.length > 0) {
            this.config.deviceName = new TextDecoder().decode(new Uint8Array(nameBytes));
        }

        this.saveToStorage();
        this.notifyListeners();
    }

    /**
     * 获取姿态类型名称
     */
    getPostureName(type) {
        const names = {
            0: '正常',
            1: '驼背',
            2: '左倾',
            3: '右倾'
        };
        return names[type] || '未知';
    }

    /**
     * 获取姿态类型CSS类名
     */
    getPostureClass(type) {
        const classes = {
            0: 'normal',
            1: 'hunched',
            2: 'lean-left',
            3: 'lean-right'
        };
        return classes[type] || '';
    }
}

// 创建全局配置管理器实例
window.configManager = new ConfigManager();

// 导出常量供其他模块使用
window.POSTURE_TYPE = DEFAULT_CONFIG.postureTypes;
window.COMMAND_TYPE = DEFAULT_CONFIG.commands;
window.CONFIG_COMMAND = DEFAULT_CONFIG.configCommands;
