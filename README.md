# APK自动下载服务

一个用于自动监控GitHub仓库最新release并提供直接APK下载的CentOS服务系统。

## 🚀 功能特性

- **自动监控**: 每10分钟检查 z0brk/netamade-releases 仓库的最新release
- **智能下载**: 自动识别并下载APK文件，删除旧版本
- **直接下载**: 提供 `/xiazai` 端点直接下载最新APK
- **系统服务**: 以systemd服务形式运行，支持自启动和重启
- **日志记录**: 详细的操作日志，便于问题排查

## 📋 系统要求

- **操作系统**: CentOS 7/8/9 或 RHEL 7/8/9
- **权限**: root权限
- **网络**: 可访问GitHub API和下载文件
- **端口**: 8080（HTTP服务端口）

## 🛠️ 快速安装

### 一键安装

```bash
# 下载并执行安装脚本
curl -fsSL https://raw.githubusercontent.com/Gundamx682/fantastic/main/install.sh | sudo bash

# 或者
curl -L -o install.sh https://raw.githubusercontent.com/Gundamx682/fantastic/main/install.sh
chmod +x install.sh
sudo ./install.sh install
```

### 快速部署

```bash
# 从GitHub直接部署
curl -fsSL https://raw.githubusercontent.com/Gundamx682/fantastic/main/deploy.sh | sudo bash
```

## 🌐 访问服务

安装完成后，可以通过以下方式访问：

- **主页**: http://45.130.146.21:8080
- **直接下载**: http://45.130.146.21:8080/xiazai ⭐

## ⬇️ 下载方式

### 方法1: 浏览器直接下载
访问 `http://45.130.146.21:8080/xiazai` 即可自动下载最新版本的APK

### 方法2: 命令行下载
```bash
curl -L http://45.130.146.21:8080/xiazai -o latest.apk
wget http://45.130.146.21:8080/xiazai -O fantastic.apk
```

### 方法3: 移动端下载
在手机浏览器中打开 `http://45.130.146.21:8080/xiazai` 即可

## 📁 目录结构

```
/opt/apk-downloader/          # 安装目录
├── apk-downloader.sh         # 主下载脚本
├── apk-server.py            # HTTP服务器
├── apk-downloader.service   # systemd服务配置
├── apk-server.service       # HTTP服务器配置
└── config.json              # 配置文件

/var/www/apk-downloads/      # APK文件存储目录
/var/log/                    # 日志文件目录
├── apk-downloader.log       # 下载服务日志
└── apk-server.log          # HTTP服务器日志
```

## ⚙️ 配置说明

### 下载脚本配置 (apk-downloader.sh)

主要配置参数：

```bash
REPO_OWNER="z0brk"                     # 监控的GitHub仓库所有者
REPO_NAME="netamade-releases"          # 监控的GitHub仓库名称
APK_DIR="/var/www/apk-downloads"      # APK存储目录
CHECK_INTERVAL=600                    # 检查间隔（秒）
SERVER_IP="45.130.146.21"            # 服务器IP
SERVER_PORT=8080                      # HTTP服务端口
```

### HTTP服务器配置 (apk-server.py)

- **监听地址**: 0.0.0.0:8080
- **静态文件目录**: /var/www/apk-downloads
- **端点**:
  - `/`: 简单主页
  - `/xiazai`: 直接下载最新APK

## 🔧 服务管理

### 基本命令

```bash
# 查看服务状态
systemctl status apk-downloader apk-server

# 重启服务
systemctl restart apk-downloader apk-server

# 停止服务
systemctl stop apk-downloader apk-server

# 启用开机自启
systemctl enable apk-downloader apk-server

# 禁用开机自启
systemctl disable apk-downloader apk-server
```

### 日志查看

```bash
# 实时查看下载服务日志
journalctl -u apk-downloader -f

# 实时查看HTTP服务日志
journalctl -u apk-server -f

# 查看文件日志
tail -f /var/log/apk-downloader.log
tail -f /var/log/apk-server.log
```

### 卸载服务

```bash
# 使用安装脚本卸载
./install.sh uninstall

# 手动卸载
systemctl stop apk-downloader apk-server
systemctl disable apk-downloader apk-server
rm /etc/systemd/system/apk-downloader.service
rm /etc/systemd/system/apk-server.service
systemctl daemon-reload
rm -rf /opt/apk-downloader
```

## 🔍 故障排除

### 常见问题

1. **访问 /xiazai 没有反应**
   ```bash
   # 检查服务状态
   systemctl status apk-server
   
   # 查看日志
   journalctl -u apk-server --since "1 hour ago"
   
   # 检查APK文件是否存在
   ls -la /var/www/apk-downloads/
   ```

2. **没有下载到APK文件**
   ```bash
   # 查看下载服务日志
   journalctl -u apk-downloader --since "1 hour ago"
   
   # 手动触发一次检查
   systemctl restart apk-downloader
   ```

3. **无法访问GitHub API**
   ```bash
   # 测试网络连接
   curl -I https://api.github.com/repos/Gundamx682/fantastic/releases/latest
   ```

### 日志分析

关键日志信息：

- `[INFO] 正在获取最新release信息...`
- `[INFO] 发现新版本: v1.2.3`
- `[INFO] 成功下载: fantastic-v1.2.3.apk`
- `[INFO] APK下载: fantastic-v1.2.3.apk (24.0 MB)`

## 📊 使用示例

### 日常使用

1. **用户下载APK**：
   - 发送链接：`http://45.130.146.21:8080/xiazai`
   - 用户点击即可下载最新版本

2. **开发者检查状态**：
   ```bash
   # 检查服务运行状态
   curl -I http://45.130.146.21:8080/xiazai
   
   # 查看最新APK信息
   ls -la /var/www/apk-downloads/*.apk
   ```

3. **自动化集成**：
   ```bash
   # 在脚本中自动获取最新APK
   #!/bin/bash
   curl -L http://45.130.146.21:8080/xiazai -o app.apk
   echo "下载完成"
   ```

## 🔒 安全考虑

1. **防火墙配置**: 只开放必要的端口（8080）
2. **文件权限**: APK文件设置为644权限
3. **服务隔离**: 使用systemd的隔离功能
4. **访问控制**: 可根据需要配置IP白名单

## 📈 性能优化

1. **智能缓存**: 避免重复下载相同版本
2. **自动清理**: 保留最新版本，删除旧文件
3. **资源限制**: 限制CPU和内存使用
4. **并发控制**: 合理控制下载并发数

## 🤝 贡献指南

1. Fork项目
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

## 📄 许可证

MIT License

## 📞 支持

如有问题，请提交Issue或联系维护者。

---

**🎯 监控仓库**: https://github.com/z0brk/netamade-releases (APK来源)

**📦 程序仓库**: https://github.com/Gundamx682/fantastic (本程序)

**⚡ 快速下载**: http://45.130.146.21:8080/xiazai

**注意**: 请确保服务器有足够的磁盘空间存储APK文件，建议至少保留10GB可用空间。