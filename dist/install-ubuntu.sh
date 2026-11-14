#!/usr/bin/env bash
# ============================================================
# mhminer Ubuntu/Debian 安装脚本 v2 (六十三, 2026-11-14 用户指令: 在线下载形态)
#   - 来源: GitHub 在线下载 (bin/<版本>/mhminer-linux-amd64)
#   - 三个动作: install (安装/升级同词) / update [版本] (更新) / uninstall [purge] (卸载)
#   - 安装目录: /root/mhminer (单文件发行立法: data/cert/key/logs 锚定二进制同目录)
#   - 运行用户: root (脚本前置检查, 非 root 拒绝安装 —— 用户裁决)
#   - 服务:     systemd (开机自启 enable --now; Restart=on-failure; LimitNOFILE 万级连接)
#   - 优雅停机: main.go:426 signal.Notify(SIGTERM) —— systemd stop 走 B-10 优雅退出
#   - 升级跨 schema: 更新后自动执行 -migrate-db (存量库唯一升级通道, 立法; 幂等,
#     已是最新 = "零迁移" exit 0), 失败红即停
#   - 日志:     journald = 有意审计道 (DS-M1 方案 B 定谳)
#   - 不铸造凭据: 默认 admin/admin + 首启提醒跳转机制照旧 (立法)
# 用法:
#   sudo ./install-ubuntu.sh                     # 安装 (默认版本)
#   sudo ./install-ubuntu.sh update              # 更新到默认版本
#   sudo ./install-ubuntu.sh update 1.0.2        # 更新到指定版本
#   sudo ./install-ubuntu.sh uninstall           # 卸载 (保留数据)
#   sudo ./install-ubuntu.sh uninstall purge     # 卸载并删数据
# 网络: 国内环境请设置 https_proxy 环境变量 (curl 走代理)
# ============================================================
set -euo pipefail

TASK="mhminer"
INSTALL_DIR="/root/mhminer"
UNIT="/etc/systemd/system/mhminer.service"
DEFAULT_VERSION="1.0.1"
BASE_ROOT="https://raw.githubusercontent.com/viponedream/mhminer/main/dist"
API_URL="https://api.github.com/repos/viponedream/mhminer/contents/dist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_BASE="mhminer-linux-amd64"

die()  { echo "[!] $*" >&2; exit 1; }
info() { echo "[i] $*"; }
ok()   { echo "[ok] $*"; }

# 六十三 v4 (用户裁决 "latest.json 多余, 版本通过文件名就知道"): GitHub API 列 dist/
# → 平台带版本名 → 版本号取最大 (sort -V 数值比较); API 不可达/限流回落内置默认
get_latest() {
    local v
    v=$(curl -fsSL --max-time 20 "$API_URL" 2>/dev/null \
        | grep -oE "\"name\": *\"$REMOTE_BASE-v[0-9.]+\"" \
        | grep -oE '[0-9]+\.[0-9.]+' | sort -uV | tail -1)
    [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$DEFAULT_VERSION"
}


ACTION="${1:-install}"

# --- root 前置检查 (用户裁决: 是 root 才安装) ---
if [ "$(id -u)" -ne 0 ]; then
    die "请用 root 运行 (sudo ./install-ubuntu.sh)"
fi

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

# ---------------- uninstall ----------------
if [ "$ACTION" = "uninstall" ]; then
    info "卸载 mhminer..."
    systemctl disable --now "$TASK" 2>/dev/null || true
    rm -f "$UNIT"
    systemctl daemon-reload
    ok "systemd 服务已移除"
    if [ "${2:-}" = "purge" ]; then
        rm -rf "$INSTALL_DIR"
        ok "已删除 $INSTALL_DIR (含数据)"
    else
        info "数据保留在 $INSTALL_DIR (彻底删除: uninstall purge)"
    fi
    ok "卸载完成"
    exit 0
fi

# ---------------- install / update ----------------
case "$ACTION" in
    install|update) ;;
    *) die "未知动作: $ACTION (可用: install / update [版本] / uninstall [purge])" ;;
esac
VERSION="${2:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(get_latest)
    info "发现最新版本: v$VERSION"
fi

TMP=$(download_mhminer "$VERSION")

info "停止运行中的服务..."
stop_all

info "部署二进制 v$VERSION → $INSTALL_DIR/mhminer ..."
mkdir -p "$INSTALL_DIR"
install -m 755 "$TMP" "$INSTALL_DIR/mhminer"
rm -f "$TMP"
ok "二进制就位"

ensure_unit

info "数据底座 schema 迁移检查 (-migrate-db, 幂等)..."
"$INSTALL_DIR/mhminer" -migrate-db

info "启用并启动 (开机自启)..."
systemctl enable --now "$TASK"
sleep 2
systemctl --no-pager --lines=5 status "$TASK" || true

ok "================= $ACTION 完成 (v$VERSION) ================="
ok "安装目录: $INSTALL_DIR (data/cert/logs 锚定于此)"
ok "开机自启: systemctl is-enabled $TASK"
ok "日志:     journalctl -u $TASK -f   (journald = 有意审计道, DS-M1 方案 B)"
ok "后台:     http://<本机IP>:8888  (默认 admin/admin, 登录后请立即修改)"
ok "凭据遗忘: $INSTALL_DIR/mhminer -show-credentials"
