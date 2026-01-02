/**
 * BLE 通信模拟器
 * 模拟 BLE 广播和 GATT 服务
 * 同时也包含真实的 Web Bluetooth API 调用尝试(作为 Central 角色去扫描反馈器)
 */
class BleSimulator {
    constructor() {
        this.isAdvertising = false;
        this.isConnected = false;
        this.connectedDevice = null;
        this.advertisingInterval = null;

        // 定义服务特征值存储
        this.gattServer = {
            [configManager.get().ble.postureDataCharUUID]: {
                value: new Uint8Array(0),
                notifying: false
            },
            [configManager.get().ble.logReadCharUUID]: {
                value: new Uint8Array(0),
                indicating: false
            },
            [configManager.get().ble.configWriteCharUUID]: {
                value: new Uint8Array(0),
                onWrite: this.handleConfigWrite.bind(this)
            }
        };

        // 真实蓝牙对象
        this.realBluetoothDevice = null;
        this.realGattServer = null;
    }

    /**
     * 开始广播 (Detector -> Feedbacker)
     * 在浏览器中无法真正进行 Peripheral 广播，这里模拟发送逻辑
     */
    startAdvertising() {
        if (this.isAdvertising) return;

        this.isAdvertising = true;
        this.log('BLE', '开始 Extended Advertising (模拟)', 'info');

        // 模拟周期性广播心跳包
        this.advertisingInterval = setInterval(() => {
            // 正常情况下只发心跳，不需要频繁log，避免刷屏
            // 但为了演示，我们通过 sendTrigger 来发送具体的指令包
        }, 1000);

        // 尝试调用真实的蓝牙 API (如果用户想用浏览器作为 Central 连接反馈器)
        // 注意：这是反向的，仅仅是为了满足"调用本地蓝牙"的要求，辅助调试反馈器
        // this.scanForFeedbacker(); 

        this.notifyStatusChange();
    }

    /**
     * 停止广播
     */
    stopAdvertising() {
        if (!this.isAdvertising) return;

        this.isAdvertising = false;
        if (this.advertisingInterval) {
            clearInterval(this.advertisingInterval);
            this.advertisingInterval = null;
        }

        this.log('BLE', '停止广播', 'info');
        this.notifyStatusChange();
    }

    /**
     * 发送触发包 (模拟广播)
     * @param {number} command 命令类型
     * @param {number} intensity 震动强度
     * @param {number} duration 持续时间
     */
    sendTrigger(command, intensity, duration) {
        if (!this.isAdvertising) return;

        // 构造包数据 (按照 05-ble-protocol.md)
        // Header(1) + Ver(1) + Cmd(1) + Int(1) + Dur(2) + Res(2) + Ts(4) + Ck(1) = 13 bytes
        const buffer = new ArrayBuffer(13);
        const view = new DataView(buffer);

        view.setUint8(0, 0xAA);
        view.setUint8(1, 0x01);
        view.setUint8(2, command);
        view.setUint8(3, intensity);
        view.setUint16(4, duration, true); // Little-endian
        view.setUint16(6, 0, true);
        const timestamp = Math.floor(Date.now() / 1000);
        view.setUint32(8, timestamp, true);

        // 计算校验和 (简单的 XOR)
        let checksum = 0;
        const uint8Array = new Uint8Array(buffer);
        for (let i = 0; i < 12; i++) {
            checksum ^= uint8Array[i];
        }
        view.setUint8(12, checksum);

        // 转换为十六进制字符串用于显示
        const hexStr = Array.from(uint8Array)
            .map(b => b.toString(16).padStart(2, '0').toUpperCase())
            .join(' ');

        // 获取命令名称
        let cmdName = 'UNKNOWN';
        Object.entries(COMMAND_TYPE).forEach(([key, val]) => {
            if (val === command) cmdName = key;
        });

        this.log('ADV', `[${cmdName}] ${hexStr}`, 'success');

        // 如果连接了真实的反馈器(作为Central)，这里可以尝试写入 Characteristic
        if (this.realGattServer && this.realGattServer.connected) {
            this.writeToRealFeedbacker(uint8Array);
        }
    }

    /**
     * 模拟 iOS 连接 (GATT Server 角色)
     */
    simulateConnect() {
        if (this.isConnected) {
            this.disconnect();
            return;
        }

        this.isConnected = true;
        this.connectedDevice = {
            id: 'IOS-SIMULATOR-001',
            name: 'iPhone 15 Pro'
        };

        this.log('GATT', `设备已连接: ${this.connectedDevice.name}`, 'info');
        this.notifyStatusChange();

        // 模拟 iOS 读取配置
        setTimeout(() => {
            this.log('GATT', 'Central 读取了配置特征值', 'info');
        }, 500);

        // 模拟 iOS 订阅通知
        setTimeout(() => {
            this.gattServer[configManager.get().ble.postureDataCharUUID].notifying = true;
            this.log('GATT', 'Central 订阅了姿态数据通知', 'info');
        }, 1000);
    }

