#!/bin/bash

# 快速部署脚本 - 从GitHub直接下载并部署APK自动下载服务
# 适用于CentOS 7/8/9 系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置参数
REPO_URL="https://raw.githubusercontent.com/Gundamx682/fantastic/main"
TEMP_DIR="/tmp/apk-downloader-$$"
INSTALL_DIR="/opt/apk-downloader"

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

# 下载文件
download_file() {
    local url="$1"
    local dest="$2"
    
    log_info "下载: $(basename "$dest")"
    
    if curl -fsSL "$url" -o "$dest"; then
        log_info "✓ 下载成功: $(basename "$dest")"
        return 0
    else
        log_error "✗ 下载失败: $(basename "$dest")"
        return 1
    fi
}

# 创建临时目录
create_temp_dir() {
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
}

# 清理临时目录
cleanup_temp() {
    rm -rf "$TEMP_DIR"
}

# 下载所有必需文件
download_files() {
    log_step "下载项目文件..."
    
    local files=(
        "apk-downloader.sh"
        "apk-server.py"
        "apk-downloader.service"
        "apk-server.service"
        "install.sh"
        "config.json"
        "README.md"
    )
    
    local download_errors=0
    
    for file in "${files[@]}"; do
        if ! download_file "${REPO_URL}/${file}" "$file"; then
            ((download_errors++))
        fi
    done
    
    if [ $download_errors -gt 0 ]; then
        log_error "有 $download_errors 个文件下载失败"
        return 1
    fi
    
    log_info "所有文件下载完成"
    return 0
}

# 验证文件完整性
verify_files() {
    log_step "验证文件完整性..."
    
    local required_files=(
        "apk-downloader.sh"
        "apk-server.py"
        "apk-downloader.service"
        "apk-server.service"
        "install.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "缺少必需文件: $file"
            return 1
        fi
        
        # 检查文件大小（避免下载空文件）
        if [ ! -s "$file" ]; then
            log_error "文件为空: $file"
            return 1
        fi
    done
    
    # 设置执行权限
    chmod +x apk-downloader.sh
    chmod +x install.sh
    chmod +x apk-server.py
    
    log_info "文件验证通过"
    return 0
}

# 复制文件到安装目录
copy_to_install_dir() {
    log_step "复制文件到安装目录..."
    
    mkdir -p "$INSTALL_DIR"
    
    # 复制核心文件
    cp apk-downloader.sh "$INSTALL_DIR/"
    cp apk-server.py "$INSTALL_DIR/"
    cp config.json "$INSTALL_DIR/"
    
    # 复制systemd服务文件
    cp apk-downloader.service /etc/systemd/system/
    cp apk-server.service /etc/systemd/system/
    
    log_info "文件复制完成"
}

# 执行安装
run_installation() {
    log_step "执行安装..."
    
    cd "$INSTALL_DIR"
    
    if ./install.sh install; then
        log_info "安装成功完成"
        return 0
    else
        log_error "安装失败"
        return 1
    fi
}

# 显示部署信息
show_deployment_info() {
    echo ""
    log_info "========================================="
    log_info "部署信息"
    log_info "========================================="
    echo ""
    log_info "📁 临时目录: $TEMP_DIR"
    log_info "📁 安装目录: $INSTALL_DIR"
    log_info "🌐 源仓库: $REPO_URL"
    echo ""
    
    if [ -d "$TEMP_DIR" ]; then
        log_info "📋 下载的文件:"
        ls -la "$TEMP_DIR/"
        echo ""
    fi
}

# 错误处理
handle_error() {
    log_error "部署过程中发生错误"
    cleanup_temp
    exit 1
}

# 主函数
main() {
    log_info "开始快速部署APK自动下载服务..."
    
    # 设置错误处理
    trap handle_error ERR
    
    # 检查权限
    check_root
    
    # 创建临时目录
    create_temp_dir
    
    # 显示部署信息
    show_deployment_info
    
    # 下载文件
    if ! download_files; then
        cleanup_temp
        exit 1
    fi
    
    # 验证文件
    if ! verify_files; then
        cleanup_temp
        exit 1
    fi
    
    # 复制到安装目录
    copy_to_install_dir
    
    # 执行安装
    if ! run_installation; then
        cleanup_temp
        exit 1
    fi
    
    # 清理临时文件
    cleanup_temp
    
    echo ""
    log_info "========================================="
    log_info "🎉 部署完成！"
    log_info "========================================="
    echo ""
    log_info "🌐 访问地址: http://45.130.146.21:8080"
    log_info "⬇️ 直接下载: http://45.130.146.21:8080/xiazai"
    log_info "📋 管理命令:"
    echo "  查看状态: systemctl status apk-downloader apk-server"
    echo "  重启服务: systemctl restart apk-downloader apk-server"
    echo "  查看日志: journalctl -u apk-downloader -f"
    echo ""
    log_info "📁 相关目录:"
    echo "  安装目录: $INSTALL_DIR"
    echo "  APK目录: /var/www/apk-downloads"
    echo ""
}

# 处理命令行参数
case "${1:-deploy}" in
    "deploy"|"")
        main
        ;;
    "download-only")
        log_info "仅下载文件模式..."
        check_root
        create_temp_dir
        download_files
        verify_files
        log_info "文件已下载到: $TEMP_DIR"
        log_info "手动安装命令:"
        echo "  cd $TEMP_DIR"
        echo "  sudo ./install.sh install"
        ;;
    "clean")
        log_info "清理临时文件..."
        rm -rf /tmp/apk-downloader-*
        log_info "清理完成"
        ;;
    "help"|"-h"|"--help")
        echo "快速部署脚本"
        echo ""
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  deploy          完整部署（默认）"
        echo "  download-only   仅下载文件，不安装"
        echo "  clean           清理临时文件"
        echo "  help            显示此帮助信息"
        echo ""
        echo "示例:"
        echo "  $0              # 完整部署"
        echo "  $0 download-only # 仅下载文件"
        ;;
    *)
        log_error "未知选项: $1"
        echo "使用 '$0 help' 查看帮助信息"
        exit 1
        ;;
esac