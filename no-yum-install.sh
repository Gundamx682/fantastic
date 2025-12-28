#!/bin/bash

# 无YUM依赖安装脚本
# 直接下载RPM包进行安装，避免yum内存问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检测系统版本
detect_system() {
    if [ -f /etc/centos-release ]; then
        CENTOS_VERSION=$(cat /etc/centos-release | grep -oE '[0-9]+' | head -1)
        log_info "检测到CentOS $CENTOS_VERSION"
    elif [ -f /etc/redhat-release ]; then
        CENTOS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
        log_info "检测到RHEL $CENTOS_VERSION"
    else
        log_error "不支持的系统"
        exit 1
    fi
    
    ARCH=$(uname -m)
    log_info "系统架构: $ARCH"
}

# 下载RPM包
download_rpm() {
    local url="$1"
    local dest="$2"
    local pkg_name="$3"
    
    log_info "下载 $pkg_name..."
    
    if curl -L -m 60 --retry 3 -o "$dest" "$url"; then
        log_info "✓ $pkg_name 下载成功"
        return 0
    else
        log_warn "✗ $pkg_name 下载失败"
        return 1
    fi
}

# 安装RPM包
install_rpm() {
    local rpm_file="$1"
    local pkg_name="$2"
    
    if [ ! -f "$rpm_file" ]; then
        log_error "$pkg_name 文件不存在"
        return 1
    fi
    
    log_info "安装 $pkg_name..."
    
    # 使用rpm直接安装，跳过依赖检查
    if rpm -Uvh "$rpm_file" --nodeps --force 2>/dev/null; then
        log_info "✓ $pkg_name 安装成功"
        return 0
    else
        log_warn "✗ $pkg_name 安装失败"
        return 1
    fi
}

# 安装curl
install_curl() {
    if command -v curl &> /dev/null; then
        log_info "✓ curl 已安装"
        return 0
    fi
    
    log_step "安装curl..."
    
    local curl_urls=(
        "https://vault.centos.org/centos/9/BaseOS/x86_64/os/Packages/curl-7.76.1-19.el9.x86_64.rpm"
        "https://vault.centos.org/centos/8/BaseOS/x86_64/os/Packages/curl-7.61.1-22.el8.x86_64.rpm"
        "https://vault.centos.org/centos/7/os/x86_64/Packages/curl-7.29.0-59.el7.x86_64.rpm"
    )
    
    local temp_dir="/tmp/rpm_install"
    mkdir -p "$temp_dir"
    
    for url in "${curl_urls[@]}"; do
        local rpm_file="$temp_dir/$(basename "$url")"
        if download_rpm "$url" "$rpm_file" "curl"; then
            if install_rpm "$rpm_file" "curl"; then
                rm -rf "$temp_dir"
                return 0
            fi
        fi
    done
    
    rm -rf "$temp_dir"
    log_error "curl安装失败"
    return 1
}

# 安装python3
install_python3() {
    if command -v python3 &> /dev/null; then
        log_info "✓ python3 已安装"
        return 0
    fi
    
    log_step "安装python3..."
    
    local python3_urls=(
        "https://vault.centos.org/centos/9/AppStream/x86_64/os/Packages/python3-3.9.16-1.el9.x86_64.rpm"
        "https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/python3-3.6.8-48.el8.x86_64.rpm"
        "https://vault.centos.org/centos/7/extras/x86_64/Packages/python3-3.6.8-18.el7.x86_64.rpm"
    )
    
    local temp_dir="/tmp/rpm_install"
    mkdir -p "$temp_dir"
    
    for url in "${python3_urls[@]}"; do
        local rpm_file="$temp_dir/$(basename "$url")"
        if download_rpm "$url" "$rpm_file" "python3"; then
            if install_rpm "$rpm_file" "python3"; then
                rm -rf "$temp_dir"
                return 0
            fi
        fi
    done
    
    rm -rf "$temp_dir"
    log_error "python3安装失败"
    return 1
}

# 安装systemd（通常已内置）
install_systemd() {
    if command -v systemctl &> /dev/null; then
        log_info "✓ systemd 已安装"
        return 0
    fi
    
    log_warn "systemd未找到，但通常应该内置在系统中"
    return 0
}

# 创建软链接工具
create_tools() {
    log_step "创建基础工具..."
    
    # 创建基础的python3链接
    if command -v python3 &> /dev/null && [ ! -L /usr/bin/python ]; then
        ln -sf python3 /usr/bin/python 2>/dev/null || true
        log_info "✓ python链接创建"
    fi
    
    # 创建curl别名（如果没有curl）
    if ! command -v curl &> /dev/null && command -v wget &> /dev/null; then
        cat > /usr/local/bin/curl << 'EOF'
#!/bin/bash
wget -O- "$@"
EOF
        chmod +x /usr/local/bin/curl
        log_info "✓ curl别名创建"
    fi
}

# 检查安装结果
check_installation() {
    log_step "检查安装结果..."
    
    local success=true
    local tools=("curl" "python3")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_info "✓ $tool - $(command -v "$tool")"
        else
            log_error "✗ $tool - 未安装"
            success=false
        fi
    done
    
    if [ "$success" = true ]; then
        log_info "✓ 基础工具安装成功"
        return 0
    else
        log_error "✗ 部分工具安装失败"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始无YUM依赖安装..."
    
    detect_system
    
    # 安装关键工具
    install_curl || exit 1
    install_python3 || exit 1
    install_systemd
    
    # 创建辅助工具
    create_tools
    
    # 检查结果
    if check_installation; then
        log_step "✓ 无YUM依赖安装完成！"
        log_info "现在可以继续主程序安装"
    else
        log_error "安装失败，请检查系统"
        exit 1
    fi
}

main "$@"