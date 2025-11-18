# Freedom Toolkit

🚀 一套用于突破网络限制的工具集，帮助你在受限网络环境下保持自由访问互联网的能力。

## 📦 工具列表

### OpenWrt PassWall2 Installer

一键安装脚本，用于在 OpenWrt 路由器上快速部署 PassWall2 代理工具。

**支持的协议**：
- ✅ Xray (VMess/VLESS)
- ✅ Hysteria2
- ✅ Shadowsocks
- ✅ Trojan
- ✅ WireGuard
- ✅ sing-box

**适用设备**：
- GL.iNet GL-MT3000 (Beryl AX)
- 其他运行 OpenWrt 24.10+ 的 aarch64_cortex-a53 路由器

---

## 🎯 OpenWrt PassWall2 安装教程

### 系统要求

- OpenWrt 23.05+ 或 24.10+
- 至少 50MB 可用存储空间
- 稳定的网络连接

### 快速安装

#### 方法 1：一键安装（推荐）

```bash
# SSH 连接到路由器
ssh root@192.168.x.x

# 下载并运行安装脚本
wget -O /tmp/installer.sh https://raw.githubusercontent.com/YOUR_USERNAME/freedom-toolkit/main/openwrt-passwall2-installer.sh
chmod +x /tmp/installer.sh
/tmp/installer.sh
```

#### 方法 2：从本地上传

```bash
# 1. 下载脚本到本地
# 2. 上传到路由器
scp openwrt-passwall2-installer.sh root@192.168.x.x:/tmp/

# 3. SSH 连接并执行
ssh root@192.168.x.x
chmod +x /tmp/openwrt-passwall2-installer.sh
/tmp/openwrt-passwall2-installer.sh
```

### 安装内容

脚本将自动完成以下操作：

1. ✅ 检查系统环境（版本、架构、磁盘空间）
2. ✅ 备份现有配置
3. ✅ 安装基础依赖包
4. ✅ 添加 PassWall2 官方软件源
5. ✅ 安装 PassWall2 核心
6. ✅ 安装多协议支持（Xray、Hysteria2、SS、Trojan、WireGuard、sing-box）
7. ✅ 安装辅助工具（chinadns-ng、dns2socks、tcping）
8. ✅ **主题选择安装**（Material、Argon、OpenWrt 2020）
9. ✅ **自动检测端口冲突**（如 80 端口被占用则使用 8080）
10. ✅ **自动应用选择的主题**
11. ✅ 启用并启动服务
12. ✅ 安装中文语言包

### 新增功能

**🎨 主题选择**
- 安装时可选择安装 Material、Argon、OpenWrt 2020 或全部主题
- 自动应用选择的主题
- 稍后可在 LuCI 界面中随时切换

**🔧 端口自动配置**
- 自动检测端口 80 是否被占用
- 如被占用（如 GL.iNet 原厂固件的 nginx），自动配置为 8080
- 确保 LuCI 界面可正常访问

**📱 完整的中文支持**
- 自动安装 PassWall2 中文语言包
- 确保界面完全汉化

### 配置 PassWall2

安装完成后：

1. 访问路由器管理界面：`http://192.168.x.x`
2. 进入：**服务** → **PassWall2**
3. 添加节点：
   - 点击 **节点列表** → **添加**
   - 选择协议类型
   - 填入服务器配置信息
4. 配置分流规则（可选）：
   - 国内直连
   - 国外代理
   - 自定义规则

---

## 🔧 VPS 服务端部署

### 使用 X-UI 面板（推荐）

X-UI 是一个支持多协议的 Web 管理面板，非常适合快速部署。

```bash
# 连接到你的 VPS
ssh root@your-vps-ip

# 安装 X-UI
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
```

安装完成后：
- 访问：`http://your-vps-ip:54321`
- 默认用户名/密码：`admin/admin`
- 在 Web 界面添加入站配置（Xray、Hysteria2、WireGuard 等）

### 快速部署

```bash
# 连接到你的 VPS
ssh root@your-vps-ip

# 下载并运行安装脚本
wget -O /tmp/installer.sh https://raw.githubusercontent.com/YOUR_USERNAME/freedom-toolkit/main/vps-xui-installer.sh
chmod +x /tmp/installer.sh
/tmp/installer.sh
```

详细教程请参考 [VPS 部署指南](docs/vps-deployment.md)

---

## 📝 使用场景

### 场景 1：出差到网络受限地区

**问题**：即将前往中国等网络受限地区，担心无法访问常用服务。

**解决方案**：
1. 在出发前，在日本/香港等地的 VPS 上部署多协议服务端
2. 在路由器上安装 PassWall2 并配置多个节点
3. 在手机上安装 Shadowrocket/Clash 作为备用
4. 启用路由器远程管理（GoodCloud）

**优势**：
- ✅ 路由器全局代理，所有设备自动科学上网
- ✅ 多协议备份，一个不行切换另一个
- ✅ 手机热点应急
- ✅ 远程管理，随时调整配置

### 场景 2：企业远程办公

**问题**：需要在受限网络环境下访问公司内部资源。

**解决方案**：
1. 使用 WireGuard 建立安全隧道
2. 配置分流规则：公司域名走 VPN，其他正常访问
3. 路由器层面实现全设备透明代理

---

## ⚠️ 注意事项

### 安全提醒

- 🔒 定期更新服务端和客户端软件
- 🔒 使用强密码保护路由器管理界面
- 🔒 不要在公共场合分享你的节点配置
- 🔒 建议使用自建服务器，避免使用免费节点

### 法律声明

- 本项目仅供学习和研究使用
- 用户需遵守所在地区的法律法规
- 不得用于任何违法违规活动
- 使用本工具产生的任何后果由用户自行承担

### 隐私保护

- 本脚本不会收集任何用户数据
- 不包含任何追踪代码
- 所有操作均在本地完成
- 开源透明，欢迎审计代码

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 贡献指南

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m 'Add some feature'`
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

### 待办事项

- [x] 添加 VPS 服务端一键部署脚本
- [x] 编写详细的 VPS 部署指南
- [ ] 支持更多 OpenWrt 版本和设备
- [ ] 添加自动更新功能
- [ ] 编写详细的故障排查指南
- [ ] 添加可视化配置工具
- [ ] 添加完整的使用教程视频

---

## 📚 相关资源

### 官方文档

- [PassWall2 官网](https://passwall2.org/)
- [OpenWrt 官网](https://openwrt.org/)
- [GL.iNet 官网](https://www.gl-inet.com/)

### 社区支持

- [PassWall2 GitHub](https://github.com/xiaorouji/openwrt-passwall2)
- [OpenWrt 论坛](https://forum.openwrt.org/)

### 协议文档

- [Xray 文档](https://xtls.github.io/)
- [Hysteria2 文档](https://v2.hysteria.network/)
- [WireGuard 文档](https://www.wireguard.com/)
- [Shadowsocks 文档](https://shadowsocks.org/)

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

---

## ⭐ Star History

如果这个项目对你有帮助，欢迎给个 Star ⭐

---

## 💬 联系方式

- 提交 Issue：[GitHub Issues](https://github.com/YOUR_USERNAME/freedom-toolkit/issues)
- 讨论区：[GitHub Discussions](https://github.com/YOUR_USERNAME/freedom-toolkit/discussions)

---

**最后更新**：2025-11-18

**版本**：v1.0.0