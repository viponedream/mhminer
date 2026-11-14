# ============================================================
# mhminer Windows 安装脚本 v2 (六十三, 2026-11-14 用户指令: 在线下载形态)
#   - 来源: GitHub 在线下载 (bin/<版本>/mhminer-windows-amd64.exe)
#   - 三个动作: install (安装/升级同词) / update [版本] (更新) / uninstall [-Purge] (卸载)
#   - 安装目录: C:\mhminer (单文件发行立法: data/cert/key/logs 锚定 exe 同目录)
#   - 开机自启: 任务计划程序 (SYSTEM, 最高权限) —— 裸控制台程序不识别 SCM 协议,
#     sc.exe 注册的服务起不来; 不引 NSSM/WinSW 第三方包装 (单文件立法)
#   - 防火墙: 程序全路径规则 (入+出) —— 免弹窗实测形态
#   - 升级跨 schema: 更新后自动执行 -migrate-db (存量库唯一升级通道, 立法; 幂等,
#     已是最新 = "零迁移" exit 0), 失败红即停
#   - 不铸造凭据: 默认 admin/admin + 首启提醒跳转机制照旧 (立法)
# 用法:
#   powershell -ExecutionPolicy Bypass -File install-windows.ps1                 # 安装 (默认版本)
#   powershell -ExecutionPolicy Bypass -File install-windows.ps1 update          # 更新到默认版本
#   powershell -ExecutionPolicy Bypass -File install-windows.ps1 update 1.0.2    # 更新到指定版本
#   powershell -ExecutionPolicy Bypass -File install-windows.ps1 uninstall       # 卸载 (保留数据)
#   powershell -ExecutionPolicy Bypass -File install-windows.ps1 uninstall -Purge # 卸载并删数据
# 网络: 国内环境请设置 https_proxy 环境变量或系统代理 (下载走系统代理)
# ============================================================
param(
    [Parameter(Position = 0)][string]$Action = "install",
    [Parameter(Position = 1)][string]$Version = "",
    [switch]$Purge,
    [string]$InstallDir = "C:\mhminer"
)

$ErrorActionPreference = "Stop"
$TaskName = "mhminer"
$Exe = Join-Path $InstallDir "mhminer.exe"

# 六十三 v4 (用户裁决 "latest.json 多余, 版本号通过文件名就知道"): 版本发现 = GitHub API
# 列仓库 dist/ 目录 → 平台带版本名 → 版本号取最大; 下载 = 平铺 dist/<带版本名>。
# API 不可达/限流 (无鉴权 60 次/时) 回落脚本内置默认。
$DefaultVersion = "1.0.1"
$BaseRoot = "https://raw.githubusercontent.com/viponedream/mhminer/main/dist"
$ApiUrl = "https://api.github.com/repos/viponedream/mhminer/contents/dist"
$RemoteBase = "mhminer-windows-amd64"

# --- 管理员权限检测 (不足则自提升 UAC 重跑) ---
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[i] 需要管理员权限, 正在自提升..." -ForegroundColor Yellow
    Start-Process -FilePath $PSCommandPath -ArgumentList $args -Verb RunAs
    exit 0
}

function Info($m) { Write-Host "[i] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ok] $m" -ForegroundColor Green }

# RunNative 原生命令执行辅助: PS5.1 已知坑 —— $ErrorActionPreference='Stop' 时
# native 命令 stderr (即使 2>$null) 会作为 terminating error 抛出。
# 解法 = 执行期间临时降级 Continue (stderr 静默), 恢复后按需红即停 ($LASTEXITCODE)。
function RunNative([scriptblock]$Block, [switch]$Check) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Block 2>$null | Out-Null
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($Check -and $rc -ne 0) {
        Write-Host "[!] 命令失败 (exit $rc)" -ForegroundColor Red
        exit 1
    }
}

function StopByPath($p) {
    # 按完整路径精确终止 (立法: 严禁按镜像名 taskkill —— 误杀同名多实例)
    Get-Process mhminer -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $p } | Stop-Process -Force
}

# Get-LatestVersion 版本发现 (六十三 v4): GitHub API 列 dist/ → 平台带版本名 →
# 版本号取最大 ([version] 数值比较, 防词典序 1.0.10 < 1.0.9); 不可达回落内置默认。
function Get-LatestVersion {
    try {
        $ProgressPreference = "SilentlyContinue"
        $listing = Invoke-RestMethod -UseBasicParsing -Uri $ApiUrl -TimeoutSec 20
        $pat = [regex]::Escape($RemoteBase) + "-v([0-9.]+)\.exe$"
        $latest = $listing.name |
            ForEach-Object { if ($_ -match $pat) { [version]$Matches[1] } } |
            Sort-Object | Select-Object -Last 1
        if ($latest) { return $latest.ToString() }
    } catch {}
    return $DefaultVersion
}

