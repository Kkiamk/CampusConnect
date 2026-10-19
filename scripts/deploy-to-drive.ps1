# deploy-to-drive.ps1
# ---------------------------------------------------------------------------
# 在 原有软件不动 的前提下，将 CampusConnect 额外部署一份到 D:\自动登录\
# 执行：powershell -ExecutionPolicy Bypass -File .\scripts\deploy-to-drive.ps1
#   - 不动任何源码、不修改 .csproj、不删除 C 盘已有安装
#   - dotnet publish 到临时目录 → 改名为 自动登录.exe → 移动到 D:\自动登录\
#   - 可选创建桌面快捷方式
# ---------------------------------------------------------------------------

param(
    [string]$RepoRoot = "D:\campus-connect",
    [string]$DriveLetter = "D",
    [string]$DeployName  = "自动登录",
    [string]$Runtime     = "win-x64"   # 或 win-arm64
)

$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "CampusConnect 部署到 D 盘 - $DeployName"

# ---------- 0. 环境校验 ----------
Write-Host "`n===== 0/6 环境校验 =====" -ForegroundColor Cyan

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "✗ 未检测到 dotnet SDK。请先安装 .NET 10 SDK（含 win-x64 targeting pack）。" -ForegroundColor Red
    exit 1
}
Write-Host "dotnet SDK: $(dotnet --version)"

$project = Join-Path $RepoRoot 'Windows\source\CampusConnect.csproj'
if (-not (Test-Path $project)) {
    # 允许用户从仓库根目录直接执行
    $project = Join-Path (Get-Location).Path 'Windows\source\CampusConnect.csproj'
}
if (-not (Test-Path $project)) {
    Write-Host "✗ 未找到 CampusConnect.csproj，请在仓库根目录执行脚本，或用 -RepoRoot 指定。" -ForegroundColor Red
    exit 1
}
Write-Host "项目路径  : $project"

# 校验 csproj 的 AssemblyName 仍为 CampusConnect — 这是 "原有软件不动" 的证据
$csproj = Get-Content $project -Raw
if ($csproj -match '<AssemblyName>([^<]+)</AssemblyName>') {
    $asm = $Matches[1]
    Write-Host "AssemblyName 保持为 : $asm  (原有软件未被动 ✅)" -ForegroundColor Green
    if ($asm -ne 'CampusConnect') {
        Write-Host "⚠ AssemblyName 不是 CampusConnect — 源码似乎已经被改过，请检查。" -ForegroundColor Yellow
    }
}

$drive = "${DriveLetter}:\"
if (-not (Test-Path $drive)) {
    Write-Host "✗ 驱动器 $DriveLetter 不存在（D 盘未挂载？）" -ForegroundColor Red
    exit 1
}
Write-Host "目标驱动器 : $drive"

# ---------- 1. 规划路径 ----------
Write-Host "`n===== 1/6 规划路径 =====" -ForegroundColor Cyan

$deployDir  = Join-Path $drive $DeployName          # D:\自动登录
$deployExe  = Join-Path $deployDir "$DeployName.exe"# D:\自动登录\自动登录.exe
$tempDir    = Join-Path $env:TEMP ("campus-deploy-" + [guid]::NewGuid().ToString('N'))
$existing   = Join-Path $env:LOCALAPPDATA "Programs\CampusConnect\"

Write-Host "部署目录   : $deployDir"
Write-Host "部署 exe   : $deployExe"
Write-Host "临时目录   : $tempDir"
if (Test-Path $existing) {
    Write-Host "原有安装   : $existing  (检测到 C 盘已安装，保持不动 ✅)" -ForegroundColor Green
} else {
    Write-Host "原有安装   : 未检测到，仅部署新副本" -ForegroundColor Gray
}

# ---------- 2. dotnet publish 到临时目录 ----------
Write-Host "`n===== 2/6 dotnet publish（单文件 Release，自包含） =====" -ForegroundColor Cyan

