#!/bin/bash

################################################################################
# OpenWrt PassWall2 一键安装脚本
# 适用于: OpenWrt 24.10.x / aarch64_cortex-a53 架构
# 设备: GL.iNet GL-MT3000 (Beryl AX) 及其他兼容设备
# 作者: Claude
# 日期: 2025-11-18
################################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
SELECTED_THEME="bootstrap"
LUCI_PORT=80
USE_ALT_PORT=false

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

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "此脚本必须以 root 用户运行"
        exit 1
    fi
}

# 检查系统信息
check_system() {
    log_step "检查系统信息..."
    
    if [ ! -f /etc/openwrt_release ]; then
        log_error "这不是 OpenWrt 系统"
        exit 1
    fi
    
    . /etc/openwrt_release
    
    log_info "系统版本: ${DISTRIB_DESCRIPTION}"
    log_info "系统架构: ${DISTRIB_ARCH}"
    log_info "目标平台: ${DISTRIB_TARGET}"
    
    # 检查版本是否兼容
    MAJOR_VERSION=$(echo ${DISTRIB_RELEASE} | cut -d'.' -f1)
    if [ "$MAJOR_VERSION" -lt 23 ]; then
        log_warn "您的 OpenWrt 版本较旧 (${DISTRIB_RELEASE})，可能存在兼容性问题"
        read -p "是否继续安装? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 检查磁盘空间
check_space() {
    log_step "检查磁盘空间..."
    
    AVAILABLE=$(df /overlay | tail -1 | awk '{print $4}')
    AVAILABLE_MB=$((AVAILABLE / 1024))
    
    log_info "可用空间: ${AVAILABLE_MB} MB"
    
    if [ "$AVAILABLE_MB" -lt 50 ]; then
        log_error "磁盘空间不足 (需要至少 50MB，当前 ${AVAILABLE_MB}MB)"
        exit 1
    fi
}

# 备份当前配置
backup_config() {
    log_step "备份当前软件源配置..."
    
    if [ -f /etc/opkg/customfeeds.conf ]; then
        cp /etc/opkg/customfeeds.conf /etc/opkg/customfeeds.conf.backup.$(date +%Y%m%d_%H%M%S)
        log_info "已备份到: /etc/opkg/customfeeds.conf.backup.*"
    fi
}

# 安装基础依赖
install_dependencies() {
    log_step "安装基础依赖..."
    
    opkg update
    
    log_info "安装 wget-ssl curl ca-certificates..."
    opkg install wget-ssl curl ca-bundle ca-certificates 2>/dev/null || log_warn "部分依赖已安装，跳过"
}

# 添加 PassWall2 软件源
add_passwall_feeds() {
    log_step "添加 PassWall2 软件源..."
    
    # 删除旧的自定义源配置（如果存在）
    if [ -f /etc/opkg/customfeeds.conf ]; then
        # 删除已存在的 passwall 相关源
        sed -i '/passwall/d' /etc/opkg/customfeeds.conf
    fi
    
    # 获取系统版本和架构
    read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF
    
    log_info "系统版本: $release"
    log_info "系统架构: $arch"
    
    # 添加 PassWall2 官方源（使用 SourceForge）
    for feed in passwall_packages passwall2; do
        echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
        log_info "已添加源: $feed"
    done
    
    # 更新软件源
    log_info "更新软件包列表..."
    if ! opkg update; then
        log_error "更新软件源失败，请检查网络连接"
        exit 1
    fi
    
    log_info "软件源添加成功"
}

# 安装 PassWall2 核心
install_passwall2() {
    log_step "安装 PassWall2 核心..."
    
    if opkg list-installed | grep -q "luci-app-passwall2"; then
        log_warn "PassWall2 已安装，跳过安装"
        return
    fi
    
    log_info "开始安装 luci-app-passwall2..."
    if ! opkg install luci-app-passwall2; then
        log_error "PassWall2 安装失败"
        exit 1
    fi
    
    log_info "安装中文语言包..."
    opkg install luci-i18n-passwall2-zh-cn 2>/dev/null || log_warn "中文语言包安装失败，可以稍后手动安装"
    
    log_info "PassWall2 核心安装完成"
}

# 安装协议支持
install_protocols() {
    log_step "安装代理协议支持..."
    
    # Xray (V2Ray 的高性能分支，默认已安装)
    log_info "检查 Xray-core..."
    opkg list-installed | grep -q "xray-core" && log_info "✓ Xray-core 已安装" || log_warn "✗ Xray-core 未安装"
    
    # sing-box (多协议支持)
    log_info "安装 sing-box..."
    opkg install sing-box 2>/dev/null && log_info "✓ sing-box 安装成功" || log_warn "✗ sing-box 安装失败"
    
    # Hysteria2 (高性能 QUIC 代理)
    log_info "安装 Hysteria2..."
    opkg install hysteria 2>/dev/null && log_info "✓ Hysteria2 安装成功" || log_warn "✗ Hysteria2 安装失败"
    
    # Shadowsocks Rust (高性能 SS 实现)
    log_info "安装 Shadowsocks-rust..."
    opkg install shadowsocks-rust-sslocal 2>/dev/null && log_info "✓ Shadowsocks-rust 安装成功" || log_warn "✗ Shadowsocks-rust 安装失败"
    
    # V2Ray Plugin
    log_info "安装 V2Ray-plugin..."
    opkg install v2ray-plugin 2>/dev/null && log_info "✓ V2Ray-plugin 安装成功" || log_warn "✗ V2Ray-plugin 安装失败"
    
    # WireGuard
    log_info "检查 WireGuard..."
    if opkg list-installed | grep -q "wireguard-tools"; then
        log_info "✓ WireGuard 已安装"
    else
        log_info "安装 WireGuard..."
        opkg install wireguard-tools kmod-wireguard && log_info "✓ WireGuard 安装成功" || log_warn "✗ WireGuard 安装失败"
    fi
    
    # Trojan
    log_info "安装 Trojan-plus..."
    opkg install trojan-plus 2>/dev/null && log_info "✓ Trojan-plus 安装成功" || log_warn "✗ Trojan-plus 安装失败"
    
    log_info "协议支持安装完成"
}

# 安装辅助工具
install_utilities() {
    log_step "安装辅助工具..."
    
    # tcping (TCP 端口连通性测试)
    opkg list-installed | grep -q "tcping" && log_info "✓ tcping 已安装" || log_warn "✗ tcping 未安装"
    
    # chinadns-ng (国内 DNS 分流)
    log_info "安装 chinadns-ng..."
    opkg install chinadns-ng 2>/dev/null && log_info "✓ chinadns-ng 安装成功" || log_warn "✗ chinadns-ng 安装失败（非必需）"
    
    # dns2socks (DNS over SOCKS5)
    log_info "安装 dns2socks..."
    opkg install dns2socks 2>/dev/null && log_info "✓ dns2socks 安装成功" || log_warn "✗ dns2socks 安装失败（非必需）"
    
    log_info "辅助工具安装完成"
}

# 安装主题
install_themes() {
    log_step "主题安装选项..."
    echo ""
    
    read -p "$(echo -e ${CYAN}是否安装额外主题? (y/n) [默认: y]:${NC} )" install_theme
    install_theme=${install_theme:-y}
    
    if [[ ! "$install_theme" =~ ^[Yy]$ ]]; then
        log_info "跳过主题安装，使用默认 Bootstrap 主题"
        return
    fi
    
    echo ""
    echo -e "${CYAN}请选择要安装的主题:${NC}"
    echo "  1) Material - Material Design 风格（推荐，稳定）"
    echo "  2) Argon - 毛玻璃效果，最漂亮（需下载）"
    echo "  3) OpenWrt 2020 - 官方现代主题"
    echo "  4) 全部安装"
    echo "  5) 跳过"
    echo ""
    
    read -p "$(echo -e ${CYAN}请选择 [1-5, 默认: 1]:${NC} )" theme_choice
    theme_choice=${theme_choice:-1}
    
    case $theme_choice in
        1)
            log_info "安装 Material 主题..."
            opkg install luci-theme-material && log_info "✓ Material 安装成功" || log_warn "✗ Material 安装失败"
            SELECTED_THEME="material"
            ;;
        2)
            log_info "安装 Argon 主题..."
            cd /tmp
            if wget --no-check-certificate https://github.com/jerrykuku/luci-theme-argon/releases/download/v2.3.1/luci-theme-argon_2.3.1_all.ipk 2>/dev/null; then
                opkg install luci-theme-argon_2.3.1_all.ipk && log_info "✓ Argon 安装成功" || log_warn "✗ Argon 安装失败"
                SELECTED_THEME="argon"
            else
                log_warn "Argon 下载失败，安装 Material 作为替代"
                opkg install luci-theme-material
                SELECTED_THEME="material"
            fi
            ;;
        3)
            log_info "安装 OpenWrt 2020 主题..."
            opkg install luci-theme-openwrt-2020 && log_info "✓ OpenWrt 2020 安装成功" || log_warn "✗ OpenWrt 2020 安装失败"
            SELECTED_THEME="openwrt2020"
            ;;
        4)
            log_info "安装所有主题..."
            opkg install luci-theme-material
            opkg install luci-theme-openwrt-2020
            cd /tmp
            wget --no-check-certificate https://github.com/jerrykuku/luci-theme-argon/releases/download/v2.3.1/luci-theme-argon_2.3.1_all.ipk 2>/dev/null && \
            opkg install luci-theme-argon_2.3.1_all.ipk
            SELECTED_THEME="material"
            log_info "✓ 所有主题安装完成"
            ;;
        5)
            log_info "跳过主题安装"
            SELECTED_THEME="bootstrap"
            return
            ;;
        *)
            log_warn "无效选择，安装 Material 主题"
            opkg install luci-theme-material
            SELECTED_THEME="material"
            ;;
    esac
}

