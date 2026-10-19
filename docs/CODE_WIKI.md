# CampusConnect Code Wiki

> **版本**：2.0.3 · **维护者**：Ye9137 · **许可证**：MIT
> 最后更新：2026-10-19

---

## 目录

1. [项目概览](#1-项目概览)
2. [目录结构](#2-目录结构)
3. [总体架构](#3-总体架构)
4. [平台对比](#4-平台对比)
5. [核心数据模型](#5-核心数据模型)
6. [Windows 平台模块详解](#6-windows-平台模块详解)
   - 6.1 [Program.cs — 入口](#61-programcs--入口)
   - 6.2 [MainForm.cs — 主控制器](#62-mainformcs--主控制器)
   - 6.3 [MainForm.BrowserRecovery.cs — 界面恢复](#63-mainformbrowserrecoverycs--界面恢复)
   - 6.4 [DesktopBridge.cs + Desktop.html — 内嵌 UI](#64-desktopbridgecs--desktophhtml--内嵌-ui)
   - 6.5 [PortalController.cs — 认证页控制](#65-portalcontrollercs--认证页控制)
   - 6.6 [WifiService.cs — WLAN Native 接口](#66-wifiservicecs--wlan-native-接口)
   - 6.7 [Connectivity.cs + CampusNetwork — 网络可达性](#67-connectivitycs--campusnetwork--网络可达性)
   - 6.8 [WiredAuthentication.cs — 有线系统认证](#68-wiredauthenticationcs--有线系统认证)
   - 6.9 [LocalStore.cs — DPAPI 加密存储](#69-localstorecs--dpapi-加密存储)
   - 6.10 [StartupRegistration.cs — 开机自启](#610-startupregistrationcs--开机自启)
7. [macOS 平台模块详解](#7-macos-平台模块详解)
   - 7.1 [App.swift + AppModel — 主界面与编排](#71-appswift--appmodel--主界面与编排)
   - 7.2 [Portal.swift — 认证页控制](#72-portalswift--认证页控制)
   - 7.3 [WiFi.swift — CoreWLAN 封装](#73-wifiswift--corewlan-封装)
   - 7.4 [WiredAuthentication.swift + WiredSystem — 有线系统](#74-wiredauthenticationswift--wiredsystem--有线系统)
   - 7.5 [Connectivity.swift — ping 联网检测](#75-connectivityswift--ping-联网检测)
   - 7.6 [CampusProxy.swift — 物理网卡绑定代理](#76-campusproxyswift--物理网卡绑定代理)
   - 7.7 [Core.swift — 数据模型与 LocalStore](#77-coreswift--数据模型与-localstore)
8. [JavaScript 认证脚本](#8-javascript-认证脚本)
   - 8.1 [PortalTemplate.js (Windows) — 填写与提交](#81-portaltemplatejs-windows--填写与提交)
   - 8.2 [PortalBootstrap.js — ePortal 初始化加速](#82-portalbootstrapjs--eportal-初始化加速)
   - 8.3 [PortalAgreements.js (Windows) — 协议勾选](#83-portalagreementsjs-windows--协议勾选)
   - 8.4 [macOS 内嵌 PortalScript.build — Swift 版脚本](#84-macos-内嵌-portalscriptbuild--swift-版脚本)
9. [依赖关系图](#9-依赖关系图)
10. [构建与运行](#10-构建与运行)
11. [测试体系](#11-测试体系)
12. [GitHub Actions CI](#12-github-actions-ci)
13. [配置与存储](#13-配置与存储)
14. [术语表](#14-术语表)

---

## 1. 项目概览

**CampusConnect**（校园 Wi-Fi 助手）是一个**跨平台桌面应用**，专门用于完成校园网认证：连接校园 Wi-Fi 或有线网络后，自动填写账号密码、选择运营商、勾选协议，并触发学校原有的登录处理流程。

- **支持平台**：Windows 10/11 x64（可选 ARM64）、macOS 14+（Apple 芯片 + Intel 通用包）
- **适配学校**：河南工业职业技术大学、郑州信息工程职业学院、无锡职业技术大学、天津石油职业技术学院、华东交通大学、南通大学（均可下载测试）
- **连接模式**：
  - Wi-Fi 无线网络（开放 / 加密 / 企业 802.1X）
  - 有线网络 + 网页认证
  - 有线网络 + PPPoE 宽带拨号（复用系统已保存凭据）
  - 有线网络 + 802.1X 系统认证（复用系统描述文件）
  - 有线网络 + 学校专用客户端（启动外部 .exe / .app）
- **核心能力**：后台自动连接（每 20s 轮询）、自动填写账号/密码/运营商/协议、百度 ping 联网检测、认证失效自动重连（递增退避 60→300s）、开机自启

### 核心设计哲学

1. **信任学校的加密与认证流程** — 程序只负责 DOM 识别、账号密码注入、触发学校原有按钮事件；不直接调用任何认证接口或 API
2. **不保存系统凭据** — PPPoE / 802.1X / 企业 Wi-Fi 凭据均由操作系统存储，程序只发起系统级命令
3. **最小权限** — 不修改系统 VPN / DNS / 路由；密码加密存储在本机

---

## 2. 目录结构

```
CampusConnect/
├── Windows/                         # Windows 平台
│   ├── source/                      # C# / .NET 10 / WinForms / WebView2 源码
│   │   ├── CampusConnect.csproj     # 项目文件（单文件发布、ReadyToRun）
│   │   ├── Program.cs               # 入口（单实例互斥、WebView2 loader 定位）
│   │   ├── MainForm.cs              # 主窗体 + 核心编排逻辑（部分类）
│   │   ├── MainForm.BrowserRecovery.cs  # 白屏/崩溃恢复（部分类）
│   │   ├── DesktopBridge.cs          # 内嵌 UI ↔ C# 命令桥
│   │   ├── Desktop.html              # 内嵌 UI（3 页面 HTML，内嵌 CSS/JS）
│   │   ├── PortalController.cs       # 认证页 WebView2 控制（部分类）
│   │   ├── WifiService.cs            # WLAN Native API P/Invoke 封装
│   │   ├── Connectivity.cs           # ping 联网检测 + 以太网链路检测
│   │   ├── WiredAuthentication.cs    # rasdial / netsh / 客户端启动
│   │   ├── LocalStore.cs             # JSON + DPAPI 加密保存
│   │   ├── StartupRegistration.cs    # HKCU Run 注册表开机自启
│   │   ├── PortalTemplate.js         # 核心认证脚本（嵌入资源）
│   │   ├── PortalAgreements.js       # 协议勾选脚本（嵌入资源）
│   │   ├── PortalBootstrap.js        # ePortal 初始化加速（从 macOS 复用）
│   │   └── app.manifest / AppIcon.ico
│   ├── tests/                        # 可跨平台运行的核心逻辑检查
│   │   ├── CampusConnect.Tests.csproj    # .NET 单元测试（Program.cs）
│   │   ├── *.test.cjs / *.test.mjs       # Node + Playwright 浏览器脚本回归
│   │   └── fixtures/cmcc-font-radio.html
│   ├── installer/                    # NSIS 安装向导
│   │   ├── CampusConnect.nsi
│   │   ├── build.py                  # 安装包构建脚本
│   │   ├── smoke-test.ps1            # 安装/修复/卸载冒烟测试
│   │   └── test-manifest.py
│   ├── build.ps1                     # 单文件发布脚本
│   ├── build-installer.ps1           # 安装包构建脚本
│   └── README.md
├── macOS/
│   ├── source/                       # Swift 原生源码
│   │   ├── Core.swift                # CampusProfile / AutoPolicy / PortalRecovery / LocalStore / PortalScript
│   │   ├── App.swift                 # SwiftUI 主界面 + AppModel 编排
│   │   ├── Portal.swift              # WKWebView 认证页控制
│   │   ├── WiFi.swift                # CoreWLAN 扫描/连接 + WiredNetwork NWPathMonitor
│   │   ├── WiredAuthentication.swift # PPPoE / 802.1X / 客户端启动 + WiredSystem
│   │   ├── Connectivity.swift         # system ping 封装
│   │   ├── CampusProxy.swift         # 本地 loopback HTTP CONNECT 代理，绑定物理网卡
│   │   ├── PortalBootstrap.js         # ePortal 初始化加速脚本（嵌入 bundle）
│   │   ├── Info.plist / AppIcon.icns
│   │   └── build.sh                  # swiftc + lipo 通用包构建
│   ├── test.sh                       # 核心逻辑回归
│   ├── test-webkit.sh                # WKWebView 首次提交回归
│   └── README.md
├── docs/screenshots/                 # 界面截图
├── licenses/                         # 第三方许可证
├── scripts/
│   ├── package-source.py             # 干净源码包生成
│   └── capture-screenshots.cjs
├── .github/workflows/
│   ├── build.yml                     # 主 CI：macOS universal + Windows x64/ARM64 安装包
│   └── test-release.yml
├── VALIDATION.md                     # 实际校园网验证记录
├── LICENSE / README.md               # MIT 许可证 + 项目总览
└── THIRD_PARTY_NOTICES.md
```

---

## 3. 总体架构

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                    CampusConnect                                      │
├──────────────────────────────────────────┬───────────────────────────────────────────┤
│           Windows (C# / WinForms)        │           macOS (Swift / SwiftUI)          │
├──────────────────────────────────────────┼───────────────────────────────────────────┤
│ Program.cs (入口、单实例互斥)             │ CampusConnectApp / AppDelegate              │
│     ↓                                     │     ↓                                       │
│ MainForm.cs (窗体 + 编排)                 │ AppModel (ObservableObject, 编排)            │
│   ├─ Desktop.html (内嵌 WebView2 UI)      │   ├─ RootView (SwiftUI 侧边栏 + 3 页面)     │
│   ├─ PortalController.cs (认证 WebView2)  │   ├─ PortalController (WKWebView)            │
│   ├─ AutoPolicy / PortalRecovery           │   ├─ AutoPolicy / PortalRecovery              │
│   ├─ WifiService (WLAN Native API)        │   ├─ WiFiService (CoreWLAN)                  │
│   ├─ CampusNetwork (System.Net.NetworkInfo)│   ├─ WiredNetwork (NWPathMonitor)             │
│   ├─ Connectivity (Ping)                  │   ├─ Connectivity (Process ping)              │
│   ├─ WiredAuthentication (rasdial/netsh)  │   ├─ WiredAuthentication (networksetup)        │
│   ├─ LocalStore (DPAPI + JSON)             │   ├─ LocalStore (JSON, 0600)                  │
│   └─ StartupRegistration (HKCU Run)       │   └─ SMAppService (登录项)                    │
├──────────────────────────────────────────┼───────────────────────────────────────────┤
│             共享：JavaScript 认证脚本层                                                  │
│ PortalScript (填写账号/密码/运营商/协议 + 触发登录按钮 + 观察学校处理函数)                │
│   输入：origin 匹配 + CSS 选择器自动识别 + 学校页面加密/参数（不改写）                    │
│   输出：状态字符串（submitted / authenticated / missing-fields / manual-required …）     │
└──────────────────────────────────────────┴───────────────────────────────────────────┘
```

### 流程：一次完整认证

```
定时 20s 触发 RefreshAsync / refresh()
   │
   ├─[Wi-Fi 模式] WifiService.ReadSnapshotAsync → 判断 SSID 是否匹配
   │     └─ 未匹配 + 开启自动连接 + 间隔 ≥ 60s → WifiService.JoinAsync → 连接
   │
   ├─[有线模式] CampusNetwork.ReadLinks / WiredSystem.selected
   │     ├─ 物理链路存在 + 系统认证 → WiredAuthentication.ConnectAsync
   │     │     ├─ PPPoE  → rasdial.exe
   │     │     ├─ 802.1X → netsh lan reconnect
   │     │     └─ 客户端 → Process.Start(.exe/.app)
   │     └─ 有链路 + 网页认证 → 下面流程
   │
   └─ 有网络 → Connectivity.CheckAsync → ping www.baidu.com
         ├─ Online → 完成
         └─ Unavailable + 开启自动连接 → PortalController.OpenAsync
               │
               ├─ 检查 origin 匹配
               ├─ 注入 PortalBootstrap.js → 加速学校 ePortal 初始化
               ├─ Navigate(portalUrl)
               ├─ DOMContentLoaded → TryFillAsync
               │     ├─ 最多 80 次尝试，每次间隔 150ms
               │     ├─ 执行 PortalTemplate.js (含协议勾选)
               │     └─ 返回 submitted / missing-fields / manual-required …
               ├─ submitted → ObserveAuthenticationAsync（30s 内轮询）
               │     ├─ /eportal/success.jsp + userIndex → ConfirmAuthentication
               │     ├─ 学校 AuthInterFace.login 返回 success → ConfirmAuthentication
               │     └─ 30s 超时 → 提示手动
               └─ 确认认证 → CheckInternetAsync → ping → Online/Unavailable
```

---

## 4. 平台对比

| 能力 | Windows | macOS |
| --- | --- | --- |
| UI 技术 | WinForms + 内嵌 WebView2 (in-process HTML) | SwiftUI + WKWebView |
| 认证页面浏览器 | WebView2（隐私会话） | WKWebView（nonPersistent 临时会话） |
| 网络接口探测 | `System.Net.NetworkInformation` | `SystemConfiguration` + `NWPathMonitor` |
| Wi-Fi 扫描/连接 | WLAN Native API (`wlanapi.dll` P/Invoke) | `CoreWLAN` (`CWWiFiClient`) |
| 有线 PPPoE | `rasdial.exe` | `/usr/sbin/networksetup -connectpppoeservice` |
| 有线 802.1X | `netsh lan reconnect interface=<name>` | 由 macOS 系统设置的描述文件自动处理 |
| 密码存储 | `ProtectedData` (DPAPI, CurrentUser) | 本地 JSON + 文件权限 0600 / 目录 0700 |
| 开机自启 | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` | `SMAppService.mainApp.register()` |
| 校园认证页直连 | WebView2 `--no-proxy-server` 绕过显式 HTTP 代理 | 本地 `CampusProxy` loopback 代理 + `NWParameters.requiredInterface` 绑定物理网卡 |
| Build 系统 | `dotnet publish` + NSIS | `swiftc -target arm64/x86_64` + `lipo` 合成通用包 |
| 发布形式 | 单文件 `CampusConnect.exe` + NSIS 安装包 | `CampusConnect.app` (universal) + zip |
| CPU 架构 | 默认 x64，可构建 ARM64 | arm64 + x86_64 通用包 |

---

## 5. 核心数据模型

两个平台有**功能等价但语法不同**的数据结构。以下按 Windows C# / Swift 对齐说明。

### 5.1 `CampusProfile` — 校园网配置

**C# (record)** — [Windows/source/Core.cs](Windows/source/Core.cs)

| 字段 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `Ssid` | `string` | `"HNPI-STU"` | Wi-Fi 名称；**留空 = 有线模式** |
| `WiredAuth` | `string` | `"web"` | 有线认证方式：`web` / `pppoe` / `dot1x` / `client` |
| `EthernetName` | `string` | `""` | 以太网接口名（如 `en5`），留空自动选第一个 link up 的 |
| `BroadbandName` | `string` | `""` | PPPoE 宽带连接名称 |
| `AuthenticationClient` | `string` | `""` | 学校专用客户端 `.exe` 完整路径 |
| `PortalEnabled` | `bool` | `true` | 是否打开网页认证 |
| `PortalUrl` | `string` | `"http://192.168.0.123"` | 学校认证地址 |
| `Username` | `string` | `""` | 上网账号 |
| `ServiceOption` | `string` | `""` | 运营商/服务完整名称（如"中国移动"），留空不选 |
| `UserSelector` | `string` | `""` | 高级：自定义账号输入框 CSS 选择器 |
| `PasswordSelector` | `string` | `""` | 高级：自定义密码输入框 CSS 选择器 |
| `SubmitSelector` | `string` | `""` | 高级：自定义登录按钮 CSS 选择器 |
| `AutoSubmit` | `bool` | `true` | 自动填写后点击登录 |
| `Automatic` | `bool` | `false` | 自动连接（后台轮询） |
| `UseSavedWifiProfile` | `bool` | — | Windows：加密 Wi-Fi 时使用系统已保存配置 |

**计算属性**（不序列化）：

| 属性 | 说明 |
| --- | --- |
| `IsWired` | `Ssid` 为空 = 有线模式 |
| `UsesSystemAuthentication` | 有线 + 非 `web` 模式 |
| `UsesWebPortal` | `PortalEnabled` + 非系统认证 |
| `ConnectionLabel` | 显示标签（"Wi-Fi" / "有线 · PPPoE 拨号" …） |

### 5.2 `AutoPolicy` — 自动连接节流

| 字段 | 说明 |
| --- | --- |
| `LastAttempt` | 上次尝试时间 |
| `ShouldJoin(...)` | 综合判断：启用 + 目标可见 + 未占用 + 距上次 ≥ 60s |
| `ShouldPrepareWired(...)` | 有线系统认证的等价判断 |
| `Begin / Reset` | 标记开始 / 重置 |

### 5.3 `PortalRecovery` — 认证失败恢复

| 字段 | 说明 |
| --- | --- |
| `Failures` | 连续失败次数（最多 2） |
| `Attempts` | 本次运行的认证尝试次数（最多 4） |
| `RetryDelay` | 递增退避：`min(300, 60 × 2^(max(0, Attempts-1)))` 秒 |
| `ShouldAuthenticate(...)` | 是否应该发起下一次认证 |
| `Observe(InternetStatus)` | 记录结果 |

### 5.4 `InternetStatus` — 联网状态

枚举值：`Online` / `Unavailable`

---

## 6. Windows 平台模块详解

所有源码位于 `Windows/source/`。主项目文件 `CampusConnect.csproj` 使用 .NET 10 / WinForms / WebView2 1.0.4258.31，`PublishSingleFile + PublishReadyToRun + IncludeNativeLibrariesForSelfExtract` 配置使发布产物仅为一个 `CampusConnect.exe`。

### 6.1 Program.cs — 入口

**文件**：[Windows/source/Program.cs](Windows/source/Program.cs)

- `[STAThread]` WinForms 强制 STA 线程模型
- `Mutex("Local\\CampusConnect.Windows")` 单实例互斥；第二个实例弹出 MessageBox "校园网助手已在运行"
- 启动前定位 WebView2Loader.dll：从 `NATIVE_DLL_SEARCH_DIRECTORIES` 中找到 loader 并调用 `CoreWebView2Environment.SetLoaderDllFolderPath`，因为单文件发布后 .NET bundle 会把原生 DLL 解压到私有目录
- 命令行参数：
  - `--startup`：开机自启路径启动（Minimized + ShowInTaskbar=false）
  - `--verify-ui <path>`：UI 冒烟测试模式（启动后立即收集 DOM 状态写入 JSON 文件并退出）

### 6.2 MainForm.cs — 主控制器

**文件**：[Windows/source/MainForm.cs](Windows/source/MainForm.cs) （约 490 行）

继承 `Form`，程序的**核心编排中枢**（partial class，恢复逻辑在 `MainForm.BrowserRecovery.cs`）。

#### 关键字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `saved` / `savedPassword` | `CampusProfile` / `string` | 当前已保存配置（不可变引用） |
| `portal` | `PortalController` | 认证页控制器 |
| `shell` | `WebView2` | 内嵌 UI（Desktop.html）的 WebView2 |
| `policy` / `recovery` | `AutoPolicy` / `PortalRecovery` | 节流 + 恢复状态机 |
| `timer` | `System.Windows.Forms.Timer` | 20s 周期触发 `RefreshAsync` |
| `tray` | `NotifyIcon` | 系统托盘图标 + 菜单（打开/刷新/暂停/退出） |
| `generation` | `int` | 配置版本号；保存/暂停/切换模式时 +1，用来使异步回调失效 |
| `portalBounds` | `Rectangle` | 认证 WebView2 在 shell UI 内的显示位置（由 Desktop.html 回传） |

#### 关键方法

| 方法 | 说明 |
| --- | --- |
| `InitializeShellAsync()` | 为 `shell` WebView2 注册资源过滤器，拦截 `*` 但只对受信源 `DesktopBridge.Uri` 回送 Desktop.html，其他返回 403；注册 WebMessageReceived 命令桥 |
| `HandleCommandAsync(JsonElement)` | 处理来自 Desktop.html 的命令：`ready / draft / page / portalBounds / connect / save / openPortal / discoverPortal / stopPortal / checkInternet / setStartup / chooseAuthClient / refresh` |
| `PushState()` / `SendState()` | 合并多次快速更新后一次性推给 Desktop.html（`kind=state`），避免闪烁 |
| `RefreshAsync(scan)` | 定时轮询入口：扫描 Wi-Fi / 检测有线链路 → 判断当前状态 → 自动连接或联网检测 |
| `CheckInternetAsync(openIfOffline)` | 核心联网检查：先 ping，失败时如果启用了自动认证则先尝试 portal（因为"ping 不通"和"认证未完成"是同一现象） |
| `ConnectAsync(snapshot, expected)` | Wi-Fi 连接流程 |
| `ConnectWiredAsync(manual)` | 有线系统认证流程 |
| `OpenPortalAsync(discover, showPage)` | 打开认证页；`discover=true` 时用 captive portal 探测 |
| `SaveFromMessage(message)` | 保存配置（校验 + DPAPI 加密密码 + 重置所有状态） |

#### 状态协调要点

- `generation` 递增是并发防护的核心手段：任何异步回调进入时必须检查 `expected == generation`，否则直接返回，避免旧保存或旧触发搞乱新状态
- `busy / joining / checking` 三个布尔值互斥，避免 RefreshAsync 重入
- 配置保存时 `policy.Reset()` + `recovery.Reset()` + `StopAuthentication()` + `generation++`，确保一切从头开始

### 6.3 MainForm.BrowserRecovery.cs — 界面恢复

**文件**：[Windows/source/MainForm.BrowserRecovery.cs](Windows/source/MainForm.BrowserRecovery.cs) （约 163 行）

处理**后台驻留 / 睡眠唤醒 / WebView2 渲染进程崩溃**三种场景下的界面白屏问题。

#### 触发条件

1. 窗口从隐藏（托盘）/最小化恢复 → `RequestShellRecovery(userRequested: true)`
2. 窗口被其他程序遮挡超过 60s 再激活 → `Activated` 事件触发
3. `shell` 的 `ProcessFailed` → BrowserProcessExited / RenderProcessExited / RenderProcessUnresponsive
4. `portal` 的 `ProcessFailed` → BrowserProcessExited 标记 `rebuildBrowserRequested`

#### 恢复策略

`RecoverShellAsync()` 最多尝试 2 次：

| 尝试 | 条件 | 动作 |
| --- | --- | --- |
| 1 | browser 进程正常，只是渲染挂起 | `shell.CoreWebView2.Resume()` + `Reload()` + 恢复草稿快照 |
| 2 | BrowserProcessExited 或上次 Reload 失败 | 销毁旧 `shell` + `browserEnvironment = null` 重建整个 WebView2 + 重走 `InitializeShellAsync` |
| 3 | 仍失败 | 显示原生重试按钮和恢复提示面板 |

#### Portal 恢复

当只有认证页（`portal.View`）渲染进程崩溃时，不影响主界面：调用 `ResetPortalView()` 重建 `portal.View` 控件，用户从托盘菜单或按钮再次点击"打开认证页"即可恢复。

#### 草稿保护

`shellSnapshot` 是在 `shellSnapshot` 内保存的 JSON（进程内），保存密码也只在 `MainForm.SaveFromMessage` 写入磁盘；恢复时用 `window.campus?.snapshot()` 从 UI 拉取草稿回填。**密码绝不写入恢复面板或日志**。

### 6.4 DesktopBridge.cs + Desktop.html — 内嵌 UI

#### DesktopBridge.cs

**文件**：[Windows/source/DesktopBridge.cs](Windows/source/DesktopBridge.cs)

- `Uri = "https://campusconnect-ui.invalid/"` — 内嵌 UI 的自签名 URI，所有非受信源的 WebMessage 在 WebResourceRequested 中被 403 拒绝
- `IsTrustedSource(string)` — 校验来源
- `ScaleBounds(JsonElement, clientWidth, clientHeight)` — Desktop.html 向 C# 请求 portalBounds 时，按 JS 端 viewport 坐标缩放为 WinForms 客户区像素

#### Desktop.html

**文件**：[Windows/source/Desktop.html](Windows/source/Desktop.html) （397 行）

单文件内嵌 SPA（无 Vue/React 依赖，纯 JS），三个页面：

1. **dashboard（网络概览）** — 连接状态卡、附近 Wi-Fi 列表、自动连接开关、"立即连接"按钮
2. **settings（校园网设置）** — 连接方式切换、SSID、认证地址、账号/密码、服务选项、开机自启开关、以太网接口/PPPoe 名称下拉
3. **portal（上网认证）** — 嵌入 `portal.View` WebView2（位置由 `portalBounds` 决定）+ 操作按钮

**与 C# 交互协议**：Desktop.html 通过 `window.chrome.webview.postMessage` 发送 JSON 命令，C# 通过 `core.PostWebMessageAsJson` 推送 `{ kind, ... }` 状态。支持命令详见 [6.2 HandleCommandAsync](#62-mainformcs--主控制器)。

### 6.5 PortalController.cs — 认证页控制

**文件**：[Windows/source/PortalController.cs](Windows/source/PortalController.cs) （约 269 行）

封装认证页 `WebView2` 的打开、自动填写、提交观察。核心状态机：

```
OpenAsync → Navigate(portalUrl) → DOMContentLoaded / NavigationCompleted
       ↓
    TryFillAsync（最多 80 次 × 150ms）
       ↓
    ExecuteScriptAsync(PortalScript.Build(...))
       ↓
    返回字符串状态 → 分支处理
```

#### 关键字段

| 字段 | 说明 |
| --- | --- |
| `generation` | 每次 OpenAsync / Stop +1，回调里必须校验 |
| `fillingGeneration` | 防止同一页面重复发起 FillAsync |
| `authenticationDeadline` | 提交后 30s 内观察学校登录结果 |
| `bootstrapId` | PortalBootstrap.js 的脚本句柄，每次 OpenAsync 前 Remove 再 Add |

#### 关键流程方法

| 方法 | 说明 |
| --- | --- |
| `OpenAsync(profile, password, discover)` | 停止旧状态 → 检查网络可用性 → 注入 PortalBootstrap.js → Navigate |
| `TryFillAsync()` | 入口防抖（`fillingGeneration == generation` 时跳过） |
| `FillAsync(expected)` | 80 次循环：每次检查网络/Origin 不变 → 执行 PortalScript → switch 分支 |
| `ObserveAuthenticationAsync()` | 提交后 500ms 轮询：状态为 `"authenticated"` → ConfirmAuthentication；超时 / 失败 → RequiresInteraction=true |
| `CheckAuthenticationPageAsync()` | 检查当前页面是否已登录（`/eportal/success.jsp` + `userIndex`） |

#### PortalScript 返回值分支

| 返回值 | 动作 |
| --- | --- |
| `"authenticated"` | ConfirmAuthentication |
| `"authentication-rejected"` | 提示账号/密码/服务选项问题 |
| `"submitted"` / `"already-submitted"` | finished + 启动 30s 观察 |
| `"waiting-submit"` / `"waiting-ready"` / `"missing-fields"` / `"missing-submit"` / `"missing-service"` / `"waiting-agreement"` | 继续重试（attempt < 80 时 150ms 后重跑） |
| `"manual-required"` | 有验证码或运营商额外字段，停止自动提交 |
| `"service-required"` | 网页要求选择运营商但设置里没填 |
| `"wrong-origin"` / `"invalid-selector"` | 配置问题 |

### 6.6 WifiService.cs — WLAN Native 接口

**文件**：[Windows/source/WifiService.cs](Windows/source/WifiService.cs) （约 217 行）

直接 P/Invoke `wlanapi.dll`，**避免解析本地化 netsh 输出**，也不在命令行暴露密码。

#### 静态入口（全部 Task.Run 后台线程）

| 方法 | 说明 |
| --- | --- |
| `ReadCurrentAsync(preferred)` | 读取当前连接 SSID |
| `ReadInterfaceAsync(ssid)` | 返回目标 SSID 的 WLAN 接口 Guid |
| `ReadSnapshotAsync(preferred, scan)` | 扫描 + 返回所有可见网络 |
| `JoinAsync(profile, snapshot)` | 连接目标 Wi-Fi |

#### 私有 P/Invoke 函数

| 函数 | 作用 |
| --- | --- |
| `WlanOpenHandle / WlanCloseHandle` | 打开/关闭 WLAN 句柄 |
| `WlanEnumInterfaces` | 列出所有 WLAN 接口 |
| `WlanQueryInterface(opcode=7)` | Query CurrentConnection |
| `WlanScan` | 触发一次扫描 |
| `WlanGetAvailableNetworkList` | 拉取扫描结果 |
| `WlanSetProfile` | 写入开放网络 XML 配置 |
| `WlanConnect` | 发起连接 |
| `WlanRenameProfile` | 旧版十六进制 profile 原地改名 |

#### 开放网络 XML Profile

```xml
<WLANProfile>
  <name>{SSID}</name>
  <connectionType>ESS</connectionType>
  <connectionMode>manual</connectionMode>
  <MSM><security><authEncryption><authentication>open</authentication><encryption>none</encryption></authEncryption></security></MSM>
</WLANProfile>
```

手动连接模式（不自动抢占），避免影响用户自己的加密网络配置。

#### 错误码 5 = ERROR_ACCESS_DENIED

提示用户在"隐私与安全性 → 位置"中开启定位服务。

### 6.7 Connectivity.cs + CampusNetwork — 网络可达性

**文件**：[Windows/source/Connectivity.cs](Windows/source/Connectivity.cs) （约 69 行）

#### `Connectivity.CheckAsync(interfaceId)`

- 接收一个 Guid（WLAN 或 PPPoE 接口 ID）
- 先验证 `NetworkInterface.GetAllNetworkInterfaces()` 中存在且状态为 `Up`
- 然后 `Ping.SendPingAsync("www.baidu.com", 3000)`
- 使用系统路由（VPN 路由由 Windows 决定），超时 6s

#### `CampusNetwork`

静态类，负责**有线链路检测**（必须在 DHCP / PPPoE / 802.1X 分配 IP 之前就能工作）：

| 方法 | 说明 |
| --- | --- |
| `IsWiredInterface(type, status)` | `OperationalStatus.Up` 且类型为 Ethernet/GigabitEthernet/FastEthernetFx/FastEthernetT |
| `ReadLinks()` | 返回所有 `NetworkLink { Id, Name, Type, Status }` |
| `SelectEthernet(preferred, links)` | 选指定名或第一个 link up 的 |
| `SelectPpp(name, links)` | 选指定名且状态 Up 的 PPP 接口（PPPoE 完成后） |
| `ReadPhysicalLink(profile)` | 实际选哪个物理网卡 |
| `ReadWiredInterface(profile)` | PPPoE 模式返回 PPP 接口 Id，其他返回物理接口 Id |
| `IsAvailableAsync(profile)` | 组合判断：有线 → ReadWiredInterface 非空；Wi-Fi → 当前 SSID 匹配 |
| `ReadInterfaceAsync(profile)` | 返回 ping 时要探测的接口 Id |

### 6.8 WiredAuthentication.cs — 有线系统认证

**文件**：[Windows/source/WiredAuthentication.cs](Windows/source/WiredAuthentication.cs) （约 124 行）

#### `ReadBroadbandEntries()`

解析 `rasphone.pbk`（`%APPDATA%` 和 `%ALLUSERSPROFILE%`），只保留 `Type=5`（`RASET_Broadband`），排除 VPN / 模拟拨号 / 自定义连接。

#### `BuildCommand(profile, interfaceName, entries, systemDirectory)`

| 模式 | 命令 |
| --- | --- |
| `pppoe` | `rasdial.exe <name> /PHONEBOOK:<pbk path>` |
| `dot1x` | `netsh.exe lan reconnect interface=<interfaceName>` |
| `client` | 不构建命令，由 `ConnectAsync` 直接 `Process.Start` |

#### `ConnectAsync(profile, interfaceName, cancellationToken)`

- **client 模式**：先检查是否已运行（`Process.GetProcessesByName` + `MainModule.FileName` 比对完整路径），避免重复启动
- **PPPoE / 802.1X 模式**：`RunAsync` 子进程，60s 超时，超时后 Kill 进程树
- **绝不把账号密码传入命令行或日志**（rasdial / netsh 都走系统已保存凭据）

### 6.9 LocalStore.cs — DPAPI 加密存储

**文件**：[Windows/source/LocalStore.cs](Windows/source/LocalStore.cs) （约 35 行）

- 路径：`%LOCALAPPDATA%\CampusConnect\configuration.json`
- 格式：`{ "Profile": {...}, "ProtectedPassword": "<Base64(DPAPI)>"}`
- 保存流程：`Validate()` → 创建目录 → `ProtectedData.Protect(password, null, DataProtectionScope.CurrentUser)` → 临时文件 → `File.Move`（原子性）
- 迁移到其他电脑需要重新输入密码（DPAPI 绑定当前用户 + 当前机器）

### 6.10 StartupRegistration.cs — 开机自启

**文件**：[Windows/source/StartupRegistration.cs](Windows/source/StartupRegistration.cs) （约 32 行）

- 注册表路径：`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- 命令：`"<exePath>" --startup`
- 路径超过 260 字符或含引号时报错；启用后立即生效，卸载时删除该值

---

## 7. macOS 平台模块详解

所有 Swift 源码位于 `macOS/source/`，编译命令见 `build.sh`。

### 7.1 App.swift + AppModel — 主界面与编排

**文件**：[macOS/source/App.swift](macOS/source/App.swift) （约 812 行）

#### 入口

`@main struct CampusConnectApp: App` 入口：
- 支持 `--configure-from-stdin` CLI 模式（stdin 接收 JSON `{username, password}`，保存后 exit 0），用于自动化部署
- 正常启动创建 `StateObject AppModel`
- `WindowGroup` + `MenuBarExtra`（菜单栏常驻，图标随有线/无线变化）
- `AppDelegate`：登录项启动时隐藏主窗口

#### AppModel（核心编排类）

`@MainActor final class AppModel: NSObject, ObservableObject, CLLocationManagerDelegate` — 状态由 `@Published` 属性驱动 UI 自动刷新。

**关键属性**（`@Published`）：

| 属性 | 说明 |
| --- | --- |
| `draft` | 正在编辑的 CampusProfile（内存中） |
| `portalPassword` / `wifiPassword` | 当前 SSID 的密码（内存中，不在配置 JSON） |
| `page` | 当前显示的 Page（dashboard / settings / portal） |
| `currentSSID` / `wiredConnected` / `wiredLink` | 网络状态 |
| `internet` | `Bool?`：nil=未知，true=可上网，false=未联网 |
| `automatic` | 自动连接开关 |
| `launchAtLogin` | 开机自启状态 |
| `status` | 底部状态栏文本 |
| `portal` | PortalController（被 PortalPage 持有） |
| `wifi` / `wiredAuthentication` | WiFiService / WiredAuthentication |

**核心方法**（与 Windows MainForm 同构）：

| 方法 | 对应 Windows | 说明 |
| --- | --- | --- |
| `refresh(scan:)` | `RefreshAsync` | 定时 20s 触发 |
| `connect(manual:)` | `ManualConnectAsync` / `ConnectAsync` | 手动 / 自动连接 |
| `verifyInternet(openIfOffline:manual:)` | `CheckInternetAsync` | ping 后决定是否打开认证页 |
| `openPortal(discover:showPage:)` | `OpenPortalAsync` | 打开认证页 |
| `save(enable:)` | `SaveFromMessage` | 保存配置 |
| `stopAuthentication()` | `StopAuthentication` | 停止 |

#### RootView（SwiftUI 主界面）

- 侧栏 + 内容区布局（与 Windows Desktop.html 对应三个页面）
- 侧边栏悬停 280ms 延迟切换，内容区 280ms 横向滑动动画
- `.allowsHitTesting(page == model.page)` 只让当前页面接收点击
- `.textSelection(.disabled)` 防止意外选中界面文字（输入框除外）
- 底部 `v2.0.3 · macOS` + 版本号

#### PortalPage

- 系统认证模式：显示说明 + 立即连接按钮 + 打开网络设置按钮
- 网页认证模式：`PortalWebView`（NSViewRepresentable 包装 WKWebView）+ 立即认证/探测地址/检查上网按钮 + 当前认证地址显示

### 7.2 Portal.swift — 认证页控制

**文件**：[macOS/source/Portal.swift](macOS/source/Portal.swift) （约 250 行）

`final class PortalController: NSObject, ObservableObject, WKNavigationDelegate`

#### 与 Windows PortalController 差异

| 差异 | Windows | macOS |
| --- | --- | --- |
| 浏览器 | `WebView2` in-process | `WKWebView` |
| 会话隔离 | 隐私会话（WebView2 级别） | `.nonPersistent()` WKWebsiteDataStore |
| 认证页网络路由 | 由 WebView2 `--no-proxy-server` 绕过 HTTP 代理 | 本地 `CampusProxy` loopback HTTP CONNECT 代理 + `NWParameters.requiredInterface` 绑定物理网卡 |
| 脚本注入 | `AddScriptToExecuteOnDocumentCreatedAsync` | `WKUserScript(.atDocumentStart)` |
| 填写脚本来源 | 嵌入资源 PortalTemplate.js | Swift 内 `PortalScript.build(...)` 直接拼接（PortalTemplate + agreementScript） |
| 状态轮询间隔 | 500ms（ObserveAuthenticationAsync） | 500ms（`pollAuthentication`） |
| 最大填写重试 | 80 次 × 150ms | `PortalFillRetry.maxAttempts = 200` × 0.15s（更保守） |

#### PortalWebView

`NSViewRepresentable` 包装器：把 `portal.webView`（WKWebView）桥接到 SwiftUI，保持 `controller.webView.frame` 跟随父视图。

### 7.3 WiFi.swift — CoreWLAN 封装

**文件**：[macOS/source/WiFi.swift](macOS/source/WiFi.swift) （约 103 行）

#### WiredNetwork（单例）

`NWPathMonitor(requiredInterfaceType: .wiredEthernet)` 持续监听有线链路变化：

| 属性 | 说明 |
| --- | --- |
| `available` | path.status == .satisfied |
| `interfaces` | path.availableInterfaces |
| `onChange` | 状态变化回调（AppModel 订阅） |

#### WiFiService

所有操作通过独立串行队列 `local.campusconnect.wifi` 执行，然后回到主线程回调。

| 方法 | 说明 |
| --- | --- |
| `readConnection(profile:)` | 组合判断（Wi-Fi 模式看 SSID，有线模式看 WiredSystem.connected） |
| `scan(preferred:completion:)` | `CWWiFiClient.shared().interface().scanForNetworks`；若当前已在 preferred SSID，则使用 `cachedScanResults()` 更快 |
| `connect(profile:password:completion:)` | `interface.associate(to:password:)` / `.associate(toEnterpriseNetwork:)` |
| `static currentSSID` | 直接读取当前 SSID |

#### VisibleNetwork / WiFiSnapshot

- `VisibleNetwork(ssid, signal(dBm, RSSI), security)`：security 归类为"开放" / "加密" / "企业认证"
- `WiFiSnapshot(current, powered, networks, hiddenCount)`：hiddenCount 统计 SSID 为空的隐藏网络

### 7.4 WiredAuthentication.swift + WiredSystem — 有线系统

**文件**：[macOS/source/WiredAuthentication.swift](macOS/source/WiredAuthentication.swift) （约 159 行）

#### WiredSystem（静态工具）

| 方法 | 说明 |
| --- | --- |
| `interfaces()` | `SCNetworkInterfaceCopyAll` 过滤 Ethernet，读取 link Active 状态 + 用 `getifaddrs` 检查是否有非自环/非链路本地 IP |
| `hasAddress(name)` | 遍历网卡地址，过滤掉 169.254.x.x、127.x、fe80:: / ::1 |
| `pppoeServices()` | `SCPreferencesCreate` + `SCNetworkServiceCopyAll` 过滤 PPP → Ethernet 基础接口 |
| `selected(profile, from:)` | PPPoE 模式先找到 service 再取其物理接口；其他模式按名称匹配或取第一个 link up |
| `connected(profile)` | PPPoE 模式查 `SCNetworkConnectionGetStatus`；其他模式看 `selected.hasAddress` |

#### WiredAuthentication（@MainActor 类）

| 模式 | 实现 |
| --- | --- |
| `.dot1x` | 不执行命令，提示在系统设置启用自动连接；manual 时打开 `x-apple.systempreferences:com.apple.Network-Settings.extension` |
| `.pppoe` | `Process("/usr/sbin/networksetup", ["-connectpppoeservice", name])`，15s 超时 |
| `.client` | `NSWorkspace.shared.runningApplications` 去重后用 `openApplication(at:configuration:)` 启动 `.app` |

#### WiredInterface

```swift
struct WiredInterface: Equatable, Identifiable {
    let name: String          // BSD name 如 en5
    let title: String         // 本地化显示名 + BSD name
    let linked: Bool          // 物理链路 Active
    let hasAddress: Bool      // 是否有有效 IP
}
```

### 7.5 Connectivity.swift — ping 联网检测

**文件**：[macOS/source/Connectivity.swift](macOS/source/Connectivity.swift) （约 31 行）

- 后台队列启动 `Process("/sbin/ping", ["-n", "-c", "1", "-W", "3000", "-t", "5", "www.baidu.com"])`
- 6s 总超时，超时后 `process.terminate()` → 1s 后仍没退出 → `SIGKILL`
- 返回 `.online` 需 exit code == 0 + exitReason == .exit

### 7.6 CampusProxy.swift — 物理网卡绑定代理

**文件**：[macOS/source/CampusProxy.swift](macOS/source/CampusProxy.swift) （约 167 行）

macOS 的 WebKit 浏览器**不支持**直接指定出站网卡（Windows 用 `--no-proxy-server` 绕过），所以通过一个本地 loopback HTTP CONNECT 代理强制所有校园认证页请求走指定物理网卡。

#### 工作原理

```
WKWebView → HTTP CONNECT 127.0.0.1:<port> → CampusProxy listener
                                                      ↓
                                            解析 HTTP 头 /CONNECT host:port HTTP/1.1
                                                      ↓
                                            允许 host 在白名单内 + 无用户凭据
                                                      ↓
                                            NWConnection(host, port,
                                               requiredInterfaceType: .wifi / .wiredEthernet,
                                               requiredInterface: 指定网卡,
                                               preferNoProxies: true)
                                                      ↓
                                            双向 pump() 数据
```

#### 安全边界

- 只监听 127.0.0.1（loopback only）
- 白名单 host（portalURL.host + 可选的 captive 探测 host）+ 无 user/password
- 非 CONNECT 模式（HTTP）：重写 host 头，去掉 `Connection: proxy-connection proxy-authorization`
- 任何违反 → 返回 `HTTP/1.1 403 Forbidden`
- 无 TLS 解密（只转发，不 MITM）

#### 与 WKWebView 集成

```swift
// Portal.swift load() 方法
campusProxy.start(host: host, interfaceType: .wiredEthernet, requiredInterface: selectedInterface) { port in
    webView.configuration.websiteDataStore.proxyConfigurations =
        [ProxyConfiguration(httpCONNECTProxy: .hostPort(host: "127.0.0.1", port: port!))]
    webView.load(...)
}
```

### 7.7 Core.swift — 数据模型与 LocalStore

**文件**：[macOS/source/Core.swift](macOS/source/Core.swift) （约 502 行）

#### 枚举 JoinMode / WiredAuth

```swift
enum JoinMode: String, Codable { case open, personal, enterprise }
enum WiredAuth: String, Codable { case web, pppoe, dot1x, client }
```

#### CampusProfile

与 Windows C# record 功能对齐，但 Swift struct 不支持 default record 值的 init，所以自定义 `init(from:)` 用 `decodeIfPresent` 全部给默认值，保证旧配置也能兼容。额外字段：

| 字段 | 说明 |
| --- | --- |
| `joinMode` | Wi-Fi 连接类型（open/personal/enterprise） |
| `wifiUsername` | 企业认证用户名 |

#### LocalStore

- 路径：`~/Library/Application Support/CampusConnect/configuration.json`
- 目录权限 0700，文件权限 0600（`posixPermissions`）
- 旧配置（UserDefaults `"campus.profile"`）兼容读取
- Secrets（wifi / portal 密码）独立保存在 `credentials[ssid]` 字典
- **明文存储**（macOS 版本）—— 迁移其他 Mac 后直接可用；文件权限限制访问

#### PortalScript（Swift 版）

与 Windows 的 `PortalTemplate.js + PortalAgreements.js` 功能完全一致，但 Swift 把脚本以三引号字符串内嵌在源码里（而不是读取嵌入资源）。协议勾选脚本是单独的 `agreementScript` 静态常量，通过 `.replacingOccurrences(of: "  /*CAMPUS_AGREEMENTS*/", with:)` 注入。

---

## 8. JavaScript 认证脚本

两套平台运行**功能同源**的认证脚本（Windows 用嵌入资源，macOS 用 Swift 字符串内嵌），职责是：在学校认证页面 DOM 就绪后，自动识别账号/密码/登录按钮、选择运营商、勾选协议、触发登录按钮、观察学校的加密处理流程。

### 8.1 PortalTemplate.js (Windows) — 填写与提交

**嵌入资源**，由 `Core.PortalScript.Build()` 组装。执行时替换 `/*CAMPUS_CONFIG*/` 为 JSON（origin、用户名、密码、服务选项、选择器），再替换 `/*CAMPUS_AGREEMENTS*/` 为协议勾选脚本。

#### 关键返回值（见 6.5 PortalScript 返回值分支）

#### 核心识别策略

**账号/密码输入框识别**（双重策略）：

1. **锐捷 ePortal 硬编码**：先查 `#username`（type=text）+ `#pwd`（type=password）+ `#loginLink`（anchor，有 `onclick="doauthen()"`）—— 最知名的校园网认证页
2. **通用策略**：在密码框的 `form` 范围内找：
   - 账号框：type 排除 password/hidden/checkbox/radio/submit/button；匹配 `user|account|student|phone|login|学号|账号|手机` 关键词
   - 密码框：`input[type="password"]`，editable + visible
   - 按钮：匹配 `/^(登录|登陆|认证|连接|login|log in|sign in|connect)/` 或 `#loginLink`

**运营商选择**（三种控件类型）：

1. **ePortal 动态菜单**：`#serviceShowHideTop` 点击展开 → 匹配 `#serviceShowHide [id^="bch_service_"]` 行 → 按文字精确匹配 → 点击 → 验证 `#selectDisname.textContent` 已变成目标值
2. **原生 select**：按 `selectedIndex` + 触发 input/change 事件
3. **radio / 自定义 radio**：匹配 label 文字（含 aria-labelledby / FONT 标签文字注释）→ `.click()` 触发学校原有事件 → 验证选中

**值的设置**：不用 `.value = xxx`（学校加密逻辑可能覆盖），而是：

```javascript
const setter = Object.getOwnPropertyDescriptor(
  HTMLInputElement.prototype, 'value').set;
setter.call(input, value);
input.dispatchEvent(new Event('input', {bubbles:true}));
input.dispatchEvent(new Event('change', {bubbles:true}));
```

**锐捷 ePortal 特殊处理**：

- 登录按钮是 anchor（`#loginLink`）而非 button，且真实输入框被隐藏、只读提示框叠在上面（`#username_tip` / `#pwd_tip`）
- 通过对 tip 触发 focus → focusin → click 三次事件，让学校自己的 reveal handler 把隐藏输入框变为可见
- 密码框激活：原生 `focus()` 在后台 WebView 里可能不生效，所以依次调用 tip.focus() + dispatchEvent

**登录触发**：`portalButton` + `onclick` 包含 `doauthen` 时：

1. 包装 `window.doauthen` 和 `window.AuthInterFace.login`：
   - 观察学校的 handler 是否启动（`handlerStarted` + 8s 超时）
   - 观察 login callback 里是否返回 `result === 'success'` 或 `'fail'`
2. 先 blur + focus 让布局完成 → 返回 `waiting-submit`
3. 两次激活尝试：
   - 第一次 `.click()`（适配原生 click handler）
   - 第二次 `dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true}))`（适配事件委托）
4. 两次都没触发 → 直接调用 `window.doauthen.call(submit)`

#### 状态去重标记

| 标记 | 说明 |
| --- | --- |
| `window.__campusSubmitted` | 已触发提交（防重复） |
| `window.__campusSubmitAttempt` | 记录 clicks / handlerStarted / result / failed / startedAt |
| `window.__campusReady` | ePortal pageInfo / getServices 就绪状态 |
| `window.__campusServiceMenus` | WeakMap 记录已展开的动态菜单，避免重复点击 |
| `window.__campusCustomServiceMenus` | 自定义动态菜单的展开记录 |
| `window.__campusServiceRadioAttempt` | radio 选择已尝试 |
| `window.__campusAgreementAttempts` | 协议勾选的 2s 去重 |

### 8.2 PortalBootstrap.js — ePortal 初始化加速

**嵌入 bundle（macOS）/ 嵌入资源（Windows 从 macOS 路径引用）**。注入时机：`DOMContentLoaded`（`.atDocumentStart`）。

功能：

1. 仅在 `window === window.top` 且 origin 匹配时执行（防 iframe 污染）
2. 检测 `window.onload` 是否为标准锐捷签名 `fillData(); getServices(); autosize();`
3. 检测 `#loginLink` 和 `AuthInterFace.pageInfo / getServices` 是否存在
4. 满足条件后，**提前**在 DOMContentLoaded 时调用 `window.onload.call(window)`（原 handler 会调 `fillData / getServices / autosize`）
5. 包装 `AuthInterFace.pageInfo / getServices` 的回调，标记 `__campusReady = {pageInfo: true, getServices: true}`，使主脚本不用等背景图加载完就能提交登录

### 8.3 PortalAgreements.js (Windows) — 协议勾选

**嵌入资源**。识别并自动勾选：

1. 在密码框所在 form 范围找所有 `checkbox` / `[role="checkbox"]`
2. 按文字过滤掉可选项：`记住|自动登录|保持登录|订阅|推广|广告|促销|营销|优惠|newsletter|marketing|remember|stay signed`
3. 只处理**必填项**：`required` / `aria-required="true"` / 或文字含 `同意|已阅读|用户协议|隐私政策|服务使用协议|使用条款|agree|accept|terms|privacy`
4. 2s 去重（`__campusAgreementAttempts` WeakMap）避免重复触发

### 8.4 macOS 内嵌 PortalScript.build — Swift 版脚本

Swift 版把 PortalTemplate.js 的 JS 代码直接以三引号字符串写在 [Core.swift](macOS/source/Core.swift) 的 `PortalScript.build(...)` 里（约第 198-467 行），与 Windows 的资源版本内容一致（因为是同一套认证逻辑）。协议勾选脚本作为静态常量 `agreementScript` 内嵌在同一文件第 468-501 行。

---

## 9. 依赖关系图

### 9.1 Windows 依赖

```
CampusConnect.csproj
├── Microsoft.Web.WebView2 (1.0.4258.31)
└── 嵌入资源
    ├── PortalTemplate.js        (C# PortalScript.Build 组装)
    ├── PortalAgreements.js      (注入到 Template 中)
    ├── PortalBootstrap.js       (从 macOS/source/ 路径引用)
    └── Desktop.html             (内嵌 UI)

WinForms 原生依赖：
├── wlanapi.dll          → WifiService (P/Invoke)
├── System.Net.NetworkInformation → Connectivity + CampusNetwork
├── System.Security.Cryptography → LocalStore (DPAPI ProtectedData)
├── Microsoft.Win32.Registry     → StartupRegistration
├── rasdial.exe / netsh.exe     → WiredAuthentication (Process.Start)
└── WebView2Runtime             → WebView2 必须安装（安装器会检测并帮助下载）
```

### 9.2 macOS 依赖

```
macOS/source/build.sh
├── Foundation, AppKit, SwiftUI
├── CoreWLAN                    → WiFiService
├── CoreLocation                → AppModel CLLocationManagerDelegate (Wi-Fi 扫描授权)
├── SystemConfiguration         → WiredSystem (SCNetworkInterface*)
├── WebKit                      → PortalController WKWebView
├── Network                     → CampusProxy (NWListener / NWConnection / NWPathMonitor)
├── ServiceManagement           → AppModel SMAppService (登录项)
├── CoreServices                → AppDelegate (AEKeyword)
├── UniformTypeIdentifiers      → PortalPage NSOpenPanel
├── process /usr/sbin/networksetup → WiredAuthentication
├── process /sbin/ping          → Connectivity
└── macOS 14+ SDK                (target arm64/x86_64)
```

### 9.3 跨共享层依赖

```
PortalTemplate.js ──→ PortalScript.Build (Windows)
      ↑ 同源
PortalScript.build (macOS Core.swift)

PortalBootstrap.js ──→ Windows (嵌入资源 from macOS 路径)
                    ──→ macOS (bundle resource)
```

### 9.4 运行时依赖图

```
┌──────────────┐     ┌────────────────┐     ┌──────────────────┐
│  AppModel /  │────→│ WifiService /   │────→│ NetworkInterface  │
│  MainForm    │     │ WiredAuth      │     │ / CWWiFiClient    │
└──────┬───────┘     └────────────────┘     └──────────────────┘
       │
       │ OpenAsync
       ↓
┌──────────────┐     ┌────────────────┐     ┌──────────────────┐
│ PortalCtrl   │────→│ PortalScript   │────→│ 学校认证页面 DOM   │
│ WebView2/    │     │ (Template +    │     │ + AuthInterFace    │
│ WKWebView    │     │  Agreements +  │     │ + networksetup     │
└──────┬───────┘     │  Bootstrap)    │     │ / rasdial / netsh  │
       │             └────────────────┘     └──────────────────┘
       │ 观察 submit result
       ↓
┌──────────────┐     ┌────────────────┐
│ Connectivity │────→│ 百度 ping      │
│ Ping         │     │ (系统路由)      │
└──────────────┘     └────────────────┘
```

---

## 10. 构建与运行

### 10.1 开发环境要求

| 平台 | 要求 |
| --- | --- |
| Windows 构建 | .NET 10 SDK + Windows（x64）；交叉编译 x64→ARM64 也可在 Windows 上做 |
| Windows 安装包 | 额外需要 [NSIS](https://nsis.sourceforge.io/Download) + Python 3 |
| Windows 运行 | Windows 10/11 64 位；首次运行需要 WebView2 Runtime（安装器会自动检测并引导安装） |
| macOS 构建 | macOS 14+ + Xcode Command Line Tools (`xcode-select --install`) |
| macOS 运行 | macOS 14+；Apple 芯片或 Intel 均可（通用包） |

### 10.2 Windows 构建

```powershell
# 测试
dotnet run --project Windows/tests -c Release

# 发布单文件
powershell -ExecutionPolicy Bypass -File Windows/build.ps1 -Runtime win-x64
# 或 ARM64
powershell -ExecutionPolicy Bypass -File Windows/build.ps1 -Runtime win-arm64

# 交叉编译（在 macOS / Linux 上也能做）
dotnet publish Windows/source/CampusConnect.csproj -c Release -r win-x64 `
  --self-contained true -p:PublishReadyToRun=true -o Windows/dist/win-x64

# 生成 NSIS 安装包（需要 NSIS + Python）
powershell -ExecutionPolicy Bypass -File Windows/build-installer.ps1 -Runtime win-x64
# 输出：Windows/installer/dist/CampusConnect-Windows-x64-Setup.exe
```

### 10.3 macOS 构建

```bash
# 测试
zsh macOS/test.sh
zsh macOS/test-webkit.sh

# 构建（自动 arm64 + x86_64 + lipo 合成通用包 + codesign 本地签名）
zsh macOS/source/build.sh
# 输出：macOS/CampusConnect.app
```

### 10.4 运行

- **Windows**：双击 `CampusConnect.exe` 或安装后的"校园 Wi-Fi 助手"开始菜单入口；关闭窗口 → 保留托盘；右键托盘可暂停自动连接 / 退出
- **macOS**：打开 `CampusConnect.app`；关闭窗口 → 保留菜单栏（图标随有线/无线变化）；菜单栏菜单：打开主窗口 / 自动连接 / 刷新 / 退出
- 首次使用：在"校园网设置"里选择 Wi-Fi 或有线模式 → 填写认证地址/账号密码 → 保存 → 点击"立即连接"

### 10.5 生成干净源码包

```bash
python3 scripts/package-source.py
```

打包时排除个人配置、浏览器数据、.vs/bin/obj 等产物。

---

## 11. 测试体系

### 11.1 Windows 测试

```
Windows/tests/
├── CampusConnect.Tests.csproj   # .NET 单元测试
│   └── Program.cs
├── portal.test.mjs              # Node + Playwright: PortalTemplate.js 核心回归
├── *.test.cjs                   # 各场景浏览器模拟回归
│   ├── desktop.test.cjs         # Desktop.html 布局/命令桥
│   ├── wired.test.cjs           # 有线模式设置切换
│   ├── agreements.test.cjs      # PortalAgreements.js 勾选识别
│   ├── eportal.test.cjs         # 锐捷 ePortal 完整认证流程（469 行，最详尽）
│   ├── portal-early.test.cjs   # 提前初始化场景
│   ├── recovery.test.cjs        # BrowserRecovery 状态机
│   └── performance.test.cjs    # 80 次重试性能基线
└── fixtures/
    └── cmcc-font-radio.html     # 运营商 font 标签 radio 测试夹具
```

#### 覆盖率重点

- **.NET 单元测试**：`WifiService.OpenProfileXml`、`WiredAuthentication.ParsePhonebook`、`CampusProfile.Origin`、`AutoPolicy.ShouldJoin`、`PortalRecovery.RetryDelay` 递增退避验证
- **PortalTemplate.js 回归**：覆盖 80 次重试、radio/font 标签、ePortal 动态菜单、隐藏输入框、focus 事件链、AuthInterFace.login 观察、origin 不匹配阻止填写
- **Desktop.html 布局**：Playwright 启动 Chromium 加载本地 HTML fixture，测三个页面切换、portalBounds 缩放、状态推送

### 11.2 macOS 测试

```
macOS/test.sh           # Core.swift 的 CampusProfile / AutoPolicy / PortalRecovery / LocalStore / PortalScript（JS 拼接）
macOS/test-webkit.sh    # 原生 WKWebView 加载 PortalBootstrap.js + PortalScript，检查首次提交链路
```

- `test.sh`：纯 Swift 逻辑（不需要运行时 UI），在 GitHub Actions 的 `macos-14` runner 上直接跑
- `test-webkit.sh`：启动 WKWebView 后 evaluate 脚本，检查状态字符串

---

## 12. GitHub Actions CI

**文件**：[.github/workflows/build.yml](.github/workflows/build.yml)

触发条件：push main/master、tag `v*` / `windows-v*`、PR、manual dispatch。

### macOS job（macos-14 runner）

```
checkout → test.sh → test-webkit.sh → build.sh → ditto zip → upload-artifact
```

### Windows 矩阵（x64 on windows-latest, ARM64 on windows-11-arm）

```
checkout → setup-dotnet 10.0.x + setup-node 22
  → dotnet run --project Windows/tests      (.NET 单元测试)
  → node Windows/tests/portal.test.mjs      (Node Playwright 核心脚本)
  → npm install playwright + chromium
  → foreach test in desktop/wired/agreements/recovery/eportal/portal-early/performance (.cjs 浏览器回归)
  → choco install nsis
  → python Windows/installer/test-manifest.py
  → ./Windows/build-installer.ps1
  → ./Windows/installer/smoke-test.ps1      (安装/修复/升级/卸载冒烟)
  → upload-artifact Setup.exe + 诊断文件
```

---

## 13. 配置与存储

### Windows

| 项目 | 路径 | 加密方式 |
| --- | --- | --- |
| 配置 + 密码 | `%LOCALAPPDATA%\CampusConnect\configuration.json` | DPAPI CurrentUser 加密密码，Profile 明文 + 密码 Base64 |
| WebView2 缓存 | `%LOCALAPPDATA%\CampusConnect\WebView2\` | WebView2 管理 |
| 安装目录 | 默认 `%LOCALAPPDATA%\Programs\CampusConnect` | 单文件 exe + licenses/ |
| 卸载程序 | 安装目录下 `Uninstall.exe` | — |

### macOS

| 项目 | 路径 | 权限 |
| --- | --- | --- |
| 配置 + 密码 | `~/Library/Application Support/CampusConnect/configuration.json` | 目录 0700，文件 0600 |
| App 位置 | 推荐 `/Applications/CampusConnect.app` | — |
| 本地签名 | 构建时 `codesign --sign -` | 临时签名，需要公证时另处理 |

### 配置 JSON 结构（两端统一 schema）

```jsonc
// Windows 用 ProtectedPassword (Base64)，macOS 用 credentials[ssid].portal (明文)
{
  "Profile": {                 // Windows
    "ssid": "HNPI-STU",
    "portalURL": "http://192.168.0.123",
    "username": "123456",
    "serviceOption": "中国移动",
    "autoSubmit": true,
    "automatic": false,
    "wiredAuth": "web",
    "ethernetName": "",
    "broadbandName": "",
    "authenticationClient": "",
    "portalEnabled": true,
    "userSelector": "",        // 高级，留空自动识别
    "passwordSelector": "",
    "submitSelector": ""
  },
  "ProtectedPassword": "<Base64(DPAPI)>"
}
// macOS: LocalConfiguration { profile, credentials: { ssid: Secrets(wifi, portal) } }
```

### 迁移

- Windows → Windows：DPAPI 解密依赖同一用户 + 同一机器；跨机器需要重新输入密码
- macOS → macOS：JSON 明文 + 权限 0600，可以直接复制到新机器的 `~/Library/Application Support/CampusConnect/`
- Windows ↔ macOS：格式不同，必须重新配置

---

## 14. 术语表

| 术语 | 说明 |
| --- | --- |
| **CampusProfile** | 用户的校园网配置（SSID、认证地址、账号、认证方式） |
| **PortalScript** | 注入到学校认证页面的 JS 脚本（填账号密码、选运营商、点登录、观察结果） |
| **PortalBootstrap.js** | ePortal 初始化加速脚本，让 AuthInterFace.pageInfo/getServices 提前执行 |
| **PortalAgreements.js** | 自动勾选必填协议项/必选框的脚本 |
| **PortalController** | 封装认证页 WebView2/WKWebView 的打开、填写、观察 |
| **AutoPolicy** | 自动连接节流状态（60s 间隔） |
| **PortalRecovery** | 认证失败递增退避状态机（60→120→240→300s） |
| **DPAPI** | Windows Data Protection API，CurrentUser scope 加密密码 |
| **WLAN Native API** | `wlanapi.dll` P/Invoke，Windows 原生 Wi-Fi 管理 |
| **CoreWLAN** | macOS 原生 Wi-Fi 管理框架 |
| **NWPathMonitor** | macOS 网络路径监听（monitor 有线 link up/down） |
| **SMAppService** | macOS 登录项管理（`.register()` / `.unregister()`） |
| **Captive Portal** | 未认证时学校网络的强制跳转页面（通常返回 `http://captive.apple.com/hotspot-detect.html`） |
| **锐捷 ePortal** | 常见校园网认证系统，特征 `#username/#pwd/#loginLink` + `AuthInterFace` + `doauthen` |
| **PPPoE** | Point-to-Point Protocol over Ethernet，拨号上网 |
| **802.1X** | IEEE 有线/无线认证标准，使用 EAP 协议和证书 |
| **Generation** | C# / Swift 中用来让旧异步回调失效的递增版本号 |
| **BrowserRecovery** | Windows 后台白屏/渲染进程崩溃恢复机制 |
| **CampusProxy** | macOS 的本地 loopback HTTP CONNECT 代理，强制校园认证流量走指定物理网卡（绕过 VPN 干扰） |

---

## 附录：关键源文件行数参考

| 文件 | 行数 | 语言 | 角色 |
| --- | --- | --- | --- |
| Windows/source/MainForm.cs | 490 | C# | 主窗体 + 编排（部分类） |
| Windows/source/PortalController.cs | 269 | C# | 认证页控制 |
| Windows/source/WifiService.cs | 217 | C# | WLAN Native P/Invoke |
| Windows/source/MainForm.BrowserRecovery.cs | 163 | C# | 界面恢复 |
| Windows/source/Core.cs | 111 | C# | 数据模型 + PortalScript.Build |
| Windows/source/WiredAuthentication.cs | 124 | C# | 有线系统认证 |
| Windows/source/Connectivity.cs | 69 | C# | ping + 以太网检测 |
| Windows/source/DesktopBridge.cs | 26 | C# | UI 命令桥 |
| Windows/source/LocalStore.cs | 35 | C# | DPAPI 存储 |
| Windows/source/PortalTemplate.js | 266 | JS | 核心认证脚本 |
| Windows/source/PortalAgreements.js | 32 | JS | 协议勾选 |
| Windows/source/Desktop.html | 397 | HTML/JS/CSS | 内嵌 SPA UI |
| macOS/source/App.swift | 812 | Swift | SwiftUI 主界面 + AppModel |
| macOS/source/Core.swift | 502 | Swift | 数据模型 + LocalStore + PortalScript（Swift 内嵌 JS） |
| macOS/source/Portal.swift | 250 | Swift | WKWebView 认证页控制 |
| macOS/source/WiFi.swift | 103 | Swift | CoreWLAN + WiredNetwork |
| macOS/source/WiredAuthentication.swift | 159 | Swift | 有线系统 + WiredSystem |
| macOS/source/CampusProxy.swift | 167 | Swift | 物理网卡绑定代理 |
| macOS/source/Connectivity.swift | 31 | Swift | system ping 封装 |
| macOS/source/PortalBootstrap.js | 33 | JS | ePortal 初始化加速 |
