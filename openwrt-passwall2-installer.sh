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
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          PassWall2 安装成功！                              ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  访问地址: http://$(uci get network.lan.ipaddr 2>/dev/null || echo "路由器IP")                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  配置路径: 服务 → PassWall2                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  已安装协议:                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ Xray (VMess/VLESS)                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ Hysteria2                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ Shadowsocks                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ Trojan                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ WireGuard                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ✓ sing-box                                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  下一步:                                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    1. 在日本 VPS 部署服务端                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    2. 在 PassWall2 中添加节点                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    3. 配置分流规则（国内直连，国外代理）                 ${GREEN}║${NC}"
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
    enable_service
    show_info
    
    log_info "脚本执行完成！"
}

# 捕获错误
trap cleanup EXIT

# 执行主函数
main "$@"
