#!/usr/bin/env bash
# ============================================================
# mhminer Ubuntu/Debian 安装管理脚本 v5 (六十五, 2026-11-14 用户指令:
# "安装,更新,卸载,由脚本里面提供选项, 用户只须运行 install-ubuntu.sh")
#   - 零参数运行 = 交互菜单 (安装/更新/卸载选项); 参数形态保留 (自动化)
#   - 来源: GitHub 在线下载 dist/mhminer-linux-amd64-v<版本>
#   - 安装目录: /root/mhminer; root 直跑 (前置检查); systemd 开机自启
#   - 随包 mhminer.service 优先, 缺失内联回落
#   - 升级跨 schema: 自动 -migrate-db (幂等, 失败红即停)
#   - journald = 有意审计道 (DS-M1 方案 B); 不铸造凭据 (admin/admin + 提醒跳转照旧)
# 用法:
#   sudo ./install-ubuntu.sh                  # 交互菜单
#   sudo ./install-ubuntu.sh install [版本]   # 直接安装/更新 (缺省 = 最新)
#   sudo ./install-ubuntu.sh uninstall        # 卸载 (含数据)
# 网络: 国内环境请设置 https_proxy 环境变量 (curl 走代理)
# ============================================================
set -euo pipefail

TASK="mhminer"
INSTALL_DIR="/root/mhminer"
UNIT="/etc/systemd/system/mhminer.service"
DEFAULT_VERSION="1.0.1"
BASE_ROOT="https://raw.githubusercontent.com/viponedream/mhminer/main/dist"
API_URL="https://api.github.com/repos/viponedream/mhminer/contents/dist"
REMOTE_BASE="mhminer-linux-amd64"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

die()  { echo "[!] $*" >&2; exit 1; }
info() { echo "[i] $*" >&2; }
ok()   { echo "[ok] $*" >&2; }

# --- root 前置检查 (用户裁决: 是 root 才安装) ---
if [ "$(id -u)" -ne 0 ]; then
    die "请用 root 运行 (sudo ./install-ubuntu.sh)"
fi

# 六十三 v4: 版本发现 = GitHub API 列 dist/ → 平台带版本名 → 版本号取最大 (sort -V);
# API 不可达/限流回落内置默认
get_latest() {
    local v
    v=$(curl -fsSL --max-time 20 "$API_URL" 2>/dev/null \
        | grep -oE "\"name\": *\"$REMOTE_BASE-v[0-9.]+\"" \
        | grep -oE '[0-9]+\.[0-9.]+' | sort -uV | tail -1)
    [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$DEFAULT_VERSION"
}

# --- 下载 + 校验 (平铺 dist 带版本名; 大小 + ELF magic) ---
download_mhminer() {
    local ver="$1"
    local tmp="/tmp/mhminer-download"
    local url="$BASE_ROOT/$REMOTE_BASE-v$ver"
    info "下载 $url ..."
    rm -f "$tmp"
    if ! curl -fSL --retry 3 --max-time 300 -o "$tmp" "$url" 2>/dev/null; then
        die "下载失败 — 检查网络/代理 (https_proxy) 与仓库 dist/ 内容"
    fi
    [ -s "$tmp" ] || die "下载文件为空"
    local magic
    magic=$(head -c 4 "$tmp")
    [ "$magic" = "$(printf '\x7fELF')" ] || die "下载文件非 Linux ELF (magic 异常)"
    echo "$tmp"
}

stop_all() {
    systemctl stop "$TASK" 2>/dev/null || true
}

ensure_unit() {
    # 六十四: 随包 mhminer.service 优先 (dist 完整包), 缺失时内联回落 (单独下载脚本形态)
    if [ -f "$SCRIPT_DIR/mhminer.service" ]; then
        info "安装随包 service 文件..."
        cp -f "$SCRIPT_DIR/mhminer.service" "$UNIT"
        systemctl daemon-reload
        ok "unit 就位 (随包文件)"
        return 0
    fi
    info "生成 systemd unit (随包文件缺失, 内联回落)..."
    cat > "$UNIT" <<EOF
[Unit]
Description=MinerHome mhminer mining pool relay (single-file, exe-dir anchored)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/mhminer
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    ok "unit 就位"
}

do_uninstall() {
    # 六十六 用户裁决: 卸载 = 一律含数据 (卸载了就没必要保留数据)
    info "卸载 mhminer..."
    systemctl disable --now "$TASK" 2>/dev/null || true
    rm -f "$UNIT"
    systemctl daemon-reload
    ok "systemd 服务已移除"
    rm -rf "$INSTALL_DIR"
    ok "已删除 $INSTALL_DIR (含数据)"
    ok "卸载完成"
}

do_install() {
    local ver="$1"
    local tmp
    tmp=$(download_mhminer "$ver")

    info "停止运行中的服务..."
    stop_all

    info "部署二进制 v$ver → $INSTALL_DIR/mhminer ..."
    mkdir -p "$INSTALL_DIR"
    install -m 755 "$tmp" "$INSTALL_DIR/mhminer"
    rm -f "$tmp"
    ok "二进制就位"

    ensure_unit

    info "数据底座 schema 迁移检查 (-migrate-db, 幂等)..."
    "$INSTALL_DIR/mhminer" -migrate-db

    info "启用并启动 (开机自启)..."
    systemctl enable --now "$TASK"
    sleep 2
    systemctl --no-pager --lines=5 status "$TASK" || true

    ok "================= 完成 (v$ver) ================="
    ok "安装目录: $INSTALL_DIR (data/cert/logs 锚定于此)"
    ok "开机自启: systemctl is-enabled $TASK"
    ok "日志:     journalctl -u $TASK -f"
    ok "后台:     http://<本机IP>:8888  (默认 admin/admin, 登录后请立即修改)"
    ok "凭据遗忘: $INSTALL_DIR/mhminer -show-credentials"
}

show_menu() {
    local latest
    latest=$(get_latest)
    echo "================= mhminer 管理脚本 (Ubuntu) ================="
    echo " 仓库最新版本: v$latest"
    echo " 1) 安装 / 更新 (最新版本)"
    echo " 2) 安装 / 更新 (指定版本)"
 echo " 3) 卸载"
 echo " 0) 退出"
}

menu_loop() {
    while true; do
        show_menu
        local c ver
        read -rp "请选择: " c || die "非交互环境请用参数形态 (install [版本] / uninstall)"
        case "$c" in
            1) do_install "$(get_latest)" ;;
            2) read -rp "版本号 (如 1.0.1): " ver
               [ -n "$ver" ] || die "版本号不能为空"
               do_install "$ver" ;;
            3) do_uninstall ;;
            0) exit 0 ;;
            *) echo "[!] 无效选择" ;;
        esac
    done
}

# --- 入口分发: 零参数 = 菜单 (用户指令); 参数 = 自动化形态 ---
if [ $# -eq 0 ]; then
    if [ ! -t 0 ]; then
        die "非交互环境请用参数形态: install [版本] / uninstall"
    fi
    menu_loop
    exit 0
fi

case "$1" in
    install|update) do_install "${2:-$(get_latest)}" ;;
    uninstall)      do_uninstall ;;
    menu)           menu_loop ;;
    *)              die "未知动作: $1 (可用: install [版本] / update [版本] / uninstall / menu)" ;;
esac
