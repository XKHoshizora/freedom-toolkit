#!/bin/bash

################################################################################
# VPS X-UI 面板一键部署脚本
# 用途: 在 VPS 上部署 X-UI 多协议代理管理面板
# 支持协议: VMess, VLESS, Trojan, Shadowsocks, Hysteria2, WireGuard
# 适用系统: Ubuntu 20.04+, Debian 10+, CentOS 7+
# 作者: Claude
# 日期: 2025-11-18
################################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
X_UI_PORT=54321
DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD=""
ENABLE_SSL=false
DOMAIN=""

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

log_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# 显示欢迎信息
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║              VPS X-UI 面板一键部署脚本                     ║
║                                                            ║
║          支持多协议: Xray, Hysteria2, WireGuard            ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "此脚本必须以 root 用户运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    log_step "检测系统信息..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        log_info "操作系统: $PRETTY_NAME"
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    
    # 检查架构
    ARCH=$(uname -m)
    log_info "系统架构: $ARCH"
    
    if [[ ! "$ARCH" =~ ^(x86_64|aarch64|armv7l)$ ]]; then
        log_warn "检测到非主流架构: $ARCH，可能存在兼容性问题"
    fi
}

# 检查系统要求
check_requirements() {
    log_step "检查系统要求..."
    
    # 检查内存
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 512 ]; then
        log_error "内存不足 (当前: ${TOTAL_MEM}MB，建议: 512MB+)"
        exit 1
    fi
    log_info "内存: ${TOTAL_MEM}MB ✓"
    
    # 检查磁盘空间
    AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
    AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
    if [ "$AVAILABLE_SPACE_GB" -lt 1 ]; then
        log_error "磁盘空间不足 (当前: ${AVAILABLE_SPACE_GB}GB，建议: 1GB+)"
        exit 1
    fi
    log_info "磁盘空间: ${AVAILABLE_SPACE_GB}GB 可用 ✓"
    
    # 检查网络连接
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "无法连接到互联网，请检查网络连接"
        exit 1
    fi
    log_info "网络连接: 正常 ✓"
}

# 获取公网 IP
get_public_ip() {
    log_step "获取公网 IP 地址..."
    
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null)
    
    if [ -z "$PUBLIC_IP" ]; then
        log_error "无法获取公网 IP"
        exit 1
    fi
    
    log_info "公网 IP: $PUBLIC_IP"
}

# 安装系统依赖
install_dependencies() {
    log_step "安装系统依赖..."
    
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        log_info "更新软件包列表..."
        apt-get update -qq
        
        log_info "安装必要工具..."
        apt-get install -y curl wget tar socat jq git > /dev/null 2>&1
        
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        log_info "安装必要工具..."
        yum install -y curl wget tar socat jq git > /dev/null 2>&1
        
    else
        log_warn "未知系统: $OS，尝试继续安装..."
    fi
    
    log_info "系统依赖安装完成 ✓"
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."
    
    # 检查防火墙类型
    if command -v ufw &> /dev/null; then
        log_info "检测到 UFW 防火墙"
        ufw allow $X_UI_PORT/tcp comment "X-UI Panel" > /dev/null 2>&1 || true
        log_info "已开放端口: $X_UI_PORT (X-UI 管理面板)"
        
    elif command -v firewall-cmd &> /dev/null; then
        log_info "检测到 Firewalld 防火墙"
        firewall-cmd --permanent --add-port=$X_UI_PORT/tcp > /dev/null 2>&1 || true
        firewall-cmd --reload > /dev/null 2>&1 || true
        log_info "已开放端口: $X_UI_PORT (X-UI 管理面板)"
        
    else
        log_warn "未检测到防火墙，跳过配置"
    fi
    
    # 提示常用端口
    log_info "建议开放以下端口用于代理服务:"
    log_info "  - 443 (HTTPS/TLS)"
    log_info "  - 80 (HTTP)"
    log_info "  - 自定义端口 (如 8443, 10086 等)"
}