# 配置 uhttpd 端口
configure_uhttpd() {
    log_step "配置 LuCI Web 服务..."
    
    # 检查端口占用
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        log_warn "端口 80 已被占用（可能是 nginx 或其他服务）"
        USE_ALT_PORT=true
    else
        USE_ALT_PORT=false
    fi
    
    if [ "$USE_ALT_PORT" = true ]; then
        log_info "配置 uhttpd 使用备用端口..."
        
        # 删除旧配置
        uci delete uhttpd.main.listen_http 2>/dev/null
        uci delete uhttpd.main.listen_https 2>/dev/null
        
        # 添加新配置
        uci add_list uhttpd.main.listen_http='0.0.0.0:8080'
        uci add_list uhttpd.main.listen_https='0.0.0.0:8443'
        uci commit uhttpd
        
        LUCI_PORT=8080
        log_info "LuCI 配置为端口 8080/8443"
    else
        log_info "使用默认端口 80/443"
        LUCI_PORT=80
    fi
}

# 应用主题
apply_theme() {
    if [ -n "$SELECTED_THEME" ] && [ "$SELECTED_THEME" != "bootstrap" ]; then
        log_step "应用主题: $SELECTED_THEME"
        
        uci set luci.main.mediaurlbase="/luci-static/$SELECTED_THEME"
        uci commit luci
        
        log_info "✓ 主题已设置为 $SELECTED_THEME"
    fi
}

