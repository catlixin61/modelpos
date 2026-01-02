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
        this.lastPosture = POSTURE_TYPE.NORMAL;
        this.postureStartTime = 0;
        this.confidence = 0;

        // 阈值配置
        this.thresholds = {
            leanAngle: 15,        // 侧倾角度阈值
            hunchedRatio: 0.35,   // 驼背判定比例 (鼻肩距/肩宽)
            confidence: 0.6       // 最小置信度
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
            modelComplexity: 1,
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
    async start() {
        if (this.isActive) return;

        try {
            if (!this.camera) {
                this.camera = new Camera(this.videoElement, {
                    onFrame: async () => {
                        await this.pose.send({ image: this.videoElement });
                    },
                    width: 640,
                    height: 360
                });
            }

            await this.camera.start();
            this.isActive = true;
            this.notifyStatus('active');

            // 调整 Canvas 尺寸
            this.canvasElement.width = this.videoElement.videoWidth;
            this.canvasElement.height = this.videoElement.videoHeight;

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
        if (!results.poseLandmarks) {
            return;
        }

        // 1. 绘制骨架
        this.drawPose(results);

        // 2. 分析姿态
        const analysis = this.analyzePosture(results.poseLandmarks);

        // 3. 更新状态
        this.updateState(analysis);
    }

    /**
     * 绘制骨架
     */
    drawPose(results) {
        this.canvasCtx.save();
        this.canvasCtx.clearRect(0, 0, this.canvasElement.width, this.canvasElement.height);

        // 绘制连接线
        drawConnectors(this.canvasCtx, results.poseLandmarks, POSE_CONNECTIONS,
            { color: '#00FF00', lineWidth: 2 });

        // 绘制关键点
        drawLandmarks(this.canvasCtx, results.poseLandmarks,
            { color: '#FF0000', lineWidth: 1, radius: 3 });

        this.canvasCtx.restore();
    }

    /**
     * 姿态分析核心逻辑
     */
    analyzePosture(landmarks) {
        // 获取关键点
        const nose = landmarks[0];
        const leftShoulder = landmarks[11];
        const rightShoulder = landmarks[12];
        const leftEar = landmarks[7];
        const rightEar = landmarks[8];

        // 计算置信度 (使用关键部位的平均可见度)
        const confidence = (nose.visibility + leftShoulder.visibility + rightShoulder.visibility) / 3;

        // 1. 也是最简单的：判断左右倾
        // 计算两肩连线的斜率角度
        const dy = rightShoulder.y - leftShoulder.y;
        const dx = rightShoulder.x - leftShoulder.x;
        const angleRad = Math.atan2(dy, dx);
        const angleDeg = angleRad * (180 / Math.PI); // 0度为水平

        // 注意：由于 Canvas 图像是镜像的或坐标系原因，通常右肩在右边(x大)，左肩在左边(x小)
        // 但这里 landmarks 是归一化坐标，x: 0~1 (左->右)
        // rightShoulder.x > leftShoulder.x 是正常的
        // 如果 angleDeg > 0，说明右肩比左肩低 (y更大)，即向右倾斜

        let posture = POSTURE_TYPE.NORMAL;

        if (angleDeg > this.thresholds.leanAngle) {
            posture = POSTURE_TYPE.LEAN_RIGHT;
        } else if (angleDeg < -this.thresholds.leanAngle) {
            posture = POSTURE_TYPE.LEAN_LEFT;
        } else {
            // 2. 判断驼背 (Webcam 正面视角比较难，使用启发式方法)
            // 方法：计算鼻子到两肩连线中点的垂直距离与肩宽的比值
            // 当人驼背/低头时，鼻子会更靠近肩膀水平线

            const midShoulderX = (leftShoulder.x + rightShoulder.x) / 2;
            const midShoulderY = (leftShoulder.y + rightShoulder.y) / 2;

            const shoulderWidth = Math.sqrt(Math.pow(dx, 2) + Math.pow(dy, 2));
            const noseToShoulderDist = midShoulderY - nose.y; // 正常应该为正值

            // 归一化比率
            const ratio = noseToShoulderDist / shoulderWidth;

            // 可以在 debug 界面显示这个 ratio 以便调整
            this.currentDebugData = { angle: angleDeg.toFixed(1), ratio: ratio.toFixed(2) };

            // 如果比值小于阈值，说明鼻子太靠近肩膀，判定为驼背/低头
            if (ratio < this.thresholds.hunchedRatio) {
                posture = POSTURE_TYPE.HUNCHED;
            }
        }

        return {
            type: posture,
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

        if (this.lastPosture !== analysis.type) {
            // 姿态改变，重置计时器
            this.lastPosture = analysis.type;
            this.postureStartTime = now;
        }

        const duration = now - this.postureStartTime;

        // 通知 UI 和 BLE 模块
        this.notifyListeners({
            type: analysis.type,
            name: configManager.getPostureName(analysis.type),
            confidence: analysis.confidence,
            duration: duration,
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
