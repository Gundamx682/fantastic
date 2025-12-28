#!/bin/bash

# CentOS依赖下载脚本
# 用于下载APK自动下载服务所需的所有依赖包

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置参数
DEPS_DIR="offline-deps"
REPO_URL="https://vault.centos.org"
CENTOS_VERSION=$(rpm -E %{rhel})

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
    log_step "检查系统信息..."
    
    if [ ! -f /etc/centos-release ] && [ ! -f /etc/redhat-release ]; then
        log_error "此脚本仅支持CentOS/RHEL系统"
        exit 1
    fi
    
    if [ -f /etc/centos-release ]; then
        CENTOS_VERSION=$(cat /etc/centos-release | grep -oE '[0-9]+' | head -1)
        log_info "检测到CentOS $CENTOS_VERSION"
    else
        log_info "检测到RHEL系统"
        CENTOS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
    fi
    
    ARCH=$(uname -m)
    log_info "系统架构: $ARCH"
}

# 创建下载目录
create_directories() {
    log_step "创建下载目录..."
    
    rm -rf "$DEPS_DIR"
    mkdir -p "$DEPS_DIR"/{rpms,python}
    
    log_info "目录创建完成: $DEPS_DIR"
}

# 下载RPM包
download_rpms() {
    log_step "下载RPM依赖包..."
    
    # 定义需要下载的包
    local packages=(
        "curl"
        "wget"
        "jq"
        "python3"
        "python3-pip"
        "systemd"
        "firewalld"
    )
    
    # 启用PowerTools仓库（如果可用）
    if command -v dnf &> /dev/null; then
        dnf config-manager --set-enabled powertools 2>/dev/null || true
        dnf config-manager --set-enabled crb 2>/dev/null || true
    else
        yum-config-manager --enable powertools 2>/dev/null || true
        yum-config-manager --enable crb 2>/dev/null || true
    fi
    
    # 下载所有包及其依赖
    log_info "下载主要包及其依赖..."
    
    if command -v dnf &> /dev/null; then
        dnf download --resolve --destdir="$DEPS_DIR/rpms" "${packages[@]}" || true
    else
        yumdownloader --resolve --destdir="$DEPS_DIR/rpms" "${packages[@]}" || true
    fi
    
    # 确保关键包被下载
    local critical_packages=("curl" "python3" "systemd")
    for pkg in "${critical_packages[@]}"; do
        if ! ls "$DEPS_DIR/rpms" | grep -q "^$pkg-"; then
            log_warn "关键包 $pkg 未下载到，尝试单独下载..."
            if command -v dnf &> /dev/null; then
                dnf download --destdir="$DEPS_DIR/rpms" "$pkg" || true
            else
                yumdownloader --destdir="$DEPS_DIR/rpms" "$pkg" || true
            fi
        fi
    done
    
    log_info "RPM包下载完成"
    log_info "下载的包数量: $(ls -1 "$DEPS_DIR/rpms" | wc -l)"
}

# 下载Python依赖
download_python_deps() {
    log_step "下载Python依赖..."
    
    # 创建requirements文件
    cat > "$DEPS_DIR/python/requirements.txt" << EOF
# 基础Python包
setuptools>=45.0.0
pip>=21.0.0
wheel>=0.36.0
EOF

    # 下载Python包
    if command -v pip3 &> /dev/null; then
        log_info "下载Python包到本地..."
        pip3 download -r "$DEPS_DIR/python/requirements.txt" -d "$DEPS_DIR/python"
        log_info "Python包下载完成"
    else
        log_warn "pip3不可用，跳过Python依赖下载"
    fi
}