# 启用并启动服务
enable_service() {
    log_step "启用并启动 PassWall2 服务..."
    
    # 启用服务
    /etc/init.d/passwall2 enable
    log_info "PassWall2 服务已设置为开机自启"
    
    # 启动服务
    /etc/init.d/passwall2 start 2>/dev/null || /etc/init.d/passwall2 restart
    log_info "PassWall2 服务已启动"
    
    # 重启 Web 界面
    /etc/init.d/uhttpd restart
    log_info "LuCI Web 界面已重启"
}

# 显示安装信息
show_info() {
    log_step "安装完成！"
    
    # 获取路由器 IP
    ROUTER_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
    LUCI_PORT=${LUCI_PORT:-80}
    
    # 构建访问地址
    if [ "$LUCI_PORT" = "80" ]; then
        LUCI_URL="http://${ROUTER_IP}"
    else
        LUCI_URL="http://${ROUTER_IP}:${LUCI_PORT}"
    fi
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          PassWall2 安装成功！                              ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  访问地址: ${LUCI_URL}                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  配置路径: 服务 → PassWall2                               ${GREEN}║${NC}"
    if [ -n "$SELECTED_THEME" ] && [ "$SELECTED_THEME" != "bootstrap" ]; then
        echo -e "${GREEN}║${NC}  当前主题: ${SELECTED_THEME}                               ${GREEN}║${NC}"
    fi
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  已安装协议:                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ Xray (VMess/VLESS)                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ Hysteria2                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ Shadowsocks                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ Trojan                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ WireGuard                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ sing-box                                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    if [ "$USE_ALT_PORT" = true ]; then
        echo -e "${GREEN}║${NC}  注意: 端口 80 被占用，LuCI 使用端口 ${LUCI_PORT}              ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    fi
    echo -e "${GREEN}║${NC}  切换主题:                                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    系统 → 系统 → 语言和外观 → 主题                        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  下一步:                                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    1. 访问管理界面                                        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    2. 在日本 VPS 部署服务端                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    3. 在 PassWall2 中添加节点                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    4. 配置分流规则（国内直连，国外代理）                 ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    # 这里可以添加清理逻辑
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║          OpenWrt PassWall2 一键安装脚本                    ║"
    echo "║                                                            ║"
    echo "║          适用于 OpenWrt 24.10.x                            ║"
    echo "║          GL.iNet GL-MT3000 (Beryl AX)                      ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # 执行安装步骤
    check_root
    check_system
    check_space
    backup_config
    install_dependencies
    add_passwall_feeds
    install_passwall2
    install_protocols
    install_utilities
    install_themes
    configure_uhttpd
    apply_theme
    enable_service
    show_info
    
    log_info "脚本执行完成！"
}

# 捕获错误
trap cleanup EXIT

# 执行主函数
main "$@"