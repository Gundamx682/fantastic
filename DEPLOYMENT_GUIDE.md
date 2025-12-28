# 🚀 快速部署指南

## 📋 部署清单

在开始部署前，请确认以下事项：

- [ ] 已有GitHub账号
- [ ] 准备好要使用的仓库名（如：fantastic）
- [ ] CentOS服务器IP：45.130.146.21
- [ ] 服务器root权限
- [ ] 服务器可访问GitHub

---

## 步骤1: 准备GitHub仓库

### 1.1 创建新仓库

1. 访问 https://github.com/new
2. 设置仓库名：`fantastic`（或你喜欢的名字）
3. 设置为公开（Public）或私有（Private）
4. 不要初始化README（我们会自己上传）
5. 点击 "Create repository"

### 1.2 记录你的仓库信息

```
GitHub用户名: YOUR_USERNAME
仓库名: fantastic
仓库URL: https://github.com/YOUR_USERNAME/fantastic
```

---

## 步骤2: 配置项目文件

### 2.1 修改 online-install.sh

编辑 `online-install.sh` 文件，修改以下配置：

```bash
# 第23-24行
REPO_OWNER="YOUR_USERNAME"  # 替换为你的GitHub用户名
REPO_NAME="fantastic"       # 替换为你的仓库名
```

### 2.2 修改 README_GITHUB.md

替换文件中所有的 `YOUR_USERNAME` 为你的实际GitHub用户名。

可以使用查找替换功能：
- 查找：`YOUR_USERNAME`
- 替换：`your_actual_username`

### 2.3 可选：修改监控目标

如果想监控其他仓库，编辑 `apk-downloader.sh` 第7-8行：

```bash
REPO_OWNER="z0brk"                    # 改为你要监控的仓库所有者
REPO_NAME="netamade-releases"         # 改为你要监控的仓库名
```

---

## 步骤3: 上传到GitHub

### 3.1 在本地终端执行

```bash
# 进入项目目录
cd c:/Users/Administrator/333ff/fantastic

# 初始化git仓库（如果还没有）
git init

# 添加所有文件
git add .

# 提交
git commit -m "Initial commit: APK auto downloader service"

# 添加远程仓库（替换YOUR_USERNAME）
git remote add origin https://github.com/YOUR_USERNAME/fantastic.git

# 推送到GitHub
git branch -M main
git push -u origin main
```

### 3.2 验证上传

访问你的GitHub仓库页面，确认所有文件都已上传成功。

应该包含以下关键文件：
- ✅ online-install.sh
- ✅ apk-downloader.sh
- ✅ apk-server.py
- ✅ apk-downloader.service
- ✅ apk-server.service
- ✅ config.json
- ✅ README_GITHUB.md

---

## 步骤4: 在服务器上安装

### 4.1 登录到服务器

```bash
ssh root@45.130.146.21
```

### 4.2 执行一键安装

```bash
# 替换YOUR_USERNAME为你的实际GitHub用户名
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/fantastic/main/online-install.sh | sudo bash
```

### 4.3 等待安装完成

安装过程会自动完成以下步骤：
1. ✅ 检查系统和权限
2. ✅ 检查网络连接
3. ✅ 安装必要的依赖（curl, python3, jq等）
4. ✅ 创建目录结构
5. ✅ 下载并部署所有文件
6. ✅ 配置防火墙
7. ✅ 配置SELinux
8. ✅ 配置systemd服务
9. ✅ 启动服务
10. ✅ 验证安装

### 4.4 验证安装

```bash
# 检查服务状态
systemctl status apk-downloader apk-server

# 检查端口
netstat -tuln | grep 8080

# 查看日志
journalctl -u apk-downloader -f
# 按Ctrl+C退出
```

---

## 步骤5: 测试服务

### 5.1 在服务器上测试

```bash
# 测试主页
curl http://45.130.146.21:8080

# 测试下载
curl -I http://45.130.146.21:8080/xiazai
```

### 5.2 在浏览器中测试

