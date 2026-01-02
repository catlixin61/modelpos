/**
 * 应用主逻辑
 * 整合 PostureDetector 和 BleSimulator
 */

// 状态变量
const state = {
    uptime: 0,
    startTime: Date.now(),
    detectionCount: 0,
    triggerCount: 0,
    logs: []
};

// DOM 元素引用
const elements = {
    // 摄像头
    cameraContainer: document.querySelector('.camera-container'),
    video: document.getElementById('video'),
    canvas: document.getElementById('overlay-canvas'),
    placeholder: document.getElementById('camera-placeholder'),
    startCameraBtn: document.getElementById('start-camera-btn'),
    cameraToggleBtn: document.getElementById('camera-toggle'),
    fullscreenBtn: document.getElementById('fullscreen-btn'),

    // 状态显示
    currentPosture: document.getElementById('current-posture'),
    confidence: document.getElementById('confidence'),
    duration: document.getElementById('duration'),
    triggerStatus: document.getElementById('trigger-status'),
    triggerIndicator: document.getElementById('trigger-indicator'),

    // 统计
    uptime: document.getElementById('uptime'),
    detectionCount: document.getElementById('detection-count'),
    triggerCount: document.getElementById('trigger-count'),

    // 电源
    powerSwitch: document.getElementById('power-switch'),
    powerLabel: document.getElementById('power-label'),
    powerStatus: document.getElementById('power-status'),

    // BLE
    bleStatus: document.getElementById('ble-status'),
    bleAdvertiseBtn: document.getElementById('ble-advertise-btn'),
    bleSimulateBtn: document.getElementById('ble-simulate-connect'),
    bleLog: document.getElementById('ble-log'),
    connectedDevice: document.getElementById('connected-device'),
    clearBleLogBtn: document.getElementById('clear-ble-log'),

    // 配置
    configInputs: {
        name: document.getElementById('config-device-name'),
        vibrationIntensity: document.getElementById('config-vibration-intensity'),
        vibrationIntensityVal: document.getElementById('vibration-intensity-value'),
        vibrationDuration: document.getElementById('config-vibration-duration'),
        triggerThreshold: document.getElementById('config-trigger-threshold'),
        detectionInterval: document.getElementById('config-detection-interval'),
        feedbackerMac: document.getElementById('config-feedbacker-mac'),
    },
    saveConfigBtn: document.getElementById('config-save-btn'),
    resetConfigBtn: document.getElementById('config-reset-btn'),

    // 日志
    logTableBody: document.getElementById('detection-log-body'),
    logEmpty: document.getElementById('log-empty'),
    clearLogBtn: document.getElementById('clear-log-btn'),
    exportLogBtn: document.getElementById('export-log-btn'),

    // Toast
    toastContainer: document.getElementById('toast-container')
};

/**
 * 初始化应用
 */
function initApp() {
    loadConfigToUI();
    setupEventListeners();
    setupTimers();

    // 监听检测器事件
    postureDetector.addListener(handlePostureUpdate);
    window.addEventListener('detector-status', handleDetectorStatus);

    // 监听BLE事件
    window.addEventListener('ble-log', handleBleLog);
    window.addEventListener('ble-status-change', handleBleStatusChange);

    showToast('模拟器已就绪', 'success');
}

/**
 * 设置事件监听器
 */