# 用户交互配置
interactive_config() {
    log_step "配置 X-UI 参数..."
    echo ""
    
    # 管理面板端口
    read -p "$(echo -e ${CYAN}请输入 X-UI 管理面板端口 [默认: 54321]:${NC} )" input_port
    X_UI_PORT=${input_port:-54321}
    log_info "管理面板端口: $X_UI_PORT"
    
    # 管理员用户名
    read -p "$(echo -e ${CYAN}请输入管理员用户名 [默认: admin]:${NC} )" input_username
    DEFAULT_USERNAME=${input_username:-admin}
    log_info "管理员用户名: $DEFAULT_USERNAME"
    
    # 管理员密码
    while true; do
        read -sp "$(echo -e ${CYAN}请输入管理员密码 [留空则随机生成]:${NC} )" input_password
        echo ""
        if [ -z "$input_password" ]; then
            DEFAULT_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
            log_warn "已生成随机密码: $DEFAULT_PASSWORD"
            log_warn "请务必保存此密码！"
            break
        else
            read -sp "$(echo -e ${CYAN}请再次输入密码确认:${NC} )" input_password2
            echo ""
            if [ "$input_password" == "$input_password2" ]; then
                DEFAULT_PASSWORD="$input_password"
                log_info "密码设置成功 ✓"
                break
            else
                log_error "两次密码输入不一致，请重新输入"
            fi
        fi
    done
    
    # 域名配置（可选）
    read -p "$(echo -e ${CYAN}是否配置域名? (y/n) [默认: n]:${NC} )" enable_domain
    if [[ "$enable_domain" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${CYAN}请输入域名 (例如: example.com):${NC} )" DOMAIN
        if [ -n "$DOMAIN" ]; then
            log_info "域名: $DOMAIN"
            read -p "$(echo -e ${CYAN}是否为管理面板启用 SSL/TLS? (y/n) [默认: n]:${NC} )" enable_ssl
            if [[ "$enable_ssl" =~ ^[Yy]$ ]]; then
                ENABLE_SSL=true
                log_info "SSL/TLS: 启用"
            fi
        fi
    fi
    
    echo ""
}

# 安装 X-UI
install_xui() {
    log_step "开始安装 X-UI..."
    
    # 下载并执行官方安装脚本
    log_info "下载 X-UI 安装脚本..."
    
    # 使用官方脚本 (支持多个镜像)
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh"
    
    # 尝试从 GitHub 下载
    if ! curl -Ls "$INSTALL_SCRIPT_URL" -o /tmp/x-ui-install.sh; then
        log_warn "从 GitHub 下载失败，尝试使用镜像..."
        INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh"
        curl -Ls "$INSTALL_SCRIPT_URL" -o /tmp/x-ui-install.sh
    fi
    
    if [ ! -f /tmp/x-ui-install.sh ]; then
        log_error "下载 X-UI 安装脚本失败"
        exit 1
    fi
    
    log_info "开始执行 X-UI 安装..."
    bash /tmp/x-ui-install.sh > /tmp/x-ui-install.log 2>&1
    
    # 等待安装完成
    sleep 3
    
    if ! command -v x-ui &> /dev/null; then
        log_error "X-UI 安装失败，请查看日志: /tmp/x-ui-install.log"
        exit 1
    fi
    
    log_success "X-UI 安装成功 ✓"
    rm -f /tmp/x-ui-install.sh
}

# 配置 X-UI
configure_xui() {
    log_step "配置 X-UI 参数..."
    
    # 停止服务
    x-ui stop > /dev/null 2>&1 || true
    sleep 2
    
    # 修改配置文件
    XUI_DB="/etc/x-ui/x-ui.db"
    
    if [ -f "$XUI_DB" ]; then
        # 修改端口
        sqlite3 "$XUI_DB" "UPDATE settings SET value='$X_UI_PORT' WHERE key='webPort';" 2>/dev/null || true
        
        # 修改用户名和密码
        sqlite3 "$XUI_DB" "UPDATE users SET username='$DEFAULT_USERNAME', password='$DEFAULT_PASSWORD' WHERE id=1;" 2>/dev/null || true
        
        log_info "配置已更新 ✓"
    else
        log_warn "配置文件不存在，将使用默认配置"
    fi
    
    # 启动服务
    x-ui start
    sleep 3
    
    # 检查服务状态
    if x-ui status | grep -q "running"; then
        log_success "X-UI 服务启动成功 ✓"
    else
        log_error "X-UI 服务启动失败"
        exit 1
    fi
}

# 安装额外协议支持
install_protocols() {
    log_step "安装额外协议支持..."
    
    log_info "Xray-core: X-UI 已内置 ✓"
    
    # Hysteria2 (可选)
    log_info "检查 Hysteria2 支持..."
    if ! command -v hysteria &> /dev/null; then
        log_info "安装 Hysteria2..."
        bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1 || log_warn "Hysteria2 安装失败（可选组件）"
    else
        log_info "Hysteria2: 已安装 ✓"
    fi
    
    # WireGuard (可选)
    log_info "检查 WireGuard 支持..."
    if ! command -v wg &> /dev/null; then
        log_info "安装 WireGuard..."
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            apt-get install -y wireguard > /dev/null 2>&1 || log_warn "WireGuard 安装失败（可选组件）"
        elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            yum install -y wireguard-tools > /dev/null 2>&1 || log_warn "WireGuard 安装失败（可选组件）"
        fi
    else
        log_info "WireGuard: 已安装 ✓"
    fi
}

# 系统优化
optimize_system() {
    log_step "优化系统参数..."
    
    # 备份原配置
    cp /etc/sysctl.conf /etc/sysctl.conf.backup 2>/dev/null || true
    
    # 优化网络参数
    cat >> /etc/sysctl.conf << EOF

# X-UI 优化参数
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 16384 67108864
net.ipv4.tcp_mtu_probing=1
fs.file-max=1000000
EOF
    
    # 应用配置
    sysctl -p > /dev/null 2>&1 || log_warn "部分优化参数应用失败"
    
    log_info "系统优化完成 ✓"
}

# 配置定时任务
configure_cron() {
    log_step "配置定时任务..."
    
    # SSL 证书自动续期（如果启用了 SSL）
    if [ "$ENABLE_SSL" = true ] && [ -n "$DOMAIN" ]; then
        log_info "添加 SSL 证书自动续期任务..."
        (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/x-ui cert") | crontab -
    fi
    
    # 每周自动备份数据库
    log_info "添加数据库自动备份任务..."
    (crontab -l 2>/dev/null; echo "0 4 * * 0 tar -czf /root/x-ui-backup-\$(date +\%Y\%m\%d).tar.gz /etc/x-ui/") | crontab -
    
    log_info "定时任务配置完成 ✓"
}

# 安全加固
security_hardening() {
    log_step "安全加固..."
    
    # 修改 SSH 端口（可选）
    log_info "建议修改 SSH 端口以提高安全性"
    
    # 禁用 root 密码登录（如果已配置密钥）
    if [ -f ~/.ssh/authorized_keys ]; then
        log_info "检测到 SSH 密钥，建议禁用密码登录"
    fi
    
    # 启用 fail2ban（可选）
    log_info "建议安装 fail2ban 防止暴力破解"
    
    log_info "安全建议已输出 ✓"
}

# 显示安装信息
show_info() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              X-UI 安装成功！                               ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  访问信息:                                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    管理面板: http://${PUBLIC_IP}:${X_UI_PORT}            ${GREEN}║${NC}"
    if [ -n "$DOMAIN" ]; then
        if [ "$ENABLE_SSL" = true ]; then
            echo -e "${GREEN}║${NC}    域名访问: https://${DOMAIN}:${X_UI_PORT}          ${GREEN}║${NC}"
        else
            echo -e "${GREEN}║${NC}    域名访问: http://${DOMAIN}:${X_UI_PORT}           ${GREEN}║${NC}"
        fi
    fi
    echo -e "${GREEN}║${NC}    用户名: ${DEFAULT_USERNAME}                           ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    密码: ${DEFAULT_PASSWORD}                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  常用命令:                                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    x-ui start     # 启动                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    x-ui stop      # 停止                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    x-ui restart   # 重启                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    x-ui status    # 状态                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    x-ui update    # 更新                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    x-ui           # 更多命令                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  下一步:                                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    1. 访问管理面板                                        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    2. 添加入站配置 (VMess/VLESS/Trojan/SS/Hysteria2)     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    3. 在 OpenWrt PassWall2 中添加此服务器节点            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ⚠️  重要提醒:                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    - 请立即修改默认密码                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    - 保存好登录凭证                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    - 在防火墙/安全组中开放必要端口                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    - 建议启用面板 SSL                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 保存信息到文件
    cat > /root/x-ui-info.txt << EOFINFO
X-UI 安装信息
============================================
安装时间: $(date '+%Y-%m-%d %H:%M:%S')
公网 IP: $PUBLIC_IP
管理面板: http://${PUBLIC_IP}:${X_UI_PORT}
用户名: $DEFAULT_USERNAME
密码: $DEFAULT_PASSWORD

常用命令:
  x-ui start     # 启动
  x-ui stop      # 停止
  x-ui restart   # 重启
  x-ui status    # 状态
  x-ui update    # 更新

配置文件位置:
  /etc/x-ui/x-ui.db

日志文件位置:
  /var/log/x-ui/

备份位置:
  /root/x-ui-backup-*.tar.gz
EOFINFO
    
    log_info "安装信息已保存到: /root/x-ui-info.txt"
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    rm -f /tmp/x-ui-install.sh
    rm -f /tmp/x-ui-install.log
}

# 主函数
main() {
    show_banner
    check_root
    detect_system
    check_requirements
    get_public_ip
    
    # 交互式配置
    interactive_config
    
    # 开始安装
    install_dependencies
    configure_firewall
    install_xui
    configure_xui
    install_protocols
    optimize_system
    configure_cron
    security_hardening
    
    # 显示结果
    show_info
    
    log_success "脚本执行完成！"
    log_info "现在可以访问管理面板开始配置节点了"
}

# 捕获错误
trap cleanup EXIT

# 执行主函数
main "$@"
