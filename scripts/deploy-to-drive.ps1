# deploy-to-drive.ps1
# ---------------------------------------------------------------------------
# 在 原有软件不动 的前提下，将 CampusConnect 额外部署一份到 D 盘独立目录。
# 执行：powershell -ExecutionPolicy Bypass -File .\scripts\deploy-to-drive.ps1
# ---------------------------------------------------------------------------
# 依赖（已由 AppIdentity.cs 自动完成）：
#   1. AppIdentity.cs   — 统一派生器，从 exe 文件名取应用名
#   2. LocalStore.cs     — 配置目录 = %LOCALAPPDATA%\AppIdentity.Name\
#   3. Program.cs       — 互斥体   = Local\AppIdentity.WindowsTag
#   4. StartupRegistration.cs — 注册表值 = AppIdentity.WindowsTag
#
# 因此不同文件名的副本：
#   CampusConnect.exe    → %LOCALAPPDATA%\CampusConnect\   Local\CampusConnect.Windows
#   自动登录.exe         → %LOCALAPPDATA%\自动登录\          Local\自动登录.Windows
#   → 配置、进程互斥、开机自启项 全部隔离，可并行运行 ✅
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
Write-Host "dotnet SDK : $(dotnet --version)"

$project = Join-Path $RepoRoot 'Windows\source\CampusConnect.csproj'
if (-not (Test-Path $project)) {
    $project = Join-Path (Get-Location).Path 'Windows\source\CampusConnect.csproj'
}
if (-not (Test-Path $project)) {
    Write-Host "✗ 未找到 CampusConnect.csproj，请在仓库根目录执行脚本，或用 -RepoRoot 指定。" -ForegroundColor Red
    exit 1
}
Write-Host "项目路径   : $project"

# 校验 AppIdentity.cs 已存在（这是隔离的基础）
$appIdentity = Join-Path (Split-Path $project) 'AppIdentity.cs'
if (Test-Path $appIdentity) {
    Write-Host "AppIdentity: 已就绪 ✅  (配置/互斥体/启动项 将按 exe 文件名自动隔离)" -ForegroundColor Green
} else {
    Write-Host "⚠ AppIdentity.cs 不存在 — 请先从仓库合入最新代码。" -ForegroundColor Yellow
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
$storeDir   = Join-Path $env:LOCALAPPDATA $DeployName

Write-Host "部署目录   : $deployDir"
Write-Host "部署 exe   : $deployExe"
Write-Host "独立配置   : $storeDir\configuration.json" -ForegroundColor Magenta
Write-Host "互斥体     : Local\${DeployName}.Windows" -ForegroundColor Magenta
Write-Host "启动项     : HKCU Run -> ${DeployName}.Windows" -ForegroundColor Magenta
Write-Host "临时目录   : $tempDir"
if (Test-Path $existing) {
    Write-Host "原有安装   : $existing  (保持不动 ✅)" -ForegroundColor Green
} else {
    Write-Host "原有安装   : 未检测到" -ForegroundColor Gray
}
Write-Host ""
Write-Host "━━━ 预期隔离效果 ━━━" -ForegroundColor DarkGray
Write-Host " C 盘原版  配置: %LOCALAPPDATA%\CampusConnect\configuration.json"
Write-Host "           互斥体: Local\CampusConnect.Windows"
Write-Host "           启动项: HKCU Run -> CampusConnect.Windows"
Write-Host " D 盘副本  配置: ${storeDir}\configuration.json"
Write-Host "           互斥体: Local\${DeployName}.Windows  ← 与原版不同，可并行运行 ✅"
Write-Host "           启动项: HKCU Run -> ${DeployName}.Windows" -ForegroundColor DarkGray

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

$published = Get-ChildItem $tempDir -File
if ($published.Count -ne 1 -or $published[0].Name -ne 'CampusConnect.exe') {
    Write-Host "✗ publish 产物异常：" ($published.Name -join ', ') -ForegroundColor Red
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
$srcExe = $published[0].FullName
Write-Host "publish 成功 : $($published[0].Name)  ($([math]::Round($published[0].Length/1MB,2)) MB)" -ForegroundColor Green

# ---------- 3. 重命名 + 移动到 D 盘 ----------
Write-Host "`n===== 3/6 重命名为 $DeployName.exe 并部署 =====" -ForegroundColor Cyan

New-Item -ItemType Directory -Path $deployDir -Force | Out-Null

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
    $lnk.Description = "校园网助手（$DeployName）- 独立配置于 D 盘"
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

Write-Host @"

┌───────────────────────────────────────────────────────────────────┐
│ ✅ 部署完成                                                         │
│                                                                     │
│   📦 可执行文件 : $deployExe
│   📁 独立配置   : $storeDir\configuration.json
│   🔗 进程互斥   : Local\${DeployName}.Windows  ← 可与原版并行运行
│                                                                     │
│ C 盘原版配置 : $env:LOCALAPPDATA\CampusConnect\configuration.json
│ D 盘副本配置 : $storeDir\configuration.json          ← 互不影响
│                                                                     │
│ 💡 第一次启动 D 盘版本后，首次配置保存在 $storeDir\
│ 💡 若想从原版导入配置，手动把原版的 configuration.json 复制过去即可
└───────────────────────────────────────────────────────────────────┘

请双击 $deployExe 或桌面快捷方式启动。
"@ -ForegroundColor Cyan
