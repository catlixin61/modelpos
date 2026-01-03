#!/bin/bash

# 北岛 AI 姿态矫正器 - 高可靠服务控制脚本
# 固定端口：Backend: 8701, DetectorSim: 8703, FeedbackerSim: 8704

WORKSPACE_DIR="/Users/mtysm/Developer/modelpos"
BACKEND_DIR="$WORKSPACE_DIR/backend"
DETECTOR_DIR="$WORKSPACE_DIR/detector/debug"
FEEDBACKER_DIR="$WORKSPACE_DIR/feedbacker/debug"

BACKEND_PORT=8701
DETECTOR_PORT=8703
FEEDBACKER_PORT=8704

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
    echo "使用方法: $0 {start|stop|restart|status|clean}"
    exit 1
}

# 检查端口占用情况并返回 PID
check_port() {
    local port=$1
    echo $(lsof -ti :$port)
}

# 启动之前先清理可能的僵尸进程
clean_ghosts() {
    echo -e "${YELLOW}正在清理旧的进程...${NC}"
    stop_all > /dev/null 2>&1
    sleep 1
}

start_backend() {
    echo -e "${BLUE}正在检查端口 $BACKEND_PORT (Backend)...${NC}"
    local PID=$(check_port $BACKEND_PORT)
    
    if [ ! -z "$PID" ]; then
        echo -e "${YELLOW}警告: 端口 $BACKEND_PORT 已被占用 (PID: $PID)。${NC}"
        echo -e "尝试重启后端服务..."
        kill -9 $PID 2>/dev/null
        sleep 1
    fi

    if [ ! -d "$BACKEND_DIR/venv" ]; then
        echo -e "${RED}错误: 后端虚拟环境不存在。请先运行依赖安装。${NC}"
        return 1
    fi
    
    cd "$BACKEND_DIR"
    nohup ./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port $BACKEND_PORT --reload > backend.log 2>&1 &
    
    # 稍微等待并验证
    sleep 2
    PID=$(check_port $BACKEND_PORT)
    if [ ! -z "$PID" ]; then
        echo -e "${GREEN}✅ 后端服务启动成功 (PID: $PID, Port: $BACKEND_PORT)${NC}"
    else
        echo -e "${RED}❌ 后端服务启动失败，请检查 backend.log${NC}"
    fi
}

start_simulators() {
    # Detector Simulator
    echo -e "${BLUE}正在检查端口 $DETECTOR_PORT (Detector Sim)...${NC}"
    local D_PID=$(check_port $DETECTOR_PORT)
    if [ ! -z "$D_PID" ]; then
        echo -e "${YELLOW}清理端口 $DETECTOR_PORT (PID: $D_PID)...${NC}"
        kill -9 $D_PID 2>/dev/null
        sleep 0.5
    fi
    
    cd "$DETECTOR_DIR"
    nohup python3 -m http.server $DETECTOR_PORT > detector.log 2>&1 &
    echo -e "${GREEN}✅ Detector 模拟器已启动 (Port: $DETECTOR_PORT)${NC}"

    # Feedbacker Simulator
    echo -e "${BLUE}正在检查端口 $FEEDBACKER_PORT (Feedbacker Sim)...${NC}"
    local F_PID=$(check_port $FEEDBACKER_PORT)
    if [ ! -z "$F_PID" ]; then
        echo -e "${YELLOW}清理端口 $FEEDBACKER_PORT (PID: $F_PID)...${NC}"
        kill -9 $F_PID 2>/dev/null
        sleep 0.5
    fi
    
    cd "$FEEDBACKER_DIR"
    nohup python3 -m http.server $FEEDBACKER_PORT > feedbacker.log 2>&1 &
    echo -e "${GREEN}✅ Feedbacker 模拟器已启动 (Port: $FEEDBACKER_PORT)${NC}"
}

stop_all() {
    echo -e "${RED}正在停止所有相关服务...${NC}"
    
    # 停止各端口进程
    local ports=($BACKEND_PORT $DETECTOR_PORT $FEEDBACKER_PORT)
    for port in "${ports[@]}"; do
        local pid=$(check_port $port)
        if [ ! -z "$pid" ]; then
            echo -e "正在停止端口 $port (PID: $pid)..."
            kill $pid 2>/dev/null || kill -9 $pid 2>/dev/null
        fi
    done
    echo -e "${GREEN}服务已停止。${NC}"
}

status() {
    echo -e "${BLUE}=== 北岛 AI 服务状态 ===${NC}"
    
    local B_PID=$(check_port $BACKEND_PORT)
    if [ ! -z "$B_PID" ]; then
        echo -e "Backend   : ${GREEN}运行中 (Port: $BACKEND_PORT)${NC}"
    else
        echo -e "Backend   : ${RED}已停止${NC}"
    fi
    
    local D_PID=$(check_port $DETECTOR_PORT)
    if [ ! -z "$D_PID" ]; then
        echo -e "Detector  : ${GREEN}运行中 (Port: $DETECTOR_PORT)${NC}"
    else
        echo -e "Detector  : ${RED}已停止${NC}"
    fi
    
    local F_PID=$(check_port $FEEDBACKER_PORT)
    if [ ! -z "$F_PID" ]; then
        echo -e "Feedbacker: ${GREEN}运行中 (Port: $FEEDBACKER_PORT)${NC}"
    else
        echo -e "Feedbacker: ${RED}已停止${NC}"
    fi
    
    echo -e "${BLUE}========================${NC}"
}

case "$1" in
    start)
        start_backend
        start_simulators
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 1
        start_backend
        start_simulators
        ;;
    status)
        status
        ;;
    clean)
        stop_all
        echo "清理日志文件..."
        rm -f "$BACKEND_DIR/backend.log" "$DETECTOR_DIR/detector.log" "$FEEDBACKER_DIR/feedbacker.log"
        ;;
    *)
        usage
        ;;
esac
