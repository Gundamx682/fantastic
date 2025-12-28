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

# 检查系统内存
check_memory() {
    local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    log_info "可用内存: ${available_mem}MB"
    
    if [ "$available_mem" -lt 200 ]; then
        log_warn "内存不足，尝试释放缓存..."
        sync
        echo 3 > /proc/sys/vm/drop_caches
        sleep 2
        log_info "缓存已释放，继续安装..."
    fi
}

# 安装系统依赖
install_dependencies() {
    log_step "安装系统依赖..."
    
    # 尝试下载并运行无yum安装脚本
    local no_yum_url="https://raw.githubusercontent.com/Gundamx682/fantastic/main/no-yum-install.sh"
    local temp_script="/tmp/no-yum-install.sh"
    
    # 如果有curl，尝试下载无yum脚本
    if command -v curl &> /dev/null; then
        if curl -fsSL --max-time 30 --retry 2 "$no_yum_url" -o "$temp_script"; then
            log_info "使用无YUM安装脚本..."
            chmod +x "$temp_script"
            if bash "$temp_script"; then
                log_info "✓ 无YUM依赖安装成功"
                rm -f "$temp_script"
                return 0
            else
                log_warn "无YUM安装失败，尝试其他方式..."
            fi
            rm -f "$temp_script"
        fi
    fi
    
    # 检查系统中已有的工具
    log_info "检查现有工具..."
    local has_curl=false
    local has_python3=false
    local has_systemctl=false
    
    if command -v curl &> /dev/null; then
        log_info "✓ curl 已存在"
        has_curl=true
    fi
    
    if command -v python3 &> /dev/null; then
        log_info "✓ python3 已存在"
        has_python3=true
    fi
    
    if command -v systemctl &> /dev/null; then
        log_info "✓ systemctl 已存在"
        has_systemctl=true
    fi
    
    # 如果关键工具都有，跳过安装
    if [ "$has_curl" = true ] && [ "$has_python3" = true ] && [ "$has_systemctl" = true ]; then
        log_info "✓ 所有关键工具已存在，跳过依赖安装"
        return 0
    fi
    
    # 尝试使用wget下载安装脚本
    if command -v wget &> /dev/null && [ "$has_curl" = false ]; then
        log_info "尝试使用wget下载安装脚本..."
        if wget --timeout=30 --tries=2 -q "$no_yum_url" -O "$temp_script"; then
            chmod +x "$temp_script"
            if bash "$temp_script"; then
                log_info "✓ 依赖安装成功"
                rm -f "$temp_script"
                return 0
            fi
            rm -f "$temp_script"
        fi
    fi
    
    # 最后的尝试：检查系统是否已经足够运行
    if [ "$has_python3" = true ] && [ "$has_systemctl" = true ]; then
        log_warn "curl不可用，但python3和systemctl存在"
        log_warn "创建curl替代方案..."
        
        # 创建curl的wget替代
        if command -v wget &> /dev/null; then
            cat > /usr/local/bin/curl << 'EOF'
#!/bin/bash
wget -O- "$@"
EOF
            chmod +x /usr/local/bin/curl
            log_info "✓ 创建curl替代方案"
            return 0
        fi
    fi
    
    # 如果还是缺少关键工具，给出手动安装建议
    local critical_missing=()
    if [ "$has_python3" = false ]; then
        critical_missing+=("python3")
    fi
    if [ "$has_systemctl" = false ]; then
        critical_missing+=("systemd")
    fi
    
    if [ ${#critical_missing[@]} -gt 0 ]; then
        log_error "缺少关键工具: ${critical_missing[*]}"
        log_error "请手动安装这些工具后重试："
        log_error "  CentOS 7: rpm -ivh https://vault.centos.org/centos/7/os/x86_64/Packages/python3-3.6.8-18.el7.x86_64.rpm"
        log_error "  CentOS 8: rpm -ivh https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/python3-3.6.8-48.el8.x86_64.rpm"
        log_error "  CentOS 9: rpm -ivh https://vault.centos.org/centos/9/AppStream/x86_64/os/Packages/python3-3.9.16-1.el9.x86_64.rpm"
        exit 1
    fi
    
    log_info "✓ 依赖检查完成"
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
    
    # 尝试从本地复制，如果失败则从GitHub下载
    deploy_file() {
        local filename="$1"
        local dest_dir="$2"
        local github_url="https://raw.githubusercontent.com/Gundamx682/fantastic/main/$filename"
        
        # 尝试从本地复制
        if [ -f "$SCRIPT_DIR/$filename" ]; then
            cp "$SCRIPT_DIR/$filename" "$dest_dir/"
            log_info "部署 $filename (本地)"
            return 0
        fi
        
        # 从GitHub下载
        log_info "下载 $filename..."
        if curl -fsSL --max-time 30 --retry 2 "$github_url" -o "$dest_dir/$filename"; then
            log_info "部署 $filename (GitHub)"
            return 0
        else
            log_error "部署 $filename 失败"
            return 1
        fi
    }
    
    # 部署主脚本文件
    if ! deploy_file "apk-downloader.sh" "$INSTALL_DIR"; then
        log_error "无法部署 apk-downloader.sh"
        exit 1
    fi
    chmod +x "$INSTALL_DIR/apk-downloader.sh"
    
    if ! deploy_file "apk-server.py" "$INSTALL_DIR"; then
        log_error "无法部署 apk-server.py"
        exit 1
    fi
    chmod +x "$INSTALL_DIR/apk-server.py"
    
    # 部署systemd服务文件
    if ! deploy_file "apk-downloader.service" "/etc/systemd/system"; then
        log_error "无法部署 apk-downloader.service"
        exit 1
    fi
    
    if ! deploy_file "apk-server.service" "/etc/systemd/system"; then
        log_error "无法部署 apk-server.service"
        exit 1
    fi
    
    log_info "所有脚本文件部署完成"
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
    log_info "⬇️ 直接下载: http://${SERVER_IP}:${SERVER_PORT}/xiazai"
    log_info "📁 APK目录: ${APK_DIR}"
    log_info "📋 服务管理命令:"
    echo "  查看状态: systemctl status apk-downloader apk-server"
    echo "  重启服务: systemctl restart apk-downloader apk-server"
    echo "  查看日志: journalctl -u apk-downloader -f"
    echo "  查看日志: journalctl -u apk-server -f"
    echo ""
    log_info "🔧 下载方式:"
    echo "  直接下载: curl -L http://${SERVER_IP}:${SERVER_PORT}/xiazai -o latest.apk"
    echo "  浏览器下载: 访问 http://${SERVER_IP}:${SERVER_PORT}/xiazai"
    echo ""
    log_info "📱 系统每10分钟自动检查一次GitHub仓库更新"
    echo ""
    log_info "🔗 程序仓库: https://github.com/Gundamx682/fantastic"
    log_info "🎯 监控仓库: https://github.com/z0brk/netamade-releases"
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