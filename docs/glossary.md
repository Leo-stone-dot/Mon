# Glossary

本表按主题分组。定义遵循 ISO/IEC 11179-4 的六条规则，每条术语标注来源编号，编号对应文末 Sources。

## 显示器与 Space

| 术语 | 定义 | Object Class | Property | Value Domain | 来源 |
| --- | --- | --- | --- | --- | --- |
| display | display 是 macOS 连接的显示器，由显示器标识区分。 | 显示器 | 连接与标识 | 已连接、未连接 | S29 |
| desktop | desktop 是 Space 类别，表示用户创建并在同一显示器内切换的工作区域。 | Space 类别 | 用户归属 | 用户桌面、非用户桌面 | S37 |
| Space | Space 是 macOS 图形系统管理的屏幕区域，包含用户桌面、全屏应用空间与系统空间。 | 屏幕区域 | 类别 | 用户桌面、全屏应用空间、系统空间 | S36 |
| Space UUID | Space UUID 是字符串，标识一个 macOS 桌面。 | 字符串 | 桌面标识 | 系统提供的值、空字符串（无稳定标识的桌面） | S19, S36 |
| Space state key | Space state key 是字符串，用作布局、布局索引与 tiling 状态的存储键。 | 字符串 | 存储键取值 | Space UUID、`display:` 加显示器标识 | S36 |
| user Space classification | user Space classification 是判定规则，表示一个 Space 是否属于用户桌面。 | 判定规则 | 全屏标记、类型与 UUID | 带 `fs_wid` 的 Space 不是、type 4 是、type 0 是（含空 UUID）、其他类型不是 | S14, S36 |
| Space contract probe | Space contract probe 是运行时检查，验证 screen descriptions 与 Space 字典能否解析并包含 user Space。 | 运行时检查 | 健康状态 | `ok` 加 user Space 数量、`failed` 加原因 | S11 |
| Space reflow policy | Space reflow policy 是判定规则，决定窗口重排是否因当前桌面信息而继续。 | 判定规则 | 重排许可 | tiling 禁用、非用户桌面、已知不匹配、桌面信息不可用、允许 | S23 |
| active window fallback | active window fallback 是筛选规则，在桌面标识不可用时按显示器、窗口活动状态和浮动状态选择可平铺窗口。 | 筛选规则 | 窗口集合 | 按桌面过滤、按显示器过滤 | S23 |
| screen topology client | screen topology client 是系统边界适配器，提供可用显示器、独立桌面开关和显示器描述。 | 系统边界适配器 | 显示器拓扑查询 | 显示器列表、独立桌面开关、描述可用或不可用 | S29 |
| Space command availability | Space command availability 是状态值，表示 Space 相关命令当前是否可执行。 | 状态值 | 可执行性 | `available`、`disabled` 加失败原因 | S3 |
| Space tiling action | Space tiling action 是状态菜单动作，切换一个显示器和 Space 组合的布局管理状态。 | 菜单动作 | 目标 tiling 状态 | Space 不可用、禁用 tiling、启用 tiling | S33 |
| per-space layout index isolation | per-space layout index isolation 是行为，表示每个 Space state key 保存并恢复独立的布局索引。 | 行为 | 隔离性 | 每个 Space state key 一个索引、切换 Space 恢复对应索引 | S17, S36 |
| layout index persistence | layout index persistence 是按 Space state key 保存当前布局索引的状态。 | 状态 | 布局索引 | 0 到布局数量减一 | S15, S36 |
| 布局选择恢复 | 布局选择恢复是状态读取过程，按存档中的 layout key 在 Space 的布局列表中定位选择。 | 状态读取过程 | 身份对应关系 | 对应条目、所选条目缺失时取首项、空列表时无选择 | S19, S38 |

## 布局

| 术语 | 定义 | Object Class | Property | Value Domain | 来源 |
| --- | --- | --- | --- | --- | --- |
| layout | layout 是窗口排列算法，由 layout key 标识。 | 算法 | 排列规则 | 内置算法、自定义脚本算法 | S19 |
| layout key | layout key 是字符串，唯一标识一种窗口排列算法。 | 字符串 | 算法标识 | 内置名称或自定义脚本名称 | S19 |
| tiling | tiling 是窗口管理状态，表示窗口是否由 layout 排列。 | 状态 | 排列控制 | 启用、停用 | S23 |
| per-desktop layout configuration | per-desktop layout configuration 是按 Space 保存 layout 选择的操作，选择后对该 Space 启用 tiling。 | 操作 | 选择与启用 | 已选择 layout、未选择 layout | S38 |
| display defaults | display defaults 是按显示器标识保存的配置，记录该显示器新 Space 使用的默认 tiling 开关与默认 layout key。 | 配置 | 默认 tiling 开关与默认 layout key | 已配置、未配置、tiling `true` 或 `false`、layout key 或空 | S36 |

