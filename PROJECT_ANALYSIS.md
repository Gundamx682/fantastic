# APK自动下载服务 - 项目分析与部署指南

## 📋 项目概述

本项目是一个完整的APK自动下载服务系统，用于监控GitHub仓库的最新release并自动提供APK下载服务。

### 核心功能
- ✅ 每10分钟自动检查GitHub仓库更新
- ✅ 自动下载最新的APK文件
- ✅ 自动清理旧版本APK（保留最新版本）
- ✅ 提供HTTP服务，支持直接下载
- ✅ systemd服务管理，支持开机自启
- ✅ 详细的日志记录

## 📁 项目结构

```
fantastic/
├── apk-downloader.sh       # APK下载主脚本（Bash）
├── apk-server.py           # HTTP服务器（Python）
├── apk-downloader.service  # 下载服务配置（systemd）
├── apk-server.service      # HTTP服务配置（systemd）
├── config.json             # 配置文件
├── install.sh              # 本地安装脚本
├── deploy.sh               # 快速部署脚本
├── online-install.sh       # 在线一键安装脚本 ⭐
├── README.md               # 项目说明文档
└── PROJECT_ANALYSIS.md     # 本文档
```

## 🔧 核心组件分析

### 1. apk-downloader.sh
**功能**：
- 监控GitHub仓库的最新release
- 使用GitHub API获取release信息
- 下载APK文件到指定目录
- 自动清理旧版本APK

**关键配置**：
```bash
REPO_OWNER="z0brk"                    # GitHub仓库所有者
REPO_NAME="netamade-releases"         # GitHub仓库名
APK_DIR="/var/www/apk-downloads"     # APK存储目录
CHECK_INTERVAL=600                     # 检查间隔（秒，10分钟）
SERVER_IP="45.130.146.21"             # 服务器IP
SERVER_PORT=8080                      # HTTP服务端口
```

### 2. apk-server.py
**功能**：
- 提供HTTP服务
- 提供 `/xiazai` 端点直接下载最新APK
- 提供主页显示APK信息
- 支持文件信息查询

**端点**：
- `/` - 主页，显示APK信息
- `/xiazai` - 直接下载最新APK

### 3. systemd服务配置
**apk-downloader.service**：
- 以systemd服务运行下载脚本
- 支持自动重启
- 配置资源限制和安全设置

**apk-server.service**：
- 运行Python HTTP服务器
- 监听0.0.0.0:8080
- 支持绑定80端口权限

## 🚀 部署方案

### 方案一：一键在线安装（推荐）

使用 `online-install.sh` 脚本，只需一行命令：

```bash
# 从GitHub直接下载并执行
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/fantastic/main/online-install.sh | sudo bash

# 或者先下载再执行
wget https://raw.githubusercontent.com/YOUR_USERNAME/fantastic/main/online-install.sh
chmod +x online-install.sh
sudo ./online-install.sh install
```

**特点**：
- ✅ 完全自动化的安装流程
- ✅ 自动检测和安装依赖
- ✅ 自动配置防火墙和SELinux
- ✅ 自动启动服务
- ✅ 完整的安装验证

