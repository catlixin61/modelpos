/**
 * 姿态检测核心类
 * 基于 MediaPipe Pose 实现
 */
class PostureDetector {
    constructor() {
        this.videoElement = document.getElementById('video');
        this.canvasElement = document.getElementById('overlay-canvas');
        this.canvasCtx = this.canvasElement.getContext('2d');

        this.isActive = false;
        this.lastPosture = null;
        this.postureStartTime = 0;
        this.confidence = 0;

        // 人员检测状态
        this.isPersonDetected = false;
        this.lastPersonDetectedTime = 0;
        this.noPersonTimeout = 5000; // 5秒无人视为离开

        // 帧率控制
        this.lastFrameTime = 0;
        this.frameCount = 0;
        this.fpsStartTime = Date.now();
        this.currentFPS = 0;
        this.normalFrameInterval = 100;  // 有人时：100ms = 10fps
        this.lowPowerFrameInterval = 1000; // 无人时：1000ms = 1fps
        this.currentFrameInterval = this.normalFrameInterval;

        // 阈值配置
        this.thresholds = {
            leanAngle: 15,        // 侧倾角度阈值
            hunchedRatio: 0.70,   // 驼背判定比例 (鼻肩距/肩宽) - 数值越大越容易触发
            confidence: 0.6,      // 最小置信度
            personVisibility: 0.5 // 人员可见度阈值
        };

        this.listeners = [];

        this.initMediaPipe();
    }

    /**
     * 初始化 MediaPipe Pose
     */
    initMediaPipe() {
        this.pose = new Pose({
            locateFile: (file) => {
                return `https://cdn.jsdelivr.net/npm/@mediapipe/pose@0.5.1675469404/${file}`;
            }
        });

        this.pose.setOptions({
            modelComplexity: 2,
            smoothLandmarks: true,
            enableSegmentation: false,
            smoothSegmentation: false,
            minDetectionConfidence: 0.5,
            minTrackingConfidence: 0.5
        });

        this.pose.onResults(this.onResults.bind(this));

        // 初始化 Camera Utils
        // 注意：这里仅初始化，等待用户点击启动
        this.camera = null;
    }

    /**
     * 启动摄像头检测
     */
    /**
     * 启动摄像头检测
     */
    async start() {
        if (this.isActive) return;

        try {
            if (!this.camera) {
                this.camera = new Camera(this.videoElement, {
                    onFrame: async () => {
                        const now = Date.now();
                        // 根据当前设定的间隔控制帧率
                        if (now - this.lastFrameTime >= this.currentFrameInterval) {
                            this.lastFrameTime = now;
                            await this.pose.send({ image: this.videoElement });
                        }
                    },
                    width: 1280,
                    height: 720
                });
            }

            await this.camera.start();
            this.isActive = true;
            this.notifyStatus('active');

            // 初始调整 Canvas 尺寸（onResults 中也会持续校验）
            this.syncCanvasSize();

            console.log('[Detector] 摄像头已启动');
        } catch (error) {
            console.error('[Detector] 启动失败:', error);
            this.notifyStatus('error', error.message);
            throw error;
        }
    }

    /**
     * 停止检测
     */
    stop() {
        if (!this.isActive) return;

        if (this.camera) {
            this.camera.stop();
        }
        this.isActive = false;
        this.notifyStatus('inactive');
        this.isPersonDetected = false;

        // 清除 Canvas
        this.canvasCtx.clearRect(0, 0, this.canvasElement.width, this.canvasElement.height);
    }

    /**
     * 切换检测状态
     */
    async toggle() {
        if (this.isActive) {
            this.stop();
            return false;
        } else {
            await this.start();
            return true;
        }
    }

