#!/bin/bash

################################################################################
# APK自动下载服务 - 一键在线安装脚本
# 适用于CentOS 7/8/9 系统
# 服务器: 45.130.146.21:8080
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置参数
REPO_OWNER="YOUR_USERNAME"  # TODO: 替换为你的GitHub用户名
REPO_NAME="fantastic"       # TODO: 替换为你的仓库名
INSTALL_DIR="/opt/apk-downloader"
APK_DIR="/var/www/apk-downloads"
SERVER_IP="45.130.146.21"
SERVER_PORT="8080"
GITHUB_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main"

################################################################################
# 日志函数
################################################################################
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
    echo -e "\n${BLUE}[STEP]${NC} $1"
    echo -e "${BLUE}======================================${NC}"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

################################################################################
# 检查函数
################################################################################
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请以root权限运行此脚本"
        log_info "使用命令: sudo bash $0"
        exit 1
    fi
    log_success "Root权限检查通过"
}

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
    
    # 检查内核版本
    KERNEL_VERSION=$(uname -r)
    log_info "内核版本: $KERNEL_VERSION"
}

check_memory() {
    log_step "检查系统资源..."
    
    local total_mem=$(free -m | awk 'NR==2{print $2}')
    local available_mem=$(free -m | awk 'NR==2{print $7}')
    local disk_space=$(df -m / | awk 'NR==2{print $4}')
    
    log_info "总内存: ${total_mem}MB"
    log_info "可用内存: ${available_mem}MB"
    log_info "磁盘可用空间: ${disk_space}MB"
    
    if [ "$available_mem" -lt 200 ]; then
        log_warn "可用内存不足200MB，尝试释放缓存..."
        sync
        echo 3 > /proc/sys/vm/drop_caches
        sleep 2
        log_info "缓存已释放"
    fi
    
    if [ "$disk_space" -lt 1024 ]; then
        log_error "磁盘可用空间不足1GB，至少需要1GB可用空间"
        exit 1
    fi
    
    log_success "系统资源检查通过"
}

check_network() {
    log_step "检查网络连接..."
    
    # 检查网络连接
    if ! ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
        log_error "无法连接到外网"
        log_info "请检查网络设置"
        exit 1
    fi
    
    # 检查GitHub连接
    if ! curl -s --connect-timeout 10 --max-time 15 "https://api.github.com" > /dev/null 2>&1; then
        log_warn "无法连接到GitHub API，但不影响基本功能"
    fi
    
    log_success "网络连接正常"
}

################################################################################
# 依赖安装
################################################################################
install_dependencies() {
    log_step "安装系统依赖..."
    
    local missing_tools=()
    
    # 检查必要工具
    for tool in curl wget python3 jq systemctl; do
        if command -v $tool &> /dev/null; then
            log_info "✓ $tool 已安装"
        else
            log_warn "$tool 未安装"
            missing_tools+=($tool)
        fi
    done
    
    # 如果所有工具都已安装，跳过
    if [ ${#missing_tools[@]} -eq 0 ]; then
        log_success "所有依赖已满足，跳过安装"
        return 0
    fi
    
    log_info "开始安装缺失的工具..."
    
    # 更新yum缓存
    log_info "更新yum缓存..."
    yum makecache fast -y
    
    # 安装缺失的工具
    for tool in "${missing_tools[@]}"; do
        case $tool in
            curl)
                yum install -y curl
                ;;
            wget)
                yum install -y wget
                ;;
            python3)
                yum install -y python3
                ;;
            jq)
                yum install -y jq
                ;;
            systemctl)
                log_error "systemctl需要systemd支持"
                exit 1
                ;;
        esac
    done
    
    # 验证安装
    for tool in "${missing_tools[@]}"; do
        if command -v $tool &> /dev/null; then
            local version=$($tool --version 2>&1 | head -1)
            log_success "$tool 安装成功 ($version)"
        else
            log_error "$tool 安装失败"
            exit 1
        fi
    done
    
    log_success "依赖安装完成"
}