### 方案二：使用deploy.sh

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/fantastic/main/deploy.sh | sudo bash
```

### 方案三：本地安装

1. 克隆项目
```bash
git clone https://github.com/YOUR_USERNAME/fantastic.git
cd fantastic
```

2. 运行安装脚本
```bash
sudo ./install.sh install
```

## ⚙️ 部署前准备

### 1. 创建GitHub仓库

在 https://github.com/ 上创建新仓库：
- 仓库名：`fantastic`
- 公开/私有：根据需求选择
- 初始化：可以添加README和.gitignore

### 2. 配置文件修改

#### 修改 online-install.sh

找到并修改以下配置：
```bash
REPO_OWNER="YOUR_USERNAME"  # 替换为你的GitHub用户名
REPO_NAME="fantastic"       # 替换为你的仓库名
```

#### 修改 apk-downloader.sh（如需监控其他仓库）

```bash
REPO_OWNER="z0brk"                    # 监控的GitHub仓库所有者
REPO_NAME="netamade-releases"         # 监控的GitHub仓库名
```

#### 修改 apk-server.py

```python
# 第215-220行
server_address = ('0.0.0.0', 8080)
logging.info(f"APK下载服务器启动")
logging.info(f"直接下载地址: http://45.130.146.21:8080/xiazai")
logging.info(f"主页地址: http://45.130.146.21:8080")
```

#### 修改 config.json

```json
{
  "server": {
    "ip": "45.130.146.21",
    "port": 8080,
    "bind_address": "0.0.0.0"
  }
}
```

### 3. 服务器要求

**系统要求**：
- CentOS 7/8/9 或 RHEL 7/8/9
- Root权限
- 至少1GB可用磁盘空间
- 可访问GitHub

**网络要求**：
- 可访问GitHub API（如需使用GitHub Token）
- 8080端口对外开放

**安全要求**：
- 开放8080端口防火墙规则
- 考虑配置SELinux

## 📦 部署步骤

### 步骤1：上传文件到GitHub

```bash
# 1. 初始化git仓库（如果还没有）
cd /path/to/fantastic
git init

# 2. 添加所有文件
git add .

# 3. 提交
git commit -m "Initial commit: APK auto downloader service"

# 4. 添加远程仓库
git remote add origin https://github.com/YOUR_USERNAME/fantastic.git

# 5. 推送到GitHub
git branch -M main
git push -u origin main
```

### 步骤2：在服务器上安装

```bash
# 一键安装命令
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/fantastic/main/online-install.sh | sudo bash
```

### 步骤3：验证安装

```bash
# 检查服务状态
systemctl status apk-downloader apk-server

# 检查端口监听
netstat -tuln | grep 8080

# 访问测试
curl -I http://45.130.146.21:8080
curl -I http://45.130.146.21:8080/xiazai
```

## 🔍 安装验证清单

- [ ] 两个服务都正常运行
- [ ] 端口8080正在监听
- [ ] 可以访问主页 http://45.130.146.21:8080
- [ ] 可以访问下载地址 http://45.130.146.21:8080/xiazai
- [ ] APK目录已创建 /var/www/apk-downloads
- [ ] 日志文件正常写入
- [ ] 服务设置为开机自启

## 🛠️ 服务管理

### 基本命令

```bash
# 查看服务状态
systemctl status apk-downloader apk-server

# 启动服务
systemctl start apk-downloader apk-server

# 停止服务
systemctl stop apk-downloader apk-server

# 重启服务
systemctl restart apk-downloader apk-server

# 启用开机自启
systemctl enable apk-downloader apk-server

# 禁用开机自启
systemctl disable apk-downloader apk-server
```

### 日志查看

```bash
# 查看下载服务日志
journalctl -u apk-downloader -f

# 查看HTTP服务日志
journalctl -u apk-server -f

# 查看所有日志
journalctl -u apk-downloader -u apk-server -f

# 查看最近的日志
journalctl -u apk-downloader --since "1 hour ago"
```

### 卸载服务

```bash
# 使用安装脚本卸载
sudo ./online-install.sh uninstall

# 或手动卸载
systemctl stop apk-downloader apk-server
systemctl disable apk-downloader apk-server
rm /etc/systemd/system/apk-downloader.service
rm /etc/systemd/system/apk-server.service
systemctl daemon-reload
rm -rf /opt/apk-downloader
```

## 📊 工作原理

### 1. APK下载流程

```
启动服务
    ↓
每10分钟检查一次
    ↓
调用GitHub API获取最新release
    ↓
检查版本号是否更新
    ↓
    是 → 下载新APK → 删除旧APK → 更新版本记录
    否  → 继续等待
    ↓
循环
```

### 2. HTTP服务流程

```
接收请求
    ↓
    /      → 返回主页（显示APK信息）
    /xiazai → 返回最新APK文件
    其他    → 返回404