    /**
     * 断开连接
     */
    disconnect() {
        if (!this.isConnected) return;

        this.isConnected = false;
        this.connectedDevice = null;

        // 重置订阅状态
        Object.values(this.gattServer).forEach(char => {
            char.notifying = false;
            char.indicating = false;
        });

        this.log('GATT', '设备已断开连接', 'warning');
        this.notifyStatusChange();
    }

    /**
     * 发送姿态数据通知 (GATT Notify)
     */
    updatePostureCharacteristic(postureType, duration) {
        if (!this.isConnected) return;

        const charUUID = configManager.get().ble.postureDataCharUUID;
        if (!this.gattServer[charUUID].notifying) return;

        // 构造通知包
        // 这里简化为：Type(1) + Duration(2)
        const buffer = new ArrayBuffer(3);
        const view = new DataView(buffer);
        view.setUint8(0, postureType);
        view.setUint16(1, Math.floor(duration / 1000), true);

        const hexStr = Array.from(new Uint8Array(buffer))
            .map(b => b.toString(16).padStart(2, '0'))
            .join(' ');

        this.log('NOTIFY', `发送姿态更新: ${hexStr} (${configManager.getPostureName(postureType)})`, 'info');
    }

    /**
     * 处理配置写入
     */
    handleConfigWrite(data) {
        // data 是 Uint8Array
        const view = new DataView(data.buffer);
        const cmd = view.getUint8(0);

        let cmdName = 'UNKNOWN';
        Object.entries(CONFIG_COMMAND).forEach(([key, val]) => {
            if (val === cmd) cmdName = key;
        });

        this.log('WRITE', `收到配置指令: ${cmdName}`, 'warning');

        // 简单的解析逻辑
        if (cmd === CONFIG_COMMAND.SET_VIBRATION) {
            const intensity = view.getUint8(1);
            const duration = view.getUint16(2, true);
            configManager.set({
                vibrationIntensity: intensity,
                vibrationDuration: duration
            });
            this.log('CONFIG', `更新震动: ${intensity}, ${duration}ms`, 'success');
        } else if (cmd === CONFIG_COMMAND.SET_THRESHOLD) {
            const threshold = view.getUint16(1, true);
            configManager.set('triggerThreshold', threshold / 1000);
            this.log('CONFIG', `更新阈值: ${threshold}ms`, 'success');
        }
    }

    /**
     * 添加日志
     */
    log(type, message, status = 'normal') {
        const entry = {
            time: new Date().toLocaleTimeString(),
            type,
            message,
            status
        };

        // 触发 UI 更新事件
        const event = new CustomEvent('ble-log', { detail: entry });
        window.dispatchEvent(event);
    }

    /**
     * 通知状态变更
     */
    notifyStatusChange() {
        const event = new CustomEvent('ble-status-change', {
            detail: {
                isAdvertising: this.isAdvertising,
                isConnected: this.isConnected,
                deviceName: this.connectedDevice ? this.connectedDevice.name : null
            }
        });
        window.dispatchEvent(event);
    }

    /* ============================================================
       真实蓝牙 API 部分 (试验性)
       用于在 Chrome 中测试连接真实的硬件
       ============================================================ */

    /**
     * 尝试扫描并连接真实的反馈器 (作为 Central)
     */
    async connectToRealFeedbacker() {
        if (!navigator.bluetooth) {
            alert('当前浏览器不支持 Web Bluetooth API');
            return;
        }

        try {
            this.log('BLUETOOTH', '正在请求蓝牙设备...', 'info');

            // 扫描特定服务 UUID
            const device = await navigator.bluetooth.requestDevice({
                filters: [{ namePrefix: 'Posture-Feedbacker' }],
                optionalServices: [configManager.get().ble.serviceUUID]
            });

            this.log('BLUETOOTH', `找到设备: ${device.name}`, 'success');

            const server = await device.gatt.connect();
            this.realGattServer = server;
            this.realBluetoothDevice = device;

            this.log('BLUETOOTH', '已连接到真实反馈器', 'success');

            device.addEventListener('gattserverdisconnected', () => {
                this.log('BLUETOOTH', '真实反馈器断开连接', 'warning');
                this.realGattServer = null;
            });

        } catch (error) {
            this.log('BLUETOOTH', `连接失败: ${error.message}`, 'error');
        }
    }

    /**
     * 向真实反馈器写入数据
     */
    async writeToRealFeedbacker(data) {
        if (!this.realGattServer) return;

        try {
            const service = await this.realGattServer.getPrimaryService(configManager.get().ble.serviceUUID);
            // 假设反馈器有一个特征值用于接收广播包数据的"透传" (用于调试)
            // 或者如果是标准协议，反馈器应该是 Observer，不需要连接
            // 这里仅仅作为演示如何写入

            // const char = await service.getCharacteristic(...) 
            // await char.writeValue(data);
        } catch (e) {
            console.error(e);
        }
    }
}

// 导出实例
window.bleSimulator = new BleSimulator();