1. 在浏览器中访问：`http://45.130.146.21:8080`
2. 应该看到APK下载页面
3. 点击 "立即下载" 按钮或访问：`http://45.130.146.21:8080/xiazai`

### 5.3 检查APK文件

```bash
# 查看APK目录
ls -la /var/www/apk-downloads/

# 应该看到APK文件
```

---

## 步骤6: 配置防火墙（如需要）

如果无法从外网访问，可能需要配置防火墙：

```bash
# 开放8080端口
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

# 验证
firewall-cmd --list-ports
```

---

## 📊 部署成功标志

部署成功后，你应该能看到：

✅ 两个systemd服务都正常运行
✅ 端口8080正在监听
✅ 可以访问 http://45.130.146.21:8080
✅ 可以下载 http://45.130.146.21:8080/xiazai
✅ APK目录中有文件（或正在下载）
✅ 日志正常输出

---

## 🔧 常用命令

安装完成后，这些命令会很有用：

```bash
# 查看服务状态
systemctl status apk-downloader apk-server

# 重启服务
systemctl restart apk-downloader apk-server

# 查看实时日志
journalctl -u apk-downloader -f
journalctl -u apk-server -f

# 下载最新APK
curl -L http://45.130.146.21:8080/xiazai -o latest.apk

# 卸载服务
sudo ./online-install.sh uninstall
```

---

## 🐛 常见问题

### Q1: 安装失败，提示权限错误

**A**: 确保使用root权限或sudo运行：
```bash
sudo bash online-install.sh
```

### Q2: 无法访问GitHub下载文件

**A**:
1. 检查网络连接：`ping github.com`
2. 检查DNS配置
3. 尝试使用代理（如果需要）

### Q3: 服务启动失败

**A**:
```bash
# 查看详细日志
journalctl -u apk-downloader --no-pager -l
journalctl -u apk-server --no-pager -l

# 检查文件权限
ls -la /opt/apk-downloader/
```

### Q4: 无法从外网访问

**A**:
1. 检查防火墙：`firewall-cmd --list-ports`
2. 检查SELinux：`getenforce`
3. 检查云服务器安全组规则

### Q5: 没有下载到APK文件

**A**:
```bash
# 查看下载日志
journalctl -u apk-downloader -f

# 手动触发下载
systemctl restart apk-downloader

# 等待几分钟后检查
ls -la /var/www/apk-downloads/
```

---

## 📱 给用户的下载说明

部署成功后，可以告诉用户这样下载：

**方法1 - 浏览器下载**：
```
直接访问：http://45.130.146.21:8080/xiazai
```

**方法2 - 命令行下载**：
```bash
curl -L http://45.130.146.21:8080/xiazai -o app.apk
```

**方法3 - 二维码**：
可以用二维码生成工具将下载地址生成二维码，用户扫码即可下载。

---

## 🎯 下一步

部署完成后，你可以：

1. **配置监控其他仓库** - 修改 `apk-downloader.sh` 中的仓库配置
2. **调整检查频率** - 修改 `CHECK_INTERVAL` 参数
3. **配置访问控制** - 在防火墙中配置IP白名单
4. **监控服务状态** - 使用 `journalctl -u apk-downloader -f` 查看日志
5. **分享给用户** - 将下载地址 `http://45.130.146.21:8080/xiazai` 分享给用户

---

## 📚 更多文档

- **详细分析**: 查看 `PROJECT_ANALYSIS.md` 了解更多技术细节
- **原版README**: 查看 `README.md` 了解完整功能说明
- **GitHub版README**: 将 `README_GITHUB.md` 内容复制到GitHub仓库首页

---

## 🆘 获取帮助

如果遇到问题：

1. 查看日志：`journalctl -u apk-downloader -f`
2. 查看文档：`PROJECT_ANALYSIS.md`
3. 检查服务状态：`systemctl status apk-downloader apk-server`

---

**祝你部署顺利！** 🎉

---

*最后更新: 2025-12-28*