## 配置、运行时与诊断

| 术语 | 定义 | Object Class | Property | Value Domain | 来源 |
| --- | --- | --- | --- | --- | --- |
| configuration load diagnostic | configuration load diagnostic 是字符串，描述配置文件路径与加载失败原因。 | 字符串 | 失败原因 | 空值、含路径的读取或解析错误文本 | S5 |
| runtime status item | runtime status item 是 status menu 中的 disabled 菜单项，展示当前运行时降级原因。 | 菜单项 | 降级说明 | 无条目、Accessibility 说明、Space 命令降级说明、布局恢复失败说明、Secure Input 说明 | S6 |
| runtime diagnostics | runtime diagnostics 是文本输出，列出 Accessibility、Secure Input、Separate Spaces 与 Space inventory 的当前状态。 | 文本输出 | 运行时状态 | Accessibility true/false、Secure Input true/false、Separate Spaces true/false、Space counts 或 unavailable | S8 |
| layout state recovery status | layout state recovery status 是状态菜单项，说明保存的布局状态未能读取且程序已采用默认布局。 | 菜单项 | 状态恢复结果 | 无条目、默认布局回退说明 | S25 |
| Secure Input status | Secure Input status 是状态菜单项，说明 macOS 安全输入正在阻止跨桌面拖动操作。 | 菜单项 | 跨桌面操作可用性 | 无条目、跨桌面拖动不可用说明 | S26 |
| login item migration notice | login item migration notice 是首次启动提示，说明旧登录项设置不会迁移。 | 提示 | 展示次数 | 未展示、已展示一次 | S9 |
| custom layout load diagnostic | custom layout load diagnostic 是错误日志，描述自定义布局文件路径与加载失败原因。 | 日志文本 | 失败原因 | 含路径的读取或解析错误 | S13 |
| Accessibility client | Accessibility client 是系统边界适配器，查询进程辅助功能信任状态并接受是否请求系统提示的输入。 | 系统边界适配器 | 信任查询与提示请求 | 提示、无提示、信任、未信任 | S28 |
| event posting client | event posting client 是系统边界适配器，创建并投递合成鼠标事件。 | 系统边界适配器 | 事件创建与投递 | 成功事件、无法创建、投递路径 | S30 |
| AppKit diagnostic initialization | AppKit diagnostic initialization 是命令行诊断开始前对共享 AppKit 应用对象的初始化。 | 初始化步骤 | 执行顺序 | 先初始化、后读取显示器状态 | S34 |

## 发布与签名

| 术语 | 定义 | Object Class | Property | Value Domain | 来源 |
| --- | --- | --- | --- | --- | --- |
| artifact manifest | artifact manifest 是 JSON 文件，记录一个发布产物的版本、构建环境、依赖 revision、二进制架构、公证 ID 与可选归档摘要。 | JSON 文件 | 发布可追溯性 | 必需字段、归档 path/bytes/SHA-256 | S21 |
| deployment floor | deployment floor 是版本值，表示发布产物允许运行的最低 macOS 版本。 | 版本值 | 最低运行版本 | 26.0（当前）、27.0（已修订） | S7 |
| Developer ID Application | Developer ID Application 是 Apple 颁发的证书类别，标识在 Mac App Store 外分发应用的开发团队。 | 证书类别 | 开发团队身份 | Apple 签发且在有效期内的团队身份 | S20 |
| notarization | notarization 是 Apple 对提交的软件执行自动检查并返回接受或拒绝结果的服务。 | 软件检查服务 | 接受状态 | Accepted、Invalid、In Progress | S20 |
| notarytool | notarytool 是 Xcode 附带的命令行工具，提交软件并查询 notarization 结果。 | 命令行工具 | 服务操作 | 保存凭据、提交、查询、取回日志 | S20 |
| Keychain | Keychain 是 macOS 提供的凭据存储系统，保存证书、私钥和密码。 | 系统服务 | 凭据存储 | 证书、私钥、密码与访问控制 | S20 |
| release preflight | release preflight 是签名发布前的检查脚本，验证签名身份与 notarytool profile。 | 验证脚本 | 前置条件 | 通过、缺少环境变量、缺少签名身份、缺少凭据 | S12 |
| 发布交接 | 发布交接是责任记录，列出维护者办理的生产资源、执行步骤和应提交的验证证据。 | 责任记录 | 责任分配 | 维护者执行、AI 实现、待提供证据 | S20 |
| local Release candidate | local Release candidate 是使用 Release configuration 构建、仅供当前开发 Mac 安装验证的软件包。 | 软件包 | 签名与分发范围 | `Amethyst Dev` 签名、本机安装、未 notarized、不可公开发布 | S35 |
| development signing identity | development signing identity 是本地代码签名身份，签名为 `Amethyst Dev`。 | 签名身份 | 签名标识 | `Amethyst Dev`、ad-hoc | S10 |
| app bundle | app bundle 是 macOS 应用目录，包含 `Contents/Info.plist` 与可执行文件。 | 文件系统对象 | 目录结构 | 含 `Contents/Info.plist`、含可执行文件 | S18 |