################################################################################
# 目录创建
################################################################################
create_directories() {
    log_step "创建目录结构..."
    
    # 创建安装目录
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        log_info "创建目录: $INSTALL_DIR"
    else
        log_warn "目录已存在: $INSTALL_DIR"
    fi
    
    # 创建APK下载目录
    if [ ! -d "$APK_DIR" ]; then
        mkdir -p "$APK_DIR"
        log_info "创建目录: $APK_DIR"
    else
        log_warn "目录已存在: $APK_DIR"
    fi
    
    # 创建日志目录
    mkdir -p "/var/log"
    
    # 设置权限
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$APK_DIR"
    
    log_success "目录结构创建完成"
}

################################################################################
# 文件下载
################################################################################
download_file() {
    local url="$1"
    local dest="$2"
    local filename=$(basename "$dest")
    
    log_info "下载: $filename"
    
    # 尝试使用curl下载
    if curl -fsSL --max-time 60 --retry 3 --connect-timeout 15 "$url" -o "$dest"; then
        # 检查文件大小
        if [ -s "$dest" ]; then
            log_success "$filename 下载成功"
            return 0
        else
            log_error "$filename 下载失败（文件为空）"
            rm -f "$dest"
            return 1
        fi
    else
        log_error "$filename 下载失败"
        rm -f "$dest"
        return 1
    fi
}