    /**
     * 处理检测结果
     */
    onResults(results) {
        const now = Date.now();

        // 计算 FPS (每秒更新一次)
        this.frameCount++;
        const elapsed = now - this.fpsStartTime;
        if (elapsed >= 1000) {
            this.currentFPS = Math.round((this.frameCount * 1000) / elapsed);
            this.frameCount = 0;
            this.fpsStartTime = now;
        }

        // 1. 人员存在性检查
        // 判断标准：是否有关键点，且躯干主要点可见度是否达标
        let hasPerson = false;
        if (results.poseLandmarks) {
            const leftShoulder = results.poseLandmarks[11];
            const rightShoulder = results.poseLandmarks[12];
            // 只要一侧肩膀可见度够高，就认为有人
            if (leftShoulder.visibility > this.thresholds.personVisibility ||
                rightShoulder.visibility > this.thresholds.personVisibility) {
                hasPerson = true;
            }
        }

        if (!hasPerson) {
            // 处理无人状态
            if (this.isPersonDetected) {
                // 刚检测到离开，检查是否达到 5 秒超时 (noPersonTimeout 已设为 5000)
                if (now - this.lastPersonDetectedTime > this.noPersonTimeout) {
                    this.isPersonDetected = false;
                    this.currentFrameInterval = this.lowPowerFrameInterval;
                    console.log('[Detector] 无人超过5秒，进入低功耗模式 (1 FPS)');
                }
            }

            // 无论是否超时，只要 FPS 更新了或处于离开过程中，就通知 UI
            // 这样用户能看到离开的倒计时和最终降频的效果
            if (elapsed >= 1000 || this.isPersonDetected) {
                this.notifyListeners({
                    type: -1,
                    name: this.isPersonDetected ? '人员离开中...' : '无人',
                    confidence: 0,
                    duration: 0,
                    isPersonDetected: this.isPersonDetected,
                    fps: this.currentFPS,
                    debug: { angle: '--', ratio: '--', viewType: '--', isHunched: false }
                });
            }

            this.canvasCtx.save();
            this.canvasCtx.clearRect(0, 0, this.canvasElement.width, this.canvasElement.height);
            this.canvasCtx.restore();
            return;
        }

        // 2. 有人状态更新
        if (!this.isPersonDetected) {
            this.isPersonDetected = true;
            this.currentFrameInterval = this.normalFrameInterval;
            console.log('[Detector] 检测到人员，恢复正常频率 (10 FPS)');
        }
        this.lastPersonDetectedTime = now;

        // 3. 绘制骨架
        this.drawPose(results);

        // 4. 分析姿态
        const analysis = this.analyzePosture(results.poseLandmarks);

        // 5. 更新状态
        this.updateState(analysis);
    }

    /**
     * 同步 Canvas 尺寸与视频比例
     */
    syncCanvasSize() {
        if (this.canvasElement.width !== this.videoElement.videoWidth && this.videoElement.videoWidth > 0) {
            this.canvasElement.width = this.videoElement.videoWidth;
            this.canvasElement.height = this.videoElement.videoHeight;
            console.log(`[Detector] Canvas 尺寸已同步: ${this.canvasElement.width}x${this.canvasElement.height}`);
        }
    }