# 创建安装脚本
create_install_script() {
    log_step "创建离线安装脚本..."
    
    cat > "$DEPS_DIR/offline-install.sh" << 'EOF'
#!/bin/bash

# 离线安装脚本
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

# 安装RPM包
install_rpms() {
    log_step "安装RPM包..."
    
    if [ ! -d "rpms" ] || [ -z "$(ls -A rpms)" ]; then
        log_error "RPM包目录为空"
        return 1
    fi
    
    # 安装所有RPM包
    rpm -Uvh rpms/*.rpm --nodeps --force 2>/dev/null || {
        log_warn "部分RPM包安装失败，尝试逐个安装..."
        for rpm in rpms/*.rpm; do
            if [ -f "$rpm" ]; then
                log_info "安装: $(basename "$rpm")"
                rpm -Uvh "$rpm" --nodeps --force || log_warn "安装失败: $(basename "$rpm")"
            fi
        done
    }
    
    log_info "RPM包安装完成"
}

# 安装Python依赖
install_python_deps() {
    log_step "安装Python依赖..."
    
    if [ ! -d "python" ] || [ -z "$(ls -A python)" ]; then
        log_warn "Python依赖目录为空，跳过Python依赖安装"
        return 0
    fi
    
    if command -v pip3 &> /dev/null; then
        log_info "安装Python包..."
        pip3 install --no-index --find-links=python -r python/requirements.txt || log_warn "Python包安装失败"
    else
        log_warn "pip3不可用，跳过Python依赖安装"
    fi
}

# 主函数
main() {
    log_info "开始离线安装..."
    
    install_rpms
    install_python_deps
    
    log_info "离线安装完成"
}

main "$@"
EOF

    chmod +x "$DEPS_DIR/offline-install.sh"
    log_info "离线安装脚本创建完成"
}

# 创建打包脚本
create_package_script() {
    log_step "创建打包脚本..."
    
    cat > "$DEPS_DIR/create-package.sh" << 'EOF'
#!/bin/bash

# 创建依赖包
PACKAGE_NAME="apk-downloader-deps.tar.gz"

log_info "创建依赖包..."
tar -czf "$PACKAGE_NAME" rpms/ python/ offline-install.sh

log_info "依赖包创建完成: $PACKAGE_NAME"
log_info "包大小: $(du -h "$PACKAGE_NAME" | cut -f1)"
EOF

    chmod +x "$DEPS_DIR/create-package.sh"
}

# 生成安装说明
create_readme() {
    log_step "生成安装说明..."
    
    cat > "$DEPS_DIR/README.md" << EOF
# APK自动下载服务 - 离线依赖包

## 使用方法

### 1. 上传到目标服务器
将此整个文件夹上传到CentOS服务器的任意目录

### 2. 解压并安装
\`\`\`bash
# 进入目录
cd offline-deps

# 运行离线安装
sudo ./offline-install.sh
\`\`\`

### 3. 安装主程序
\`\`\`bash
# 下载并运行主安装脚本
curl -fsSL https://raw.githubusercontent.com/Gundamx682/fantastic/main/install.sh | sudo bash
\`\`\`

## 包含的依赖

### RPM包
- curl: 网络请求工具
- wget: 文件下载工具  
- jq: JSON处理工具
- python3: Python运行环境
- python3-pip: Python包管理器
- systemd: 系统服务管理
- firewalld: 防火墙管理

### Python包
- setuptools: Python包构建工具
- pip: Python包管理器
- wheel: Python包构建工具

## 注意事项

- 适用于CentOS 7/8/9系统
- 安装过程会跳过依赖检查，确保系统兼容性
- 如遇到问题，请检查系统版本和架构

## 创建时间
$(date)
EOF

    log_info "安装说明创建完成"
}

# 主函数
main() {
    log_info "开始下载依赖包..."
    
    check_system
    create_directories
    download_rpms
    download_python_deps
    create_install_script
    create_package_script
    create_readme
    
    log_step "依赖下载完成！"
    log_info "目录: $DEPS_DIR"
    log_info "下一步: 运行 ./create-package.sh 创建压缩包"
    log_info "然后上传到您的GitHub仓库"
    
    # 显示下载的文件
    echo ""
    log_info "下载的文件列表:"
    ls -la "$DEPS_DIR/rpms/" | head -10
    if [ $(ls "$DEPS_DIR/rpms" | wc -l) -gt 10 ]; then
        log_info "... 还有 $(($(ls "$DEPS_DIR/rpms" | wc -l) - 10)) 个文件"
    fi
}

main "$@"