```

## 🔒 安全建议

### 1. 防火墙配置

```bash
# 只允许特定IP访问（可选）
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="YOUR_IP" port port="8080" protocol="tcp" accept'
firewall-cmd --reload
```

### 2. 配置SELinux

```bash
# 临时设置SELinux为Permissive模式
setenforce 0

# 永久禁用（编辑/etc/selinux/config）
SELINUX=disabled
```

### 3. 文件权限

```bash
# 设置APK目录权限
chmod 755 /var/www/apk-downloads
chmod 644 /var/www/apk-downloads/*.apk
```

### 4. 使用GitHub Token（可选）

如果遇到GitHub API限流，可以配置GitHub Token：

```bash
# 在apk-downloader.sh中修改
curl -H "Authorization: token YOUR_GITHUB_TOKEN" -s "$api_url"
```

## 🐛 故障排除

### 问题1：服务启动失败

**症状**：
```bash
systemctl status apk-downloader
# 显示：failed
```

**解决方案**：
```bash
# 查看详细日志
journalctl -u apk-downloader --no-pager -l

# 检查文件权限
ls -la /opt/apk-downloader/
chmod +x /opt/apk-downloader/apk-downloader.sh
```

### 问题2：无法访问GitHub

**症状**：
```
错误: 无法获取GitHub API响应
```

**解决方案**：
```bash
# 测试网络连接
curl -I https://api.github.com

# 检查DNS
ping github.com

# 使用代理（如果需要）
export https_proxy=http://proxy.example.com:port
```

### 问题3：端口无法访问

**症状**：
```bash
netstat -tuln | grep 8080
# 没有输出
```

**解决方案**：
```bash
# 检查防火墙
firewall-cmd --list-ports
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

# 检查SELinux
getenforce

# 重启服务
systemctl restart apk-server
```

### 问题4：APK下载失败

**症状**：
```
错误: 下载失败 xxx.apk
```

**解决方案**：
```bash
# 检查磁盘空间
df -h

# 检查目录权限
ls -la /var/www/apk-downloads/

# 手动触发下载
systemctl restart apk-downloader

# 查看日志
journalctl -u apk-downloader -f
```

## 📈 性能优化

### 1. 调整检查间隔

修改 `apk-downloader.sh`：
```bash
CHECK_INTERVAL=300  # 改为5分钟
```

### 2. 限制资源使用

systemd服务文件中已配置：
```ini
LimitNOFILE=65536
LimitNPROC=4096
```

### 3. 优化日志大小

修改systemd服务配置，添加日志轮转：
```ini
LogRateLimitIntervalSec=30s
LogRateLimitBurst=10
```

## 📝 使用示例

### 1. 下载最新APK

```bash
# 命令行下载
curl -L http://45.130.146.21:8080/xiazai -o app.apk

# 使用wget
wget http://45.130.146.21:8080/xiazai -O app.apk
```

### 2. 集成到脚本

```bash
#!/bin/bash
# 自动获取最新APK
APK_URL="http://45.130.146.21:8080/xiazai"
curl -L "$APK_URL" -o /path/to/save/app.apk
echo "APK下载完成"
```

### 3. 定时任务

```bash
# 添加到crontab（每半小时检查一次服务状态）
*/30 * * * * /usr/bin/systemctl is-active apk-downloader || /usr/bin/systemctl start apk-downloader
```

## 🔗 相关链接

- **监控仓库**: https://github.com/z0brk/netamade-releases
- **程序仓库**: https://github.com/YOUR_USERNAME/fantastic
- **下载地址**: http://45.130.146.21:8080/xiazai

## 📞 支持

如有问题，请：
1. 查看日志：`journalctl -u apk-downloader -f`
2. 查看项目文档：README.md
3. 提交Issue到GitHub仓库

## 📄 许可证

MIT License

---

**最后更新**: 2025-12-28
**版本**: 1.0.0