function setupEventListeners() {
    // 摄像头控制
    elements.startCameraBtn.addEventListener('click', () => postureDetector.start());
    elements.cameraToggleBtn.addEventListener('click', () => {
        // 切换前后摄逻辑 (暂未实现完全，需 CameraUtils 支持)
        showToast('正在切换摄像头...', 'info');
    });
    elements.fullscreenBtn.addEventListener('click', toggleFullscreen);

    // 电源开关
    elements.powerSwitch.addEventListener('change', (e) => {
        const isOn = e.target.checked;
        elements.powerLabel.textContent = isOn ? '开机' : '关机';

        const dot = elements.powerStatus.querySelector('.status-dot');
        const text = elements.powerStatus.querySelector('span:last-child');

        if (isOn) {
            dot.className = 'status-dot online';
            text.textContent = '在线';
            elements.bleAdvertiseBtn.disabled = false;
        } else {
            dot.className = 'status-dot offline';
            text.textContent = '离线';
            if (postureDetector.isActive) postureDetector.stop();
            if (bleSimulator.isAdvertising) bleSimulator.stopAdvertising();
            if (bleSimulator.isConnected) bleSimulator.disconnect();
            elements.bleAdvertiseBtn.disabled = true;
        }
    });

    // BLE 控制
    elements.bleAdvertiseBtn.addEventListener('click', () => {
        if (bleSimulator.isAdvertising) {
            bleSimulator.stopAdvertising();
        } else {
            bleSimulator.startAdvertising();
        }
    });

    elements.bleSimulateBtn.addEventListener('click', () => bleSimulator.simulateConnect());
    elements.clearBleLogBtn.addEventListener('click', () => {
        elements.bleLog.innerHTML = '<div class="log-placeholder">暂无日志</div>';
    });

    // 配置控制
    elements.configInputs.vibrationIntensity.addEventListener('input', (e) => {
        elements.configInputs.vibrationIntensityVal.textContent = e.target.value + '%';
    });

    elements.saveConfigBtn.addEventListener('click', saveConfigFromUI);
    elements.resetConfigBtn.addEventListener('click', resetConfig);

    // 日志控制
    elements.clearLogBtn.addEventListener('click', () => {
        elements.logTableBody.innerHTML = '';
        elements.logEmpty.classList.remove('hidden');
        state.logs = [];
    });

    elements.exportLogBtn.addEventListener('click', () => {
        if (state.logs.length === 0) {
            showToast('没有可导出的日志', 'warning');
            return;
        }
        // 简单导出 CSV
        const csvContent = "data:text/csv;charset=utf-8,"
            + "Time,Posture,Confidence,Duration,Triggered\n"
            + state.logs.map(e => `${e.time},${e.posture},${e.confidence},${e.duration}s,${e.triggered}`).join("\n");

        const encodedUri = encodeURI(csvContent);
        const link = document.createElement("a");
        link.setAttribute("href", encodedUri);
        link.setAttribute("download", "detector_logs.csv");
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    });
}

/**
 * 设置定时器
 */