    /**
     * 绘制骨架和关键点
     */
    drawPose(results) {
        const ctx = this.canvasCtx;
        const landmarks = results.poseLandmarks;

        // 确保 canvas 尺寸正确
        this.syncCanvasSize();

        ctx.save();
        ctx.clearRect(0, 0, this.canvasElement.width, this.canvasElement.height);

        const w = this.canvasElement.width;
        const h = this.canvasElement.height;

        // 使用 MediaPipe 绘制工具（如果可用）
        if (typeof drawConnectors !== 'undefined' && typeof POSE_CONNECTIONS !== 'undefined') {
            drawConnectors(ctx, landmarks, POSE_CONNECTIONS, { color: 'rgba(0, 255, 0, 0.4)', lineWidth: 0.8 });
        }
        if (typeof drawLandmarks !== 'undefined') {
            drawLandmarks(ctx, landmarks, { color: 'rgba(255, 0, 0, 0.4)', lineWidth: 0.5, radius: 0.8 });
        }

        // 手动绘制重要的关键点（更大更醒目）
        const keyPoints = [
            { index: 0, name: '鼻子', color: '#FF6B6B' },
            { index: 7, name: '左耳', color: '#4ECDC4' },
            { index: 8, name: '右耳', color: '#4ECDC4' },
            { index: 11, name: '左肩', color: '#45B7D1' },
            { index: 12, name: '右肩', color: '#45B7D1' },
            { index: 23, name: '左臀', color: '#96CEB4' },
            { index: 24, name: '右臀', color: '#96CEB4' },
        ];

        keyPoints.forEach(kp => {
            const point = landmarks[kp.index];
            if (point && point.visibility > 0.5) {
                const x = point.x * w;
                const y = point.y * h;

                // 绘制圆点
                ctx.beginPath();
                ctx.arc(x, y, 1.5, 0, 2 * Math.PI);
                ctx.fillStyle = kp.color;
                ctx.globalAlpha = 0.6;
                ctx.fill();
                ctx.globalAlpha = 1.0;

                // 绘制极简标签
                ctx.font = '7px Inter, sans-serif';
                ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
                ctx.fillText(kp.name, x + 4, y + 2);
            }
        });

        // 绘制肩膀中心线（用于判断驼背）
        const leftShoulder = landmarks[11];
        const rightShoulder = landmarks[12];
        const nose = landmarks[0];

        if (leftShoulder && rightShoulder && nose) {
            const midX = (leftShoulder.x + rightShoulder.x) / 2 * w;
            const midY = (leftShoulder.y + rightShoulder.y) / 2 * h;
            const noseX = nose.x * w;
            const noseY = nose.y * h;

            // 绘制鼻子到肩膀中点的连线
            ctx.beginPath();
            ctx.moveTo(noseX, noseY);
            ctx.lineTo(midX, midY);
            ctx.strokeStyle = 'rgba(255, 217, 61, 0.6)';
            ctx.lineWidth = 1;
            ctx.setLineDash([3, 3]);
            ctx.stroke();
            ctx.setLineDash([]);

            // 绘制肩膀中点
            ctx.beginPath();
            ctx.arc(midX, midY, 2, 0, 2 * Math.PI);
            ctx.fillStyle = '#FFD93D';
            ctx.fill();
        }

        ctx.restore();
    }