deploy_files() {
    log_step "部署项目文件..."
    
    # 定义需要下载的文件
    local files=(
        "apk-downloader.sh:$INSTALL_DIR/"
        "apk-server.py:$INSTALL_DIR/"
        "apk-downloader.service:/etc/systemd/system/"
        "apk-server.service:/etc/systemd/system/"
        "config.json:$INSTALL_DIR/"
    )
    
    local failed_files=()
    
    # 下载并部署每个文件
    for file_info in "${files[@]}"; do
        IFS=':' read -r filename dest_dir <<< "$file_info"
        local file_url="${RAW_URL}/${filename}"
        local dest_path="${dest_dir}${filename}"
        
        if download_file "$file_url" "$dest_path"; then
            # 设置执行权限
            case "$filename" in
                *.sh|*.py)
                    chmod +x "$dest_path"
                    ;;
            esac
        else
            failed_files+=("$filename")
        fi
    done
    
    # 检查是否有文件下载失败
    if [ ${#failed_files[@]} -gt 0 ]; then
        log_error "以下文件下载失败: ${failed_files[*]}"
        exit 1
    fi
    
    log_success "所有文件部署完成"
}

################################################################################
# 配置防火墙
################################################################################
configure_firewall() {
    log_step "配置防火墙..."
    
    # 检查firewalld是否安装
    if ! command -v firewall-cmd &> /dev/null; then
        log_warn "firewalld未安装，跳过防火墙配置"
        log_info "请手动开放端口: $SERVER_PORT"
        return 0
    fi
    
    # 启动并启用firewalld
    if ! systemctl is-active --quiet firewalld; then
        systemctl start firewalld
        log_info "启动firewalld服务"
    fi
    
    if ! systemctl is-enabled --quiet firewalld; then
        systemctl enable firewalld
        log_info "启用firewalld开机自启"
    fi
    
    # 开放端口
    firewall-cmd --permanent --add-port="${SERVER_PORT}/tcp" > /dev/null 2>&1
    firewall-cmd --reload > /dev/null 2>&1
    
    log_success "防火墙配置完成（端口 $SERVER_PORT 已开放）"
}

################################################################################
# 配置SELinux
################################################################################
configure_selinux() {
    log_step "配置SELinux..."
    
    if [ ! -f /etc/selinux/config ]; then
        log_info "SELinux未安装，跳过配置"
        return 0
    fi
    
    local selinux_status=$(getenforce 2>/dev/null || echo "Disabled")
    
    if [ "$selinux_status" = "Enforcing" ]; then
        log_warn "SELinux处于Enforcing模式"
        log_info "设置SELinux为Permissive模式..."
        setenforce 0
        log_info "已临时设置SELinux为Permissive模式"
        log_warn "如需永久禁用，请编辑 /etc/selinux/config"
    elif [ "$selinux_status" = "Disabled" ]; then
        log_info "SELinux已禁用"
    else
        log_info "SELinux当前状态: $selinux_status"
    fi
}

################################################################################
# 配置systemd服务
################################################################################
setup_services() {
    log_step "配置systemd服务..."
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用服务（开机自启）
    systemctl enable apk-downloader
    systemctl enable apk-server
    
    log_success "服务配置完成（已启用开机自启）"
}

################################################################################
# 启动服务
################################################################################
start_services() {
    log_step "启动服务..."
    
    # 停止可能存在的旧服务
    systemctl stop apk-downloader 2>/dev/null || true
    systemctl stop apk-server 2>/dev/null || true
    
    # 启动APK下载服务
    log_info "启动APK下载服务..."
    systemctl start apk-downloader
    sleep 2
    
    # 启动HTTP服务器
    log_info "启动HTTP服务器..."
    systemctl start apk-server
    sleep 2
    
    # 检查服务状态
    if systemctl is-active --quiet apk-downloader; then
        log_success "APK下载服务启动成功"
    else
        log_error "APK下载服务启动失败"
        systemctl status apk-downloader --no-pager -l
        exit 1
    fi
    
    if systemctl is-active --quiet apk-server; then
        log_success "HTTP服务器启动成功"
    else
        log_error "HTTP服务器启动失败"
        systemctl status apk-server --no-pager -l
        exit 1
    fi
}

################################################################################
# 验证安装
################################################################################
verify_installation() {
    log_step "验证安装..."
    
    # 检查服务状态
    echo ""
    log_info "服务状态:"
    echo "----------------------------------------"
    systemctl status apk-downloader --no-pager -l | head -10
    echo "----------------------------------------"
    systemctl status apk-server --no-pager -l | head -10
    echo "----------------------------------------"
    
    # 检查端口监听
    log_info "端口监听状态:"
    if netstat -tuln | grep -q ":${SERVER_PORT} "; then
        log_success "端口 $SERVER_PORT 正在监听"
        netstat -tuln | grep ":${SERVER_PORT} "
    else
        log_warn "端口 $SERVER_PORT 未检测到监听"
    fi
    
    # 检查文件
    log_info "关键文件检查:"
    for file in "$INSTALL_DIR/apk-downloader.sh" "$INSTALL_DIR/apk-server.py" "$INSTALL_DIR/config.json"; do
        if [ -f "$file" ]; then
            log_success "✓ $(basename $file)"
        else
            log_error "✗ $(basename $file)"
        fi
    done
    
    # 检查目录
    log_info "目录检查:"
    if [ -d "$APK_DIR" ]; then
        local apk_count=$(ls -1 "$APK_DIR"/*.apk 2>/dev/null | wc -l)
        log_success "✓ APK目录: $APK_DIR (当前有 $apk_count 个APK文件)"
    else
        log_error "✗ APK目录不存在"
    fi
    
    # 显示最终信息
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}        🎉 安装完成！${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}📋 访问信息:${NC}"
    echo "   主页地址: http://${SERVER_IP}:${SERVER_PORT}"
    echo "   直接下载: http://${SERVER_IP}:${SERVER_PORT}/xiazai ⭐"
    echo ""
    echo -e "${GREEN}📁 相关目录:${NC}"
    echo "   安装目录: $INSTALL_DIR"
    echo "   APK目录:  $APK_DIR"
    echo ""
    echo -e "${GREEN}🔧 服务管理:${NC}"
    echo "   查看状态: systemctl status apk-downloader apk-server"
    echo "   重启服务: systemctl restart apk-downloader apk-server"
    echo "   停止服务: systemctl stop apk-downloader apk-server"
    echo ""
    echo -e "${GREEN}📋 日志查看:${NC}"
    echo "   下载服务: journalctl -u apk-downloader -f"
    echo "   HTTP服务:  journalctl -u apk-server -f"
    echo ""
    echo -e "${GREEN}⬇️ 下载方式:${NC}"
    echo "   命令行:   curl -L http://${SERVER_IP}:${SERVER_PORT}/xiazai -o latest.apk"
    echo "   浏览器:   访问 http://${SERVER_IP}:${SERVER_PORT}/xiazai"
    echo ""
    echo -e "${GREEN}🔗 相关链接:${NC}"
    echo "   程序仓库: $GITHUB_URL"
    echo "   监控仓库: https://github.com/z0brk/netamade-releases"
    echo ""
    echo -e "${YELLOW}💡 提示:${NC}"
    echo "   - 系统每10分钟自动检查一次GitHub仓库更新"
    echo "   - 如有新版本会自动下载并删除旧版本"
    echo "   - 查看日志了解详细运行情况"
    echo ""
}

################################################################################
# 卸载函数
################################################################################
uninstall() {
    log_step "开始卸载..."
    
    # 停止并禁用服务
    log_info "停止服务..."
    systemctl stop apk-downloader apk-server 2>/dev/null || true
    systemctl disable apk-downloader apk-server 2>/dev/null || true
    
    # 删除服务文件
    log_info "删除服务文件..."
    rm -f /etc/systemd/system/apk-downloader.service
    rm -f /etc/systemd/system/apk-server.service
    systemctl daemon-reload
    
    # 删除安装目录
    log_info "删除安装目录..."
    rm -rf "$INSTALL_DIR"
    
    # 询问是否删除APK目录
    if [ -d "$APK_DIR" ]; then
        echo ""
        read -p "是否删除APK下载目录 $APK_DIR? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$APK_DIR"
            log_info "APK目录已删除"
        else
            log_info "APK目录已保留"
        fi
    fi
    
    # 关闭防火墙端口
    if command -v firewall-cmd &> /dev/null; then
        log_info "关闭防火墙端口..."
        firewall-cmd --permanent --remove-port="${SERVER_PORT}/tcp" 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
    fi
    
    log_success "卸载完成"
}

################################################################################
# 显示帮助信息
################################################################################
show_help() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  APK自动下载服务 - 一键安装脚本${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "用法: $0 [命令]"
    echo ""
    echo -e "命令:"
    echo -e "  ${GREEN}install${NC}     安装服务（默认）"
    echo -e "  ${GREEN}uninstall${NC}   卸载服务"
    echo -e "  ${GREEN}status${NC}      查看服务状态"
    echo -e "  ${GREEN}restart${NC}     重启服务"
    echo -e "  ${GREEN}logs${NC}        查看日志"
    echo -e "  ${GREEN}help${NC}        显示此帮助信息"
    echo ""
    echo -e "示例:"
    echo "  $0              # 安装服务"
    echo "  $0 install      # 安装服务"
    echo "  $0 status       # 查看状态"
    echo "  $0 uninstall    # 卸载服务"
    echo ""
    echo -e "系统要求:"
    echo "  - CentOS 7/8/9 或 RHEL 7/8/9"
    echo "  - Root权限"
    echo "  - 可访问GitHub"
    echo "  - 至少1GB可用磁盘空间"
    echo ""
}

################################################################################
# 主函数
################################################################################
main() {
    case "${1:-install}" in
        "install"|"")
            echo -e "${CYAN}========================================${NC}"
            echo -e "${CYAN}  APK自动下载服务 - 在线安装${NC}"
            echo -e "${CYAN}========================================${NC}"
            echo ""
            check_root
            check_system
            check_memory
            check_network
            install_dependencies
            create_directories
            deploy_files
            configure_firewall
            configure_selinux
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
            echo ""
            echo -e "${CYAN}服务状态:${NC}"
            echo "----------------------------------------"
            systemctl status apk-downloader apk-server --no-pager -l
            ;;
        "restart")
            check_root
            log_info "重启服务..."
            systemctl restart apk-downloader apk-server
            log_success "服务已重启"
            ;;
        "logs")
            check_root
            log_info "显示日志（按Ctrl+C退出）..."
            journalctl -u apk-downloader -u apk-server -f
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
