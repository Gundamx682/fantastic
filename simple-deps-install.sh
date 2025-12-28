#!/bin/bash

# 简化的离线依赖安装脚本
# 直接安装最基础的依赖，避免复杂的依赖解析

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

# 检查系统
check_system() {
    if [ ! -f /etc/centos-release ] && [ ! -f /etc/redhat-release ]; then
        log_error "此脚本仅支持CentOS/RHEL系统"
        exit 1
    fi
    
    log_info "检测到 $(cat /etc/centos-release 2>/dev/null || cat /etc/redhat-release)"
}

# 安装基础依赖
install_basic_deps() {
    log_step "安装基础依赖..."
    
    # 检查已安装的包
    local missing=()
    
    # 检查关键工具
    for tool in curl python3 systemctl; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        log_info "✓ 所有关键工具已安装"
        return 0
    fi
    
    log_info "缺少工具: ${missing[*]}"
    
    # 尝试使用dnf（CentOS 8+）
    if command -v dnf &> /dev/null; then
        log_info "使用dnf安装..."
        for tool in "${missing[@]}"; do
            case "$tool" in
                "curl") dnf install -y curl --setopt=install_weak_deps=False || log_warn "curl安装失败" ;;
                "python3") dnf install -y python3 --setopt=install_weak_deps=False || log_warn "python3安装失败" ;;
                "systemctl") dnf install -y systemd --setopt=install_weak_deps=False || log_warn "systemd安装失败" ;;
            esac
        done
    # 使用yum（CentOS 7）
    elif command -v yum &> /dev/null; then
        log_info "使用yum安装..."
        for tool in "${missing[@]}"; do
            case "$tool" in
                "curl") yum install -y curl --setopt=install_weak_deps=False || log_warn "curl安装失败" ;;
                "python3") yum install -y python3 --setopt=install_weak_deps=False || log_warn "python3安装失败" ;;
                "systemctl") yum install -y systemd --setopt=install_weak_deps=False || log_warn "systemd安装失败" ;;
            esac
        done
    else
        log_error "找不到包管理器"
        exit 1
    fi
    
    # 再次检查
    local still_missing=()
    for tool in curl python3 systemctl; do
        if ! command -v "$tool" &> /dev/null; then
            still_missing+=("$tool")
        fi
    done
    
    if [ ${#still_missing[@]} -gt 0 ]; then
        log_error "仍有工具缺失: ${still_missing[*]}"
        log_error "请手动安装这些工具"
        exit 1
    fi
    
    log_info "✓ 基础依赖安装完成"
}

# 安装可选依赖
install_optional_deps() {
    log_step "安装可选依赖..."
    
    local optional=(wget jq firewalld)
    local installed=()
    
    for pkg in "${optional[@]}"; do
        if command -v "$pkg" &> /dev/null || rpm -q "$pkg" &> /dev/null; then
            log_info "✓ $pkg 已安装"
            continue
        fi
        
        log_info "安装 $pkg..."
        if command -v dnf &> /dev/null; then
            if dnf install -y "$pkg" --setopt=install_weak_deps=False 2>/dev/null; then
                installed+=("$pkg")
                log_info "✓ $pkg 安装成功"
            else
                log_warn "✗ $pkg 安装失败"
            fi
        elif command -v yum &> /dev/null; then
            if yum install -y "$pkg" --setopt=install_weak_deps=False 2>/dev/null; then
                installed+=("$pkg")
                log_info "✓ $pkg 安装成功"
            else
                log_warn "✗ $pkg 安装失败"
            fi
        fi
    done
    
    if [ ${#installed[@]} -gt 0 ]; then
        log_info "可选依赖安装完成: ${installed[*]}"
    else
        log_info "没有安装新的可选依赖"
    fi
}

# 检查pip
check_pip() {
    log_step "检查pip..."
    
    if python3 -m pip --version &> /dev/null; then
        log_info "✓ pip3 可用"
        return 0
    fi
    
    # 尝试安装pip
    log_info "尝试安装pip..."
    
    if command -v dnf &> /dev/null; then
        dnf install -y python3-pip --setopt=install_weak_deps=False || log_warn "pip安装失败"
    elif command -v yum &> /dev/null; then
        yum install -y python3-pip --setopt=install_weak_deps=False || log_warn "pip安装失败"
    fi
    
    if python3 -m pip --version &> /dev/null; then
        log_info "✓ pip3 安装成功"
    else
        log_warn "pip3 不可用，某些功能可能受限"
    fi
}

# 主函数
main() {
    log_info "开始安装依赖..."
    
    check_system
    install_basic_deps
    install_optional_deps
    check_pip
    
    log_step "依赖安装完成！"
    
    # 显示安装状态
    echo ""
    log_info "当前工具状态:"
    for tool in curl wget python3 jq systemctl firewall-cmd; do
        if command -v "$tool" &> /dev/null; then
            echo "  ✓ $tool - $(command -v "$tool")"
        else
            echo "  ✗ $tool - 未安装"
        fi
    done
    
    if python3 -m pip --version &> /dev/null; then
        echo "  ✓ pip3 - $(python3 -m pip --version)"
    else
        echo "  ✗ pip3 - 未安装"
    fi
}

main "$@"