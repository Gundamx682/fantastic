#!/bin/bash

# APK自动下载和更新脚本
# 用于监控GitHub仓库的最新release并自动下载APK文件

# 配置参数
REPO_OWNER="z0brk"
REPO_NAME="netamade-releases"
APK_DIR="/var/www/apk-downloads"
LOG_FILE="/var/log/apk-downloader.log"
PID_FILE="/var/run/apk-downloader.pid"
CHECK_INTERVAL=600  # 10分钟（秒）
SERVER_IP="45.130.146.21"
SERVER_PORT=8080

# 创建必要的目录
mkdir -p "$APK_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 检查并安装必要的工具
check_dependencies() {
    local missing_tools=()
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log "正在安装缺失的工具: ${missing_tools[*]}"
        yum update -y
        yum install -y ${missing_tools[*]}
    fi
}

# 获取最新release信息
get_latest_release() {
    local api_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
    local response
    
    log "正在获取最新release信息..."
    response=$(curl -s "$api_url")
    
    if [ $? -ne 0 ]; then
        log "错误: 无法获取GitHub API响应"
        return 1
    fi
    
    # 检查是否有错误
    if echo "$response" | grep -q '"message": "Not Found"'; then
        log "错误: 仓库不存在或没有release"
        return 1
    fi
    
    echo "$response"
}

# 下载APK文件
download_apk() {
    local release_info="$1"
    local apk_urls apk_name download_url
    
    # 提取APK下载链接
    apk_urls=$(echo "$release_info" | jq -r '.assets[] | select(.name | endswith(".apk")) | .browser_download_url')
    
    if [ -z "$apk_urls" ]; then
        log "警告: 最新release中没有找到APK文件"
        return 1
    fi
    
    # 下载每个APK文件
    while IFS= read -r download_url; do
        if [ -n "$download_url" ] && [ "$download_url" != "null" ]; then
            apk_name=$(basename "$download_url")
            local_file_path="${APK_DIR}/${apk_name}"
            
            log "正在下载APK: $apk_name"
            
            # 下载文件
            curl -L -o "$local_file_path" "$download_url"
            
            if [ $? -eq 0 ]; then
                log "成功下载: $apk_name"
                chmod 644 "$local_file_path"
            else
                log "错误: 下载失败 $apk_name"
                return 1
            fi
        fi
    done <<< "$apk_urls"
    
    return 0
}

# 清理旧APK文件
cleanup_old_apks() {
    log "正在清理旧APK文件..."
    
    # 保留最新的3个APK文件
    cd "$APK_DIR" || return 1
    ls -t *.apk 2>/dev/null | tail -n +4 | xargs -r rm -f
    
    log "旧APK文件清理完成"
}

# 检查是否有新版本
check_for_updates() {
    local current_version new_version release_info
    
    # 获取当前版本信息
    if [ -f "${APK_DIR}/current_version.txt" ]; then
        current_version=$(cat "${APK_DIR}/current_version.txt")
    else
        current_version=""
    fi
    
    # 获取最新release信息
    release_info=$(get_latest_release)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # 提取版本号
    new_version=$(echo "$release_info" | jq -r '.tag_name')
    
    if [ "$new_version" = "null" ] || [ -z "$new_version" ]; then
        log "错误: 无法获取版本号"
        return 1
    fi
    
    log "当前版本: $current_version"
    log "最新版本: $new_version"
    
    # 检查是否有新版本
    if [ "$current_version" != "$new_version" ]; then
        log "发现新版本: $new_version"
        
        # 下载新APK
        if download_apk "$release_info"; then
            # 清理旧文件
            cleanup_old_apks
            
            # 更新版本记录
            echo "$new_version" > "${APK_DIR}/current_version.txt"
            
            log "成功更新到版本: $new_version"
            return 0
        else
            log "错误: APK下载失败"
            return 1
        fi
    else
        log "没有新版本，当前已是最新"
        return 0
    fi
}

# 启动HTTP服务器
start_http_server() {
    log "正在启动HTTP服务器..."
    
    # 检查端口是否被占用
    if netstat -tuln | grep -q ":${SERVER_PORT} "; then
        log "警告: 端口 ${SERVER_PORT} 已被占用，尝试停止现有服务"
        pkill -f "python.*${SERVER_PORT}" || true
        sleep 2
    fi
    
    # 启动简单的HTTP服务器
    cd "$APK_DIR" || exit 1
    nohup python3 -m http.server ${SERVER_PORT} --bind 0.0.0.0 > /dev/null 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    
    # 检查服务器是否启动成功
    if netstat -tuln | grep -q ":${SERVER_PORT} "; then
        log "HTTP服务器启动成功，访问地址: http://${SERVER_IP}:${SERVER_PORT}"
    else
        log "错误: HTTP服务器启动失败"
        return 1
    fi
}

# 停止HTTP服务器
stop_http_server() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log "HTTP服务器已停止"
        fi
        rm -f "$PID_FILE"
    fi
}

# 主循环
main_loop() {
    log "APK下载服务启动"
    log "检查间隔: ${CHECK_INTERVAL}秒"
    log "下载目录: $APK_DIR"
    log "服务地址: http://${SERVER_IP}:${SERVER_PORT}"
    
    # 启动HTTP服务器
    start_http_server
    
    # 首次检查
    check_for_updates
    
    # 主循环
    while true; do
        sleep "$CHECK_INTERVAL"
        check_for_updates
    done
}

# 信号处理
cleanup() {
    log "正在停止服务..."
    stop_http_server
    exit 0
}

trap cleanup SIGTERM SIGINT

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请以root权限运行此脚本"
    exit 1
fi

# 检查依赖
check_dependencies

# 启动主循环
main_loop