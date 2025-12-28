#!/bin/bash

# APK自动下载服务一键安装脚本
# 适用于CentOS 7/8/9 系统
# 服务器IP: 45.130.146.21

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置参数
INSTALL_DIR="/opt/apk-downloader"
APK_DIR="/var/www/apk-downloads"
SERVICE_USER="root"
SERVER_IP="45.130.146.21"
SERVER_PORT="8080"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请以root权限运行此脚本"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    log_step "检查系统版本..."
    
    if [ ! -f /etc/centos-release ] && [ ! -f /etc/redhat-release ]; then
        log_error "此脚本仅支持CentOS/RHEL系统"
        exit 1
    fi
    
    if [ -f /etc/centos-release ]; then
        CENTOS_VERSION=$(cat /etc/centos-release | grep -oE '[0-9]+' | head -1)
        log_info "检测到CentOS $CENTOS_VERSION"
    else
        log_info "检测到RHEL系统"
    fi
}

# 安装系统依赖
install_dependencies() {
    log_step "安装系统依赖..."
    
    # 更新系统
    yum update -y
    
    # 安装基础工具
    yum install -y curl wget jq python3 python3-pip systemd firewalld
    
    # 安装Python依赖
    python3 -m pip install --upgrade pip
    
    log_info "系统依赖安装完成"
}

# 创建目录结构
create_directories() {
    log_step "创建目录结构..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$APK_DIR"
    mkdir -p "/var/log"
    
    # 设置权限
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$APK_DIR"
    
    log_info "目录结构创建完成"
}

# 部署脚本文件
deploy_scripts() {
    log_step "部署脚本文件..."
    
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 复制脚本文件
    if [ -f "$SCRIPT_DIR/apk-downloader.sh" ]; then
        cp "$SCRIPT_DIR/apk-downloader.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/apk-downloader.sh"
        log_info "部署 apk-downloader.sh"
    else
        log_error "找不到 apk-downloader.sh 文件"
        exit 1
    fi
    
    if [ -f "$SCRIPT_DIR/apk-server.py" ]; then
        cp "$SCRIPT_DIR/apk-server.py" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/apk-server.py"
        log_info "部署 apk-server.py"
    else
        log_error "找不到 apk-server.py 文件"
        exit 1
    fi
    
    # 复制systemd服务文件
    if [ -f "$SCRIPT_DIR/apk-downloader.service" ]; then
        cp "$SCRIPT_DIR/apk-downloader.service" "/etc/systemd/system/"
        log_info "部署 apk-downloader.service"
    else
        log_error "找不到 apk-downloader.service 文件"
        exit 1
    fi
    
    if [ -f "$SCRIPT_DIR/apk-server.service" ]; then
        cp "$SCRIPT_DIR/apk-server.service" "/etc/systemd/system/"
        log_info "部署 apk-server.service"
    else
        log_error "找不到 apk-server.service 文件"
        exit 1
    fi
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."
    
    # 启动firewalld
    systemctl enable firewalld
    systemctl start firewalld
    
    # 开放HTTP端口
    firewall-cmd --permanent --add-port="${SERVER_PORT}/tcp"
    firewall-cmd --reload
    
    log_info "防火墙配置完成，已开放端口 ${SERVER_PORT}"
}

# 配置systemd服务
setup_services() {
    log_step "配置systemd服务..."
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable apk-downloader
    systemctl enable apk-server
    
    log_info "systemd服务配置完成"
}

# 启动服务
start_services() {
    log_step "启动服务..."
    
    # 启动APK下载服务
    systemctl start apk-downloader
    
    # 等待几秒
    sleep 3
    
    # 启动HTTP服务器
    systemctl start apk-server
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet apk-downloader; then
        log_info "✓ APK下载服务启动成功"
    else
        log_error "✗ APK下载服务启动失败"
        systemctl status apk-downloader --no-pager
    fi
    
    if systemctl is-active --quiet apk-server; then
        log_info "✓ HTTP服务器启动成功"
    else
        log_error "✗ HTTP服务器启动失败"
        systemctl status apk-server --no-pager
    fi
}

# 验证安装
verify_installation() {
    log_step "验证安装..."
    
    # 检查服务状态
    log_info "服务状态:"
    echo "----------------------------------------"
    systemctl status apk-downloader --no-pager -l
    echo "----------------------------------------"
    systemctl status apk-server --no-pager -l
    echo "----------------------------------------"
    
    # 检查端口监听
    log_info "端口监听状态:"
    netstat -tuln | grep ":${SERVER_PORT} "
    
    # 检查目录
    log_info "安装目录:"
    ls -la "$INSTALL_DIR/"
    echo "----------------------------------------"
    log_info "APK下载目录:"
    ls -la "$APK_DIR/"
    
    # 显示访问信息
    echo ""
    log_info "========================================="
    log_info "安装完成！"
    log_info "========================================="
    echo ""
    log_info "🌐 访问地址: http://${SERVER_IP}:${SERVER_PORT}"
    log_info "📁 APK目录: ${APK_DIR}"
    log_info "📋 服务管理命令:"
    echo "  查看状态: systemctl status apk-downloader apk-server"
    echo "  重启服务: systemctl restart apk-downloader apk-server"
    echo "  查看日志: journalctl -u apk-downloader -f"
    echo "  查看日志: journalctl -u apk-server -f"
    echo ""
    log_info "🔧 API接口:"
    echo "  状态查询: curl http://${SERVER_IP}:${SERVER_PORT}/api/status"
    echo "  APK列表: curl http://${SERVER_IP}:${SERVER_PORT}/api/list"
    echo ""
    log_info "📱 系统每10分钟自动检查一次GitHub仓库更新"
}

# 卸载函数
uninstall() {
    log_step "开始卸载..."
    
    # 停止服务
    systemctl stop apk-downloader apk-server 2>/dev/null || true
    systemctl disable apk-downloader apk-server 2>/dev/null || true
    
    # 删除服务文件
    rm -f /etc/systemd/system/apk-downloader.service
    rm -f /etc/systemd/system/apk-server.service
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 删除安装目录
    rm -rf "$INSTALL_DIR"
    
    # 保留APK目录，询问用户
    read -p "是否删除APK下载目录 ${APK_DIR}? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$APK_DIR"
        log_info "已删除APK下载目录"
    fi
    
    # 关闭防火墙端口
    firewall-cmd --permanent --remove-port="${SERVER_PORT}/tcp" 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    
    log_info "卸载完成"
}

# 显示帮助信息
show_help() {
    echo "APK自动下载服务安装脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  install     安装服务"
    echo "  uninstall   卸载服务"
    echo "  status      查看服务状态"
    echo "  restart     重启服务"
    echo "  logs        查看日志"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 install     # 安装服务"
    echo "  $0 status      # 查看状态"
    echo "  $0 uninstall   # 卸载服务"
}

# 主函数
main() {
    case "${1:-install}" in
        "install")
            log_info "开始安装APK自动下载服务..."
            check_root
            check_system
            install_dependencies
            create_directories
            deploy_scripts
            configure_firewall
            setup_services
            start_services
            verify_installation
            ;;
        "uninstall")
            check_root
            uninstall
            ;;
        "status")
            check_root
            systemctl status apk-downloader apk-server --no-pager
            ;;
        "restart")
            check_root
            systemctl restart apk-downloader apk-server
            log_info "服务已重启"
            ;;
        "logs")
            check_root
            journalctl -u apk-downloader -u apk-server -f
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"