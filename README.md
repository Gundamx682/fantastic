# APK自动下载服务

一个用于自动监控GitHub仓库最新release并下载APK文件的CentOS服务系统。

## 🚀 功能特性

- **自动监控**: 每10分钟检查一次GitHub仓库的最新release
- **智能下载**: 自动识别并下载APK文件，删除旧版本
- **HTTP服务**: 提供Web界面和API接口供用户下载APK
- **版本管理**: 保留最新版本的APK文件，自动清理旧文件
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
# 下载所有文件到服务器
curl -L -o install.sh https://raw.githubusercontent.com/your-repo/apk-downloader/main/install.sh
chmod +x install.sh

# 执行安装
sudo ./install.sh install
```

### 手动安装

1. **下载脚本文件**
   ```bash
   mkdir -p /opt/apk-downloader
   cd /opt/apk-downloader
   
   # 下载所有必需文件
   wget https://raw.githubusercontent.com/your-repo/apk-downloader/main/apk-downloader.sh
   wget https://raw.githubusercontent.com/your-repo/apk-downloader/main/apk-server.py
   wget https://raw.githubusercontent.com/your-repo/apk-downloader/main/apk-downloader.service
   wget https://raw.githubusercontent.com/your-repo/apk-downloader/main/apk-server.service
   ```

2. **设置权限**
   ```bash
   chmod +x apk-downloader.sh
   chmod +x apk-server.py
   ```

3. **安装系统依赖**
   ```bash
   yum update -y
   yum install -y curl wget jq python3 python3-pip systemd firewalld
   ```

4. **部署服务文件**
   ```bash
   cp apk-downloader.service /etc/systemd/system/
   cp apk-server.service /etc/systemd/system/
   systemctl daemon-reload
   ```

5. **配置防火墙**
   ```bash
   systemctl enable firewalld
   systemctl start firewalld
   firewall-cmd --permanent --add-port=8080/tcp
   firewall-cmd --reload
   ```

6. **启动服务**
   ```bash
   systemctl enable apk-downloader apk-server
   systemctl start apk-downloader apk-server
   ```

## 🌐 访问服务

安装完成后，可以通过以下方式访问：

- **Web界面**: http://45.130.146.21:8080
- **状态API**: http://45.130.146.21:8080/api/status
- **APK列表API**: http://45.130.146.21:8080/api/list

## 📁 目录结构

```
/opt/apk-downloader/          # 安装目录
├── apk-downloader.sh         # 主下载脚本
├── apk-server.py            # HTTP服务器
├── apk-downloader.service   # systemd服务配置
└── apk-server.service       # HTTP服务器配置

/var/www/apk-downloads/      # APK文件存储目录
/var/log/                    # 日志文件目录
├── apk-downloader.log       # 下载服务日志
└── apk-server.log          # HTTP服务器日志
```

## ⚙️ 配置说明

### 下载脚本配置 (apk-downloader.sh)

主要配置参数：

```bash
REPO_OWNER="z0brk"                    # GitHub仓库所有者
REPO_NAME="netamade-releases"         # GitHub仓库名称
APK_DIR="/var/www/apk-downloads"      # APK存储目录
CHECK_INTERVAL=600                    # 检查间隔（秒）
SERVER_IP="45.130.146.21"            # 服务器IP
SERVER_PORT=8080                      # HTTP服务端口
```

### HTTP服务器配置 (apk-server.py)

- **监听地址**: 0.0.0.0:8080
- **静态文件目录**: /var/www/apk-downloads
- **API端点**:
  - `/`: Web主页
  - `/api/status`: 服务状态
  - `/api/list`: APK文件列表
  - `/*.apk`: APK文件下载

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

# 查看最近的日志
journalctl -u apk-downloader --since "1 hour ago"
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

## 📊 API接口

### 状态查询

```bash
curl http://45.130.146.21:8080/api/status
```

响应示例：
```json
{
  "status": "running",
  "timestamp": "2024-01-01T12:00:00",
  "server_ip": "45.130.146.21",
  "server_port": 8080,
  "apk_count": 3
}
```

### APK列表

```bash
curl http://45.130.146.21:8080/api/list
```

响应示例：
```json
[
  {
    "name": "app-v1.2.3.apk",
    "size": 25165824,
    "modified": "2024-01-01T12:00:00",
    "download_url": "/app-v1.2.3.apk",
    "size_mb": 24.0
  }
]
```

## 🔍 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查服务状态
   systemctl status apk-downloader apk-server
   
   # 查看详细错误
   journalctl -u apk-downloader --no-pager
   journalctl -u apk-server --no-pager
   ```

2. **无法访问GitHub API**
   ```bash
   # 测试网络连接
   curl -I https://api.github.com
   
   # 检查DNS解析
   nslookup api.github.com
   ```

3. **APK下载失败**
   ```bash
   # 查看下载日志
   tail -f /var/log/apk-downloader.log
   
   # 手动测试下载
   curl -L -o test.apk https://github.com/z0brk/netamade-releases/releases/latest/download/app.apk
   ```

4. **端口被占用**
   ```bash
   # 检查端口占用
   netstat -tuln | grep 8080
   
   # 停止占用进程
   lsof -ti:8080 | xargs kill -9
   ```

### 日志分析

关键日志信息：

- `[INFO] 正在获取最新release信息...`
- `[INFO] 发现新版本: v1.2.3`
- `[INFO] 成功下载: app-v1.2.3.apk`
- `[INFO] HTTP服务器启动成功`

错误信息：

- `[ERROR] 无法获取GitHub API响应` - 网络问题
- `[ERROR] 仓库不存在或没有release` - 仓库配置错误
- `[ERROR] APK下载失败` - 下载链接问题

## 🔒 安全考虑

1. **防火墙配置**: 只开放必要的端口（8080）
2. **文件权限**: APK文件设置为644权限
3. **服务隔离**: 使用systemd的隔离功能
4. **日志轮转**: 配置logrotate防止日志文件过大

## 📈 性能优化

1. **并发下载**: 支持同时下载多个APK文件
2. **断点续传**: 大文件支持断点续传
3. **缓存机制**: 避免重复下载相同版本
4. **资源限制**: 限制CPU和内存使用

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

**注意**: 请确保服务器有足够的磁盘空间存储APK文件，建议至少保留10GB可用空间。