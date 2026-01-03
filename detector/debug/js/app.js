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
    logs: [],
    deviceId: null, // 从后端获取的 ID
    mac: new URLSearchParams(window.location.search).get('mac') || 'AA:BB:CC:DD:EE:01',
    lastTriggerState: 'idle' // 追踪触发状态：idle, accumulating, triggered
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
    triggerStatus: null,
    triggerIndicator: null,

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

    bleLog: document.getElementById('ble-log'),
    connectedDevice: document.getElementById('connected-device'),
    clearBleLogBtn: document.getElementById('clear-ble-log'),

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
    setupEventListeners();
    setupTimers();

    // 监听检测器事件
    postureDetector.addListener(handlePostureUpdate);
    window.addEventListener('detector-status', handleDetectorStatus);

    // 监听BLE事件
    window.addEventListener('ble-log', handleBleLog);
    window.addEventListener('ble-status-change', handleBleStatusChange);

    // 页面关闭时发送离线状态
    window.addEventListener('beforeunload', () => {
        if (elements.powerSwitch.checked) {
            // 使用 fetch + keepalive 确保在页面关闭时可靠发送
            const apiBase = 'http://localhost:8701/api/v1';
            const url = `${apiBase}/devices/mac/${encodeURIComponent(state.mac)}/online?is_online=false`;
            fetch(url, { method: 'POST', keepalive: true });
        }
    });

    showToast('模拟器已就绪', 'success');

    // 初始化在线状态
    if (elements.powerSwitch.checked) {
        reportOnlineStatus(true);
    }
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


            // 自动启动摄像头检测 (开机即探测)
            if (!postureDetector.isActive) {
                postureDetector.start().catch(err => {
                    console.error('自动启动摄像头失败:', err);
                    showToast('自动启动摄像头失败，请手动点击启动', 'error');
                });
            }
        } else {
            dot.className = 'status-dot offline';
            text.textContent = '离线';
            if (postureDetector.isActive) postureDetector.stop();
            if (bleSimulator.isAdvertising) bleSimulator.stopAdvertising();
            if (bleSimulator.isConnected) bleSimulator.disconnect();

        }

        // 同步到后端
        reportOnlineStatus(isOn);
    });


    elements.clearBleLogBtn.addEventListener('click', () => {
        elements.bleLog.innerHTML = '<div class="log-placeholder">暂无日志</div>';
    });

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
 * 处理姿态更新
 */
function handlePostureUpdate(data) {
    // 更新实时显示
    elements.currentPosture.textContent = data.name;
    elements.currentPosture.className = 'status-value ' + configManager.getPostureClass(data.type);

    elements.confidence.textContent = (data.confidence * 100).toFixed(0) + '%';
    elements.duration.textContent = (data.duration / 1000).toFixed(1) + 's';

    // 更新调试数据
    if (data.debug) {
        const personEl = document.getElementById('debug-person');
        const fpsEl = document.getElementById('debug-fps');

        if (personEl) {
            personEl.textContent = data.isPersonDetected ? '有人' : '无人';
            personEl.style.color = data.isPersonDetected ? '#22c55e' : '#ef4444';
        }

        if (fpsEl) {
            fpsEl.textContent = (data.fps || 0) + ' FPS';
            fpsEl.style.color = (data.fps > 5) ? '#00f2ff' : '#64748b';
        }

        // 处理 A/B/C 详细算法状态 (卡片化)
        if (data.debug.methods) {
            const m = data.debug.methods;
            const updateMethodCard = (id, valId, method) => {
                const card = document.getElementById(id);
                const val = document.getElementById(valId);
                if (card && val) {
                    val.textContent = `${method.val}${method.name === '颈部夹角' ? '°' : ''}`;
                    val.style.color = method.active ? '#ef4444' : '#22c55e';
                    // 动态切换卡片样式
                    if (method.active) {
                        card.classList.add('warning');
                    } else {
                        card.classList.remove('warning');
                    }
                }
            };

            updateMethodCard('card-method-a', 'val-method-a', m.A);
            updateMethodCard('card-method-b', 'val-method-b', m.B);
            updateMethodCard('card-method-c', 'val-method-c', m.C);
        }
    }

    // 检测次数
    state.detectionCount++;
    elements.detectionCount.textContent = state.detectionCount;

    // 触发判断 - 只针对驼背
    const thresholdMs = configManager.get('triggerThreshold') * 1000; // 5秒
    const isHunchedPosture = data.type === POSTURE_TYPE.HUNCHED;

    if (isHunchedPosture && data.duration > thresholdMs) {
        // 驼背超过5秒，触发广播
        if (state.lastTriggerState !== 'triggered') {
            state.lastTriggerState = 'triggered';

            state.triggerCount++;
            elements.triggerCount.textContent = state.triggerCount;

            // 确保广播已开启
            if (!bleSimulator.isAdvertising) {
                bleSimulator.startAdvertising();
            }

            // 发送驼背触发广播
            bleSimulator.sendTrigger(
                COMMAND_TYPE.TRIGGER_HUNCHED,
                configManager.get('vibrationIntensity'),
                configManager.get('vibrationDuration')
            );

            // 记录日志
            addLogEntry(data, true);

            showToast(`驼背触发！持续${(data.duration / 1000).toFixed(1)}秒`, 'warning');
        }
    } else {
        state.lastTriggerState = isHunchedPosture ? 'accumulating' : 'idle';
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

    // 连接状态
    if (isConnected) {
        elements.bleStatus.innerHTML = `<span class="status-dot online"></span> 已连接`;
        elements.bleStatus.classList.add('connected');
        elements.connectedDevice.textContent = deviceName;
    } else {
        elements.bleStatus.innerHTML = `<span class="status-dot offline"></span> 未连接`;
        elements.bleStatus.classList.remove('connected');
        elements.connectedDevice.textContent = '--';
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

/**
 * 同步在线状态到后端
 */
async function reportOnlineStatus(isOnline) {
    try {
        const mac = state.mac;
        const apiBase = 'http://localhost:8701/api/v1'; // 明确后端地址

        // 直接使用 MAC 地址更新在线状态
        const resp = await fetch(`${apiBase}/devices/mac/${encodeURIComponent(mac)}/online?is_online=${isOnline}`, {
            method: 'POST'
        });

        if (resp.ok) {
            console.log(`[Status] 已同步在线状态到后端: ${isOnline ? '在线' : '离线'}`);
        } else {
            const result = await resp.json();
            console.warn('[Status] 同步在线状态失败:', result.message || resp.statusText);
        }
    } catch (err) {
        console.error('[Status] 同步在线状态失败:', err);
    }
}

// 启动
document.addEventListener('DOMContentLoaded', initApp);