function setupTimers() {
    // 更新运行时间
    setInterval(() => {
        if (elements.powerSwitch.checked) {
            const now = Date.now();
            const diff = Math.floor((now - state.startTime) / 1000);

            const hours = Math.floor(diff / 3600);
            const minutes = Math.floor((diff % 3600) / 60);
            const seconds = diff % 60;

            elements.uptime.textContent =
                `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        }
    }, 1000);
}

/**
 * 加载配置到 UI
 */
function loadConfigToUI() {
    const cfg = configManager.get();
    elements.configInputs.name.value = cfg.deviceName;
    elements.configInputs.vibrationIntensity.value = cfg.vibrationIntensity;
    elements.configInputs.vibrationIntensityVal.textContent = cfg.vibrationIntensity + '%';
    elements.configInputs.vibrationDuration.value = cfg.vibrationDuration;
    elements.configInputs.triggerThreshold.value = cfg.triggerThreshold;
    elements.configInputs.detectionInterval.value = cfg.detectionInterval;
    elements.configInputs.feedbackerMac.value = cfg.feedbackerMac || '';
}

/**
 * 从 UI 保存配置
 */
function saveConfigFromUI() {
    const newConfig = {
        deviceName: elements.configInputs.name.value,
        vibrationIntensity: parseInt(elements.configInputs.vibrationIntensity.value),
        vibrationDuration: parseInt(elements.configInputs.vibrationDuration.value),
        triggerThreshold: parseFloat(elements.configInputs.triggerThreshold.value),
        detectionInterval: parseInt(elements.configInputs.detectionInterval.value),
        feedbackerMac: elements.configInputs.feedbackerMac.value
    };

    configManager.set(newConfig);
    configManager.saveToStorage();
    showToast('配置已保存', 'success');

    // 如果 BLE 已连接，模拟发送配置更新通知? (实际上配置是 Write 属性)
}

/**
 * 重置配置
 */
function resetConfig() {
    if (confirm('确定要重置所有配置为默认值吗？')) {
        configManager.reset();
        loadConfigToUI();
        showToast('配置已重置', 'info');
    }
}

/**
 * 处理姿态更新
 */
function handlePostureUpdate(data) {
    // 更新实时显示
    elements.currentPosture.textContent = data.name;
    elements.currentPosture.className = 'status-value ' + configManager.getPostureClass(data.type);

    elements.confidence.textContent = (data.confidence * 100).toFixed(0) + '%';
    elements.duration.textContent = (data.duration / 1000).toFixed(1) + 's';

    // 检测次数
    state.detectionCount++;
    elements.detectionCount.textContent = state.detectionCount;

    // 触发判断 logic
    const thresholdMs = configManager.get('triggerThreshold') * 1000;
    const isBadPosture = data.type !== POSTURE_TYPE.NORMAL;

    if (isBadPosture && data.duration > thresholdMs) {
        // 触发逻辑
        if (elements.triggerStatus.textContent !== '已触发') { // 简单的防抖，避免重复触发
            elements.triggerStatus.textContent = '已触发';
            elements.triggerIndicator.className = 'status-card danger';

            state.triggerCount++;
            elements.triggerCount.textContent = state.triggerCount;

            // 发送 BLE 广播
            let cmd = COMMAND_TYPE.TRIGGER_HUNCHED;
            if (data.type === POSTURE_TYPE.LEAN_LEFT) cmd = COMMAND_TYPE.TRIGGER_LEAN_LEFT;
            if (data.type === POSTURE_TYPE.LEAN_RIGHT) cmd = COMMAND_TYPE.TRIGGER_LEAN_RIGHT;

            bleSimulator.sendTrigger(
                cmd,
                configManager.get('vibrationIntensity'),
                configManager.get('vibrationDuration')
            );

            // 记录日志
            addLogEntry(data, true);
        }
    } else {
        elements.triggerStatus.textContent = isBadPosture ? '积累中...' : '未触发';
        elements.triggerIndicator.className = isBadPosture ? 'status-card warning' : 'status-card normal';
    }

    // 发送 Notification (GATT)
    if (bleSimulator.isConnected) {
        bleSimulator.updatePostureCharacteristic(data.type, data.duration);
    }
}

/**
 * 处理检测器状态
 */
function handleDetectorStatus(e) {
    const { status, message } = e.detail;
    if (status === 'active') {
        elements.placeholder.classList.add('hidden');
        elements.startCameraBtn.style.display = 'none';
        elements.cameraToggleBtn.style.display = 'block';

        // 自动打开电源
        if (!elements.powerSwitch.checked) {
            elements.powerSwitch.click();
        }
    } else if (status === 'error') {
        showToast('摄像头错误: ' + message, 'error');
    }
}

/**
 * 添加日志条目
 */
function addLogEntry(data, triggered) {
    const now = new Date();
    const timeStr = now.toLocaleTimeString();

    const entry = {
        time: timeStr,
        posture: data.name,
        confidence: (data.confidence * 100).toFixed(0) + '%',
        duration: (data.duration / 1000).toFixed(1),
        triggered: triggered ? '是' : '否'
    };

    state.logs.unshift(entry); // 加到前面
    if (state.logs.length > 50) state.logs.pop();

    // 更新 DOM
    const row = document.createElement('tr');
    row.innerHTML = `
        <td>${entry.time}</td>
        <td><span class="badge ${getBadgeClass(data.type)}">${entry.posture}</span></td>
        <td>${entry.confidence}</td>
        <td>${entry.duration}s</td>
        <td>${triggered ? '<span class="status-dot online"></span>' : ''}</td>
    `;

    elements.logTableBody.insertBefore(row, elements.logTableBody.firstChild);
    elements.logEmpty.classList.add('hidden');

    // 保持表格行数
    if (elements.logTableBody.children.length > 20) {
        elements.logTableBody.removeChild(elements.logTableBody.lastChild);
    }
}

function getBadgeClass(type) {
    switch (type) {
        case POSTURE_TYPE.NORMAL: return 'badge-success';
        case POSTURE_TYPE.HUNCHED: return 'badge-danger';
        default: return 'badge-warning';
    }
}

/**
 * 处理 BLE 日志
 */
function handleBleLog(e) {
    const log = e.detail;
    const div = document.createElement('div');
    div.className = 'log-entry';
    div.innerHTML = `
        <span class="log-time">[${log.time}]</span>
        <span class="log-msg ${log.status}">[${log.type}] ${log.message}</span>
    `;

    // 移除 placeholder
    if (elements.bleLog.querySelector('.log-placeholder')) {
        elements.bleLog.innerHTML = '';
    }

    elements.bleLog.appendChild(div);
    elements.bleLog.scrollTop = elements.bleLog.scrollHeight;
}

/**
 * 处理 BLE 状态变更
 */
function handleBleStatusChange(e) {
    const { isAdvertising, isConnected, deviceName } = e.detail;

    // 广播按钮状态
    if (isAdvertising) {
        elements.bleAdvertiseBtn.innerHTML = `
            <div class="loading-spinner" style="width:16px;height:16px;"></div> 停止广播
        `;
        elements.bleAdvertiseBtn.classList.add('btn-primary');
        elements.bleAdvertiseBtn.classList.remove('btn-secondary');
    } else {
        elements.bleAdvertiseBtn.innerHTML = `
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M6.5 6.5l11 11M6.5 17.5l11-11M12 2v4M12 18v4M2 12h4M18 12h4"/>
            </svg> 开始广播
        `;
        elements.bleAdvertiseBtn.classList.remove('btn-primary');
        elements.bleAdvertiseBtn.classList.add('btn-secondary');
    }

    // 连接状态
    if (isConnected) {
        elements.bleStatus.innerHTML = `<span class="status-dot online"></span> 已连接`;
        elements.bleStatus.classList.add('connected');
        elements.connectedDevice.textContent = deviceName;
        elements.bleSimulateBtn.textContent = '断开连接';
        elements.bleSimulateBtn.classList.add('btn-danger');
    } else {
        elements.bleStatus.innerHTML = `<span class="status-dot offline"></span> 未连接`;
        elements.bleStatus.classList.remove('connected');
        elements.connectedDevice.textContent = '--';
        elements.bleSimulateBtn.textContent = '模拟iOS连接';
        elements.bleSimulateBtn.classList.remove('btn-danger');
    }
}

/**
 * 全屏切换
 */
function toggleFullscreen() {
    if (!document.fullscreenElement) {
        elements.cameraContainer.requestFullscreen().catch(err => {
            console.warn(`Error attempting to enable fullscreen: ${err.message}`);
        });
    } else {
        document.exitFullscreen();
    }
}

/**
 * 显示 Toast
 */
function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    let icon = '';
    if (type === 'success') icon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>';
    else if (type === 'error') icon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>';
    else icon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>';

    toast.innerHTML = `
        <div class="toast-icon">${icon}</div>
        <div class="toast-message">${message}</div>
        <button class="toast-close" onclick="this.parentElement.remove()">×</button>
    `;

    elements.toastContainer.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// 启动
document.addEventListener('DOMContentLoaded', initApp);