function Download-Mhminer([string]$Ver) {
    $tmp = Join-Path $env:TEMP "mhminer-download.exe"
    $url = "$BaseRoot/$RemoteBase-v$Ver.exe"
    Info "下载 $url ..."
    Remove-Item -Force $tmp -ErrorAction SilentlyContinue
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        RunNative { curl.exe -fL --retry 3 --max-time 300 -o $tmp $url } -Check
    } else {
        try {
            $ProgressPreference = "SilentlyContinue"
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp
        } catch {
            Write-Host "[!] 下载失败 ($($_.Exception.Message)) — 检查网络/代理" -ForegroundColor Red
            exit 1
        }
    }
    if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -lt 1MB) {
        Write-Host "[!] 下载文件异常 (大小不足)" -ForegroundColor Red
        exit 1
    }
    $fs = [System.IO.File]::OpenRead($tmp)
    $magic = New-Object byte[] 2
    $null = $fs.Read($magic, 0, 2)
    $fs.Close()
    if ($magic[0] -ne 0x4D -or $magic[1] -ne 0x5A) {
        Write-Host "[!] 下载文件非 Windows PE (缺 MZ 头) — 检查仓库 dist/ 内容" -ForegroundColor Red
        exit 1
    }
    return $tmp
}

function StopAll {
    RunNative { schtasks /end /tn $TaskName }
    if (Test-Path $Exe) { StopByPath $Exe }
}

function EnsureFirewall {
    RunNative { netsh advfirewall firewall delete rule name="mhminer-exe-in" }
    RunNative { netsh advfirewall firewall delete rule name="mhminer-exe-out" }
    RunNative { netsh advfirewall firewall add rule name="mhminer-exe-in"  dir=in  program="$Exe" action=allow } -Check
    RunNative { netsh advfirewall firewall add rule name="mhminer-exe-out" dir=out program="$Exe" action=allow } -Check
    Ok "防火墙规则就位 (入+出)"
}

function EnsureTask {
    $action = '"' + $Exe + '"'
    RunNative { schtasks /create /f /tn $TaskName /sc onstart /ru SYSTEM /rl highest /tr $action } -Check
    Ok "任务计划 $TaskName 就位 (开机自启)"
}

function StartTask {
    RunNative { schtasks /run /tn $TaskName } -Check
    Start-Sleep -Seconds 3
}

# ---------------- uninstall ----------------
if ($Action -eq "uninstall") {
    Info "卸载 mhminer..."
    RunNative { schtasks /end /tn $TaskName }
    RunNative { schtasks /delete /tn $TaskName /f }
    if (Test-Path $Exe) { StopByPath $Exe }
    RunNative { netsh advfirewall firewall delete rule name="mhminer-exe-in" }
    RunNative { netsh advfirewall firewall delete rule name="mhminer-exe-out" }
    Ok "任务计划 + 防火墙规则已移除"
    if ($Purge) {
        if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir; Ok "已删除 $InstallDir (含数据)" }
    } else {
        Info "数据保留在 $InstallDir (彻底删除请加 -Purge)"
    }
    Ok "卸载完成"
    exit 0
}

# ---------------- install / update ----------------
if ($Action -ne "install" -and $Action -ne "update") {
    Write-Host "[!] 未知动作: $Action (可用: install / update [版本] / uninstall [-Purge])" -ForegroundColor Red
    exit 1
}
if (-not $Version) { $Version = Get-LatestVersion; Info "发现最新版本: v$Version" }

$tmp = Download-Mhminer $Version

Info "停止运行中的实例..."
StopAll

Info "部署二进制 v$Version → $Exe ..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Force $tmp $Exe
Remove-Item -Force $tmp -ErrorAction SilentlyContinue
Ok "二进制就位"

EnsureFirewall
EnsureTask

Info "数据底座 schema 迁移检查 (-migrate-db, 幂等)..."
RunNative { & $Exe -migrate-db } -Check

Info "立即启动..."
StartTask

Ok "================= $Action 完成 (v$Version) ================="
Ok "安装目录: $InstallDir (data/cert/logs 锚定于此)"
Ok "开机自启: 任务计划 $TaskName (SYSTEM)"
Ok "后台:     http://<本机IP>:8888  (默认 admin/admin, 登录后请立即修改)"
Ok "日志:     控制台无窗口 (SYSTEM 会话); 文件日志请进后台设置 log_file"
try {
    Info "当前凭据 (-show-credentials):"
    & $Exe -show-credentials
} catch { Info "凭据查询跳过 ($($_.Exception.Message))" }