## 测试与工具链

| 术语 | 定义 | Object Class | Property | Value Domain | 来源 |
| --- | --- | --- | --- | --- | --- |
| stable test host | stable test host 是测试运行使用的应用宿主，带有固定 development signing identity。 | 测试宿主 | 代码身份稳定性 | `Amethyst Dev` 签名、未签名测试宿主 | S27 |
| toolchain lock verifier | toolchain lock verifier 是验证脚本，检查项目工具版本、SwiftPM revision 和非修改性 build 配置。 | 验证脚本 | 工具链可复现性 | 通过、未锁定、会修改源码 | S31 |
| implementation status report | implementation status report 是证据索引，列出改造工作包的实现状态、现有证据和剩余完成证据。 | 证据索引 | 工作包完成度 | 已实现、仅编译、需要外部证据、待处理 | S32 |
| Release custom layout validation | Release custom layout validation 是测试过程，在优化的 Release configuration 中执行 JavaScript layout fixtures。 | 测试过程 | configuration 与 fixture 执行 | Release、空 Release entitlement、通过、失败 | S24 |

## Sources

- S3: `Amethyst/Managers/WindowTransitionCoordinator.swift` defines `SpaceCommandAvailability` and `spaceCommandAvailability()`; `Amethyst/AppDelegate.swift` displays its disabled reason in the status menu.
- S5: `Amethyst/Preferences/UserConfiguration.swift` defines `ConfigurationFileLoad` and parse helpers that produce configuration load diagnostics.
- S6: `Amethyst/AppDelegate.swift` defines `RuntimeStatusPresentation` and `updateRuntimeStatusItems()`.
- S7: `Amethyst.xcodeproj/project.pbxproj` and `Scripts/verify-support-contract.sh` define the current 26.0 deployment floor.
- S8: `Amethyst/Debug/DebugInfo.swift` defines `runtimeDiagnostics()` and `spaceDiagnostics()`.
- S9: `Amethyst/AppDelegate.swift` defines `LoginItemMigrationNotice` and `presentLoginItemMigrationNoticeIfNecessary()`.
- S10: `Scripts/bootstrap-dev-signing.sh` and `Scripts/sign-dev-app.sh` create and apply the local development signing identity.
- S11: `Amethyst/Model/CGInfo.swift` defines `SpaceContractProbe`; `Amethyst/Debug/DebugInfo.swift` prints its result.
- S12: `Scripts/release-preflight.sh` performs the checks; `Scripts/test-release-preflight.sh` verifies its failure paths.
- S13: `Amethyst/Layout/Layouts/CustomLayout.swift` logs the custom layout file path on load failure.
- S14: `Amethyst/Model/Space.swift` defines `isUserSpace`; macOS 26 reports user desktops with type 4.
- S15: `Scripts/dev-build.sh` builds, signs with the development identity, and optionally relaunches; `Amethyst/Managers/ScreenManager.swift` persists `currentLayoutIndexBySpaceUUID`.
- S17: `AmethystTests/Tests/Managers/ScreenManagerTests.swift` verifies that layout indices are isolated per Space UUID and encoded for multiple Spaces.
- S18: `Amethyst/Amethyst-Info.plist` defines the bundle metadata; `Scripts/ci-archive.sh` inspects the built bundle before distribution.
- S19: `Amethyst/Managers/ScreenManager.swift` loads a Space's layouts before its selection and resolves saved indices through encoded keys; `AmethystTests/Tests/Managers/ScreenManagerTests.swift` exercises actual encoding/decoding across displays, Spaces, and changed lists.
- S20: `docs/release-maintainer-handoff.md`; Apple Developer ID and notarization documentation; local `notarytool store-credentials --help`.
- S21: `Scripts/generate-artifact-manifest.sh` records archive and dependency evidence; its self-test exercises acceptance and failure paths.
- S23: `Amethyst/Managers/ScreenManager.swift` defines `SpaceReflowPolicy`; `Amethyst/Managers/Windows.swift` selects current-display windows when Space data is unavailable; associated ScreenManager and CGSpacesInfo tests cover the degradation boundary.
- S24: `Scripts/test-release-custom-layouts.sh` runs `CustomLayoutTests` in Release configuration with `ENABLE_TESTABILITY=YES`; CI executes the script after Debug tests.
- S25: `Amethyst/AppDelegate.swift` defines `LayoutStateRestorePresentation` and adds the title to runtime status items; `docs/macos-27-support.md` documents the recovery action.
- S26: `Amethyst/AppDelegate.swift` defines `SecureInputPresentation`; `SpaceDragTransaction` fails before posting drag events when Secure Input is enabled; `docs/macos-27-support.md` documents the status item.
- S27: `Scripts/dev-test.sh` builds tests before launch, signs the Debug test host with the development identity, then runs tests without rebuilding; `.github/workflows/tests.yml` requires the `ci` runner label.
- S28: `Amethyst/Preferences/UserConfiguration.swift` defines `AccessibilityClient`; `DebugInfo` and UserConfiguration tests inject fake clients to distinguish prompted and non-prompted checks.
- S29: `Amethyst/Model/CGInfo.swift` defines `ScreenTopologyClient`; `Screens` and focus-follows-mouse receive it through `WindowManager`, and the CGSpacesInfo fixture constructs it without system APIs.
- S30: `Amethyst/Model/CGInfo.swift` defines `EventPostingClient`; Space drag, mouse-follows-focus, AX window focus, and screen focus reuse it; CGSpacesInfo tests inject its closures.
- S31: `Scripts/verify-toolchain-locks.sh` verifies Mintfile, Gemfile.lock, Package.resolved, bootstrap behavior, and the absence of an Xcode formatting phase.
- S32: `docs/macos-27-implementation-status.md` maps adaptation work packages to current source/script evidence and outstanding physical or maintainer evidence.
- S33: `AppDelegate` presents the Space tiling action; `ScreenManager` persists layout and tiling state immediately; README and support documentation describe the behavior.
- S34: `DebugInfo.separateSpacesAreEnabled()` initializes `NSApplication.shared` before reading `NSScreen.screensHaveSeparateSpaces`; `AppDelegateTests` verifies the order through injected closures.
- S35: `Scripts/ci-archive.sh` produces the arm64 Release archive; the local package was re-signed with `Scripts/sign-dev-app.sh` and enclosed in a verified DMG without production release credentials.
- S36: `Amethyst/Model/Space.swift` defines `isFullscreen` and `hasStableIdentifier`; `Amethyst/Model/CGInfo.swift` parses `fs_wid`; `Amethyst/Managers/ScreenManager.swift` keys state by `Space state key` and seeds new Spaces from `DisplayDefaults`; `Amethyst/Preferences/UserConfiguration.swift` persists `display-defaults`; `Amethyst/Preferences/DisplaysPreferencesViewController.swift` presents the per-display defaults and Space list.
- S37: `Amethyst/Preferences/DisplaysPreferencesViewController.swift` presents desktops by ordinal and follows the macOS Human Interface Guidelines for settings panes, labels, layout, and toggles; `Amethyst/View/PreferencesWindow.swift` keeps the window title in sync with the visible pane.
- S38: `ScreenManager.setLayout` enables tiling and keeps Space-specific layouts; `decodedLayouts` preserves Space-specific layouts; `DisplaysPreferencesViewController` is the single layout configuration surface after the status-menu Layouts entry and Layouts pane removal.