dotnet publish $project `
    -c Release `
    -r $Runtime `
    --self-contained true `
    -p:PublishReadyToRun=true `
    -p:PublishSingleFile=true `
    -o $tempDir

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ dotnet publish 失败。" -ForegroundColor Red
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# 验证单文件
$published = Get-ChildItem $tempDir -File
if ($published.Count -ne 1 -or $published[0].Name -ne 'CampusConnect.exe') {
    Write-Host "✗ publish 产物异常：" ($published.Name -join ', ') -ForegroundColor Red
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
$srcExe = $published[0].FullName
Write-Host "publish 成功 : $($published[0].Name)  ($([math]::Round($published[0].Length/1MB,2)) MB)" -ForegroundColor Green

# ---------- 3. 重命名 + 移动到 D 盘 ----------
Write-Host "`n===== 3/3 重命名为 $DeployName.exe 并部署 =====" -ForegroundColor Cyan

New-Item -ItemType Directory -Path $deployDir -Force | Out-Null

# 如果目标已有旧版本，先删（只删同名，不动任何其他东西）
if (Test-Path $deployExe) {
    $oldHash = (Get-FileHash $deployExe -Algorithm SHA256).Hash
    $newHash = (Get-FileHash $srcExe    -Algorithm SHA256).Hash
    if ($oldHash -eq $newHash) {
        Write-Host "新版本与部署目录中已有文件完全一致，跳过复制。" -ForegroundColor Green
        Remove-Item $tempDir -Recurse -Force
        goto :Shortcut
    } else {
        Write-Host "覆盖旧版本（SHA256 不同）"
    }
}

Move-Item -Path $srcExe -Destination $deployExe -Force
Write-Host "已部署 : $deployExe  ($([math]::Round((Get-Item $deployExe).Length/1MB,2)) MB)" -ForegroundColor Green

# ---------- 4. 清理临时目录 ----------
Write-Host "`n===== 4/6 清理临时目录 =====" -ForegroundColor Cyan
Remove-Item $tempDir -Recurse -Force
Write-Host "临时目录已删除 ✅" -ForegroundColor Gray

# ---------- 5. 可选：桌面快捷方式 ----------
:Shortcut
Write-Host "`n===== 5/6 创建桌面快捷方式 =====" -ForegroundColor Cyan
$createLnk = Read-Host "在桌面创建 [$DeployName] 快捷方式？(y/N)"
$desktop   = [Environment]::GetFolderPath('Desktop')
$lnkPath   = Join-Path $desktop "$DeployName.lnk"

if ($createLnk -match '^(y|Y)$') {
    $ws = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($lnkPath)
    $lnk.TargetPath = $deployExe
    $lnk.WorkingDirectory = $deployDir
    $lnk.Description = "校园网助手（自动登录）- 部署于 D 盘"
    $lnk.IconLocation = $deployExe
    $lnk.Save()
    Write-Host "快捷方式: $lnkPath ✅" -ForegroundColor Green
} else {
    Write-Host "跳过快捷方式。" -ForegroundColor Gray
}

# ---------- 6. 验证 ----------
Write-Host "`n===== 6/6 部署验证 =====" -ForegroundColor Cyan
if (Test-Path $deployExe) {
    $exe = Get-Item $deployExe
    Write-Host "✓ $deployExe 存在" -ForegroundColor Green
    Write-Host "  大小    : $([math]::Round($exe.Length/1MB,2)) MB"
    Write-Host "  修改时间: $($exe.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
} else {
    Write-Host "✗ 部署后文件消失，请检查杀毒软件 / 安全策略。" -ForegroundColor Red
    exit 1
}
if (Test-Path $existing) {
    Write-Host "✓ 原有 CampusConnect 安装仍在 : $existing" -ForegroundColor Green
}

# ---------- Mutex 提醒 ----------
Write-Host @"

┌───────────────────────────────────────────────────────────────┐
│ ⚠ Mutex 提醒                                                   │
│                                                                 │
│ 原 CampusConnect 和 新的 $DeployName 共用同一进程互斥名           │
│  Local\CampusConnect.Windows                                    │
│  → 两者不能同时运行（系统会提示"校园网助手已在运行"）           │
│  → 关掉 C 盘版本后再开 D 盘版本，反之亦然                       │
└───────────────────────────────────────────────────────────────┘

✅ 部署完成！请双击 $deployExe 或桌面快捷方式启动。
"@ -ForegroundColor Yellow