    /**
     * 姿态分析核心逻辑
     * 支持正面和侧面视角的驼背检测
     */
    analyzePosture(landmarks) {
        // 获取关键点
        const nose = landmarks[0];
        const leftShoulder = landmarks[11];
        const rightShoulder = landmarks[12];
        const leftEar = landmarks[7];
        const rightEar = landmarks[8];
        const leftHip = landmarks[23];
        const rightHip = landmarks[24];
        const leftWrist = landmarks[15];
        const rightWrist = landmarks[16];
        const leftElbow = landmarks[13];
        const rightElbow = landmarks[14];

        // 计算置信度
        const confidence = (nose.visibility + leftShoulder.visibility + rightShoulder.visibility) / 3;

        // 屏蔽位: 如果任意一只手或肘部举过肩膀，则不进行驼背判定
        const isHandRaised = (leftWrist && leftWrist.visibility > 0.5 && leftWrist.y < leftShoulder.y) ||
            (rightWrist && rightWrist.visibility > 0.5 && rightWrist.y < rightShoulder.y) ||
            (leftElbow && leftElbow.visibility > 0.5 && leftElbow.y < leftShoulder.y) ||
            (rightElbow && rightElbow.visibility > 0.5 && rightElbow.y < rightShoulder.y);

        // 基础中心点
        const midShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
        const midShoulderX = (leftShoulder.x + rightShoulder.x) / 2;
        const midEarY = (leftEar.y + rightEar.y) / 2;
        const midEarX = (leftEar.x + rightEar.x) / 2;
        const midHipY = (leftHip.y + rightHip.y) / 2;
        const midHipX = (leftHip.x + rightHip.x) / 2;

        // 躯干高度参考
        const torsoHeight = Math.abs(midHipY - midShoulderY);
        const safeTorsoHeight = torsoHeight > 0.05 ? torsoHeight : 0.5;

        // ========== 算法 A: 垂直落差法 (针对低头) ==========
        const noseHeightRatio = (midShoulderY - nose.y) / safeTorsoHeight;
        const noseDropRatio = (nose.y - midEarY) / safeTorsoHeight;
        const isHunchedA = (noseHeightRatio < 0.36) || (noseDropRatio > 0.08);

        // ========== 算法 B: 躯干前倾法 (针对前倾) ==========
        // 计算肩膀相对于髋部的水平偏移比例
        const torsoLeanOffset = Math.abs(midShoulderX - midHipX) / safeTorsoHeight;
        const isHunchedB = torsoLeanOffset > 0.10; // 降低前倾容忍度

        // ========== 算法 C: 颈-躯干夹角法 (针对含胸) ==========
        // 向量1: 肩 -> 髋 (向下)
        const v1x = midHipX - midShoulderX;
        const v1y = midHipY - midShoulderY;
        // 向量2: 肩 -> 耳 (向上)
        const v2x = midEarX - midShoulderX;
        const v2y = midEarY - midShoulderY;

        // 计算两条向量的夹角
        const angle1 = Math.atan2(v1y, v1x);
        const angle2 = Math.atan2(v2y, v2x);
        let neckAngle = Math.abs(angle1 - angle2) * (180 / Math.PI);
        if (neckAngle > 180) neckAngle = 360 - neckAngle;
        const isHunchedC = neckAngle < 165; // 提高颈部夹角灵敏度 (155 -> 165)

        // 最终综合判定: 如果举手，即使符合驼背特征也判定为正常
        let isHunched = (isHunchedA || isHunchedB || isHunchedC);
        if (isHandRaised) {
            isHunched = false;
        }

        // 更新调试数据
        this.currentDebugData = {
            ratio: noseHeightRatio.toFixed(2),
            viewType: '通用',
            isHunched: isHunched,
            isHandRaised: isHandRaised,
            // 记录三个算法的状态用于 UI 展示
            methods: {
                A: { active: isHunchedA, val: noseHeightRatio.toFixed(2), name: '高度落下' },
                B: { active: isHunchedB, val: torsoLeanOffset.toFixed(2), name: '躯干前倾' },
                C: { active: isHunchedC, val: neckAngle.toFixed(0), name: '颈部夹角' }
            },
            extra: `Hand:${isHandRaised ? 'UP' : 'Down'}`
        };

        return {
            type: isHunched ? POSTURE_TYPE.HUNCHED : POSTURE_TYPE.NORMAL,
            confidence: confidence,
            timestamp: Date.now()
        };
    }

    /**
     * 更新状态并通知
     */
    updateState(analysis) {
        if (analysis.confidence < this.thresholds.confidence) {
            return; // 置信度太低，忽略
        }

        const now = Date.now();
        const isHunched = analysis.type === POSTURE_TYPE.HUNCHED;

        if (isHunched) {
            if (this.lastPosture !== POSTURE_TYPE.HUNCHED) {
                // 刚开始驼背，记录开始时间
                this.postureStartTime = now;
            }
        } else {
            // 正常姿态，重置开始时间为0（或当前时间，取决于如何计算 duration）
            this.postureStartTime = 0;
        }

        this.lastPosture = analysis.type;

        // 计算持续时间：仅在驼背时计算
        const duration = (isHunched && this.postureStartTime > 0) ? (now - this.postureStartTime) : 0;

        // 通知 UI 和 BLE 模块
        this.notifyListeners({
            type: analysis.type,
            name: configManager.getPostureName(analysis.type),
            confidence: analysis.confidence,
            duration: duration,
            isPersonDetected: true,
            fps: this.currentFPS,
            debug: this.currentDebugData
        });
    }

    /**
     * 添加监听器
     */
    addListener(callback) {
        this.listeners.push(callback);
    }

    /**
     * 通知监听器
     */
    notifyListeners(data) {
        this.listeners.forEach(cb => cb(data));
    }

    /**
     * 通知状态变更
     */
    notifyStatus(status, message = null) {
        const event = new CustomEvent('detector-status', {
            detail: { status, message }
        });
        window.dispatchEvent(event);
    }
}

// 导出实例
window.postureDetector = new PostureDetector();
