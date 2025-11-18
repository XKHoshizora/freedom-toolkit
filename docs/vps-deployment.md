# VPS 服务端部署指南

本指南将帮助你在 VPS 上部署多协议代理服务端，配合 OpenWrt PassWall2 客户端使用。

---

## 📋 目录

- [准备工作](#准备工作)
- [方案 1: X-UI 面板 (推荐)](#方案-1-x-ui-面板-推荐)
- [方案 2: 手动配置单协议](#方案-2-手动配置单协议)
- [配置示例](#配置示例)
- [安全加固](#安全加固)
- [常见问题](#常见问题)

---

## 准备工作

### VPS 要求

**最低配置**:
- CPU: 1 核心
- 内存: 512MB
- 硬盘: 10GB
- 带宽: 100Mbps

**推荐配置**:
- CPU: 2 核心
- 内存: 1GB+
- 硬盘: 20GB+
- 带宽: 1Gbps

### 系统要求

支持的操作系统:
- ✅ Ubuntu 20.04 / 22.04 / 24.04
- ✅ Debian 10 / 11 / 12
- ✅ CentOS 7 / 8 / Stream
- ✅ Rocky Linux 8 / 9
- ✅ AlmaLinux 8 / 9

### VPS 提供商推荐

**日本机房推荐** (适合中国用户):

1. **Vultr Tokyo**
   - 价格: $5/月起
   - 特点: 按小时计费，可随时删除
   - 链接: https://www.vultr.com/

2. **Linode Tokyo**
   - 价格: $5/月起
   - 特点: 稳定性好，老牌厂商
   - 链接: https://www.linode.com/

3. **DigitalOcean Singapore** (距离近)
   - 价格: $6/月起
   - 特点: 界面友好，新手推荐
   - 链接: https://www.digitalocean.com/

4. **Bandwagon (搬瓦工)**
   - 价格: $49.99/年起
   - 特点: CN2 GIA 线路，速度快
   - 链接: https://bandwagonhost.com/

### 域名准备 (可选但推荐)

如果你有域名:
1. 在 Cloudflare / DNSPod 添加 A 记录指向 VPS IP
2. 等待 DNS 生效 (5-10 分钟)
3. 可以使用域名伪装流量

---

## 方案 1: X-UI 面板 (推荐)

X-UI 是一个功能强大的多协议管理面板，支持 Web 界面管理。

### 优势

- ✅ Web 图形界面，操作简单
- ✅ 支持多协议 (Xray, Hysteria2, WireGuard)
- ✅ 流量统计和用户管理
- ✅ 自动申请 SSL 证书
- ✅ 支持订阅链接生成

### 一键安装

```bash
# 1. SSH 连接到 VPS
ssh root@your-vps-ip

# 2. 下载并运行安装脚本
wget -O /tmp/installer.sh https://raw.githubusercontent.com/YOUR_USERNAME/freedom-toolkit/main/vps-xui-installer.sh
chmod +x /tmp/installer.sh
/tmp/installer.sh
```

### 安装过程

脚本会提示你输入以下信息:

1. **管理面板端口** (默认: 54321)
   - 建议使用非标准端口，如 12345

2. **管理员用户名** (默认: admin)
   - 建议使用复杂用户名，如 admin_xxxx

3. **管理员密码**
   - 留空则自动生成强密码
   - 或手动输入 16 位以上强密码

4. **域名配置** (可选)
   - 如果有域名，输入域名
   - 可选择是否启用 SSL

### 安装后配置

#### 1. 访问管理面板

```
http://your-vps-ip:54321
```

使用安装时设置的用户名和密码登录。

#### 2. 添加入站配置

在 X-UI 面板中:

**推荐配置 1: VMess + WebSocket + TLS** (最隐蔽)
- 协议: VMess
- 端口: 443
- 传输: WebSocket
- 路径: /vmess (可自定义)
- TLS: 启用
- 域名: your-domain.com

**推荐配置 2: VLESS + Reality** (最新技术)
- 协议: VLESS
- 端口: 443
- Flow: xtls-rprx-vision
- SNI: www.microsoft.com (或其他可信网站)

**推荐配置 3: Hysteria2** (高性能)
- 协议: Hysteria2
- 端口: 443 或自定义
- 伪装: 启用
- 混淆: 设置密码

**推荐配置 4: Shadowsocks** (简单)
- 协议: SS
- 端口: 自定义 (如 8388)
- 加密: aes-256-gcm
- 密码: 强密码

#### 3. 生成客户端配置

在 X-UI 面板中:
1. 点击入站配置旁的"二维码"图标
2. 复制配置链接
3. 在 OpenWrt PassWall2 中添加节点

### X-UI 常用命令

```bash
# 查看状态
x-ui status

# 启动服务
x-ui start

# 停止服务
x-ui stop

# 重启服务
x-ui restart

# 查看日志
x-ui log

# 更新面板
x-ui update

# 卸载面板
x-ui uninstall
```

---

## 方案 2: 手动配置单协议

如果你只需要单一协议，可以手动配置。

### 2.1 WireGuard 配置

**服务端安装**:

```bash
# Ubuntu/Debian
apt update && apt install wireguard

# CentOS
yum install epel-release
yum install wireguard-tools

# 生成密钥
wg genkey | tee server_private.key | wg pubkey > server_public.key
wg genkey | tee client_private.key | wg pubkey > client_public.key

# 配置 /etc/wireguard/wg0.conf
[Interface]
PrivateKey = <server_private_key>
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <client_public_key>
AllowedIPs = 10.0.0.2/32

# 启动
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

**客户端配置** (OpenWrt):

```
[Interface]
PrivateKey = <client_private_key>
Address = 10.0.0.2/24

[Peer]
PublicKey = <server_public_key>
Endpoint = your-vps-ip:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### 2.2 Hysteria2 配置

**服务端安装**:

```bash
# 一键安装
bash <(curl -fsSL https://get.hy2.sh/)

# 配置 /etc/hysteria/config.yaml
listen: :443

acme:
  domains:
    - your-domain.com
  email: your-email@example.com

auth:
  type: password
  password: your-strong-password

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

# 启动
systemctl enable hysteria-server
systemctl start hysteria-server
```

### 2.3 Xray (VMess/VLESS) 配置

**服务端安装**:

```bash
# 一键安装
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 配置 /usr/local/etc/xray/config.json
{
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "生成的UUID",
        "flow": "xtls-rprx-vision"
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "www.microsoft.com:443",
        "serverNames": ["www.microsoft.com"],
        "privateKey": "生成的私钥"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}

# 启动
systemctl enable xray
systemctl start xray
```

---

## 配置示例

### 多协议组合方案

**推荐组合 1: 稳定为主**
- WireGuard (主力，日常使用)
- VMess + WebSocket + TLS (备用，伪装性好)
- Shadowsocks (应急，轻量)

**推荐组合 2: 性能为主**
- Hysteria2 (主力，高性能)
- VLESS + Reality (备用，最新技术)
- Trojan (应急，简单)

**推荐组合 3: 隐蔽为主**
- VMess + CDN (主力，难以检测)
- Trojan + TLS (备用，伪装 HTTPS)
- WireGuard (应急，简单快速)

### 端口选择建议

| 用途 | 推荐端口 | 说明 |
|------|---------|------|
| HTTPS 伪装 | 443 | 最常见，不易被封 |
| HTTP 伪装 | 80 | 常见但不加密 |
| 自定义 | 8443, 10086 | 避开常见端口 |
| WireGuard | 51820 | 官方默认 |
| 管理面板 | 12345-65535 | 非标准端口 |

---

## 安全加固

### 1. 修改 SSH 端口

```bash
# 编辑 SSH 配置
vim /etc/ssh/sshd_config

# 修改端口
Port 22222  # 改为非标准端口

# 重启 SSH
systemctl restart sshd
```

### 2. 配置密钥登录

```bash
# 在本地生成密钥对
ssh-keygen -t ed25519

# 上传公钥到 VPS
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@your-vps-ip

# 禁用密码登录
vim /etc/ssh/sshd_config
# 设置: PasswordAuthentication no
systemctl restart sshd
```

### 3. 安装 Fail2Ban

```bash
# Ubuntu/Debian
apt install fail2ban

# CentOS
yum install fail2ban

# 启动
systemctl enable fail2ban
systemctl start fail2ban
```

### 4. 配置防火墙

```bash
# UFW (Ubuntu/Debian)
ufw allow 22/tcp        # SSH
ufw allow 443/tcp       # HTTPS/代理
ufw allow 54321/tcp     # X-UI 面板
ufw enable

# Firewalld (CentOS)
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=54321/tcp
firewall-cmd --reload
```

### 5. 启用自动更新

```bash
# Ubuntu/Debian
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# CentOS
yum install yum-cron
systemctl enable yum-cron
systemctl start yum-cron
```

---

## 常见问题

### Q: VPS 被墙怎么办？

**A**: 
1. 更换 IP (部分 VPS 商支持换 IP)
2. 使用 CDN (Cloudflare) 中转
3. 更换协议 (如改用 Reality/Hysteria2)
4. 更换端口和伪装域名

### Q: 速度慢怎么优化？

**A**:
1. 启用 BBR 拥塞控制
2. 优化系统参数
3. 使用 Hysteria2 等高性能协议
4. 选择物理距离更近的 VPS

### Q: 流量消耗大怎么办？

**A**:
1. 启用压缩
2. 配置智能分流 (国内直连)
3. 限制视频清晰度
4. 监控流量使用情况

### Q: 如何备份配置？

**A**:
```bash
# 备份 X-UI 数据
tar -czf x-ui-backup.tar.gz /etc/x-ui/

# 备份到本地
scp root@vps-ip:/root/x-ui-backup.tar.gz ./
```

### Q: 忘记管理密码怎么办？

**A**:
```bash
# 重置 X-UI 密码
x-ui reset

# 或直接删除数据库
rm /etc/x-ui/x-ui.db
x-ui restart
```

---

## 相关资源

### 官方文档

- [X-UI GitHub](https://github.com/vaxilu/x-ui)
- [Xray 文档](https://xtls.github.io/)
- [Hysteria2 文档](https://v2.hysteria.network/)
- [WireGuard 文档](https://www.wireguard.com/)

### 工具推荐

- [V2Ray 配置生成器](https://www.v2fly.org/)
- [UUID 生成器](https://www.uuidgenerator.net/)
- [密码生成器](https://passwordsgenerator.net/)

---

**最后更新**: 2025-11-18

**返回**: [主文档](README.md)
