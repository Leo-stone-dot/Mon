# Amethyst macOS 27 Golden Gate 适配改造计划

> 状态：Proposed  
> 审计日期：2026-11-03（Asia/Shanghai）  
> 仓库基线：`development@d7b442f`  
> 目标系统：macOS 27 Golden Gate 27.2  
> 工具链基线：Xcode 27.2、macOS 27.2 SDK、Swift 6.4 compiler / Swift 5 language mode

## 1. 结论与推荐决策

本项目需要为了“用 Xcode 27 编译”而整体重写。当前 Amethyst target 以 macOS 12 为 deployment target，但本计划已按维护者决策将新支持合同收窄为 **macOS 26+、Apple silicon-only、`arm64` only**（2026-11-03 由 27+ 修订为 26+）；刚完成的 MASShortcut → KeyboardShortcuts 迁移也已经消除了一个已知旧依赖。真正决定 macOS 27 适配质量的是四条高风险边界：

1. 通过 Silica 和项目代码直接使用的 private `CGS*` / Space 接口，以及用合成 HID 事件拖动窗口跨 Space 的行为。
2. Accessibility/TCC 授权、AX observer 生命周期和多显示器坐标/Space 拓扑在 macOS 27 真机上的行为。
3. 已 deprecated 的 `LSSharedFileList` 登录项实现、旧 `SUUpdater` 接口，以及尚未固化到仓库的签名/notarization/update verification 链路。
4. 浮动 CI/tool dependencies：`macos-latest` 当前不是 macOS 27，两个 SwiftPM dependency 跟随 `master`，Lint build phase 还会执行 `swiftlint --fix` 修改源码。

目标支持范围固定为：

| Architecture | Supported macOS | 支持级别 |
| --- | --- | --- |
| Apple silicon `arm64` | macOS 26.x–27.x | Full support；26.0 是 deployment floor，26.6.2 是当前 runtime baseline；27.2 physical validation 暂缓 |
| `arm64e.x1` | macOS 27、M6+ | 本轮不单独产物化；只做兼容观察 |

> 2026-11-03 修订：按维护者决定，D2 system floor 由 27.0 改为 26.0，以便在当前 macOS 26.6.2 机器上直接测试；仍只支持 Apple silicon `arm64`，不维护 Intel/Rosetta。

新发布物将 `MACOSX_DEPLOYMENT_TARGET` 设为 26.0，并将 `ARCHS` 明确限制为 `arm64`；不生成 `x86_64` slice，不维护 Rosetta/Intel 或 macOS 25 及更早版本。最后一个 Intel-compatible artifact 保留下载但进入 end-of-support，新的 Sparkle item 必须声明 `sparkle:minimumSystemVersion=26.0`。

## 2. 官方基线

截至审计日，Apple 官方资料给出的基线为：

| 项目 | 当前官方值 | 对本项目的影响 |
| --- | --- | --- |
| 最新稳定版 macOS | macOS 27 Golden Gate 27.2 | 最终 runtime gate 必须在 27.2 真机完成 |
| 最新 Xcode | Xcode 27.2 | 固定 CI/Release toolchain，不使用未约束的“latest” |
| macOS SDK | macOS 27.2 SDK | 触发 SDK-linked AppKit 行为变化和新的 diagnostics |
| Swift | Swift 6.4 compiler；支持 Swift 5 language mode | 本轮不强制 Swift 6 language-mode migration |
| Xcode 27.2 deployment targets | macOS 12–27 | 项目主动选择 target 26.0，不再承担 macOS 25 及更早的 compatibility branches |
| macOS 27 hardware | Apple silicon Mac | 发布物只包含 arm64，不生成 x86_64/Rosetta artifact |

Apple 官方硬件表覆盖 M1 及之后的 MacBook Pro/Air、24-inch iMac、Mac mini，全部 Mac Studio、2023 Mac Pro，以及 Apple silicon MacBook Neo。最低真机基线应至少包含 M1；新硬件验证应包含一台 M6 或之后设备，但 `arm64e.x1` 优化不作为本轮的 completion criterion。

来源（均于 2026-11-03 读取）：

- [Apple Support: Find out which macOS your Mac is using](https://support.apple.com/en-us/109033)
- [Apple Developer: SDK and system requirements](https://developer.apple.com/xcode/system-requirements)
- [Apple Developer: macOS 27 Golden Gate Release Notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
- [Apple Support: macOS 27 compatible computers](https://support.apple.com/en-us/127255)
- [Apple Developer: App Store submissions for latest OS releases](https://developer.apple.com/news/?id=k1mtkt1k)

## 3. 当前实现审计

### 3.1 已有能力，不重复改造

| 能力 | 当前证据 | 结论 |
| --- | --- | --- |
| Hardened Runtime | `project.pbxproj:1054,1098` | Debug/Release 已开启；只需审计 entitlement 和发布产物 |
| Accessibility trust prompt/check | `Amethyst/Preferences/UserConfiguration.swift:785-792`、`Amethyst/Debug/DebugInfo.swift:42-48` | 已有基础授权入口；缺 runtime revoke/recovery 和 macOS 27 contract test |
| AX observation | `Amethyst/Model/Application.swift:222-224`、`ApplicationObservation.swift:88-228` | 已覆盖窗口创建、销毁、移动、缩放、聚焦、最小化等通知 |
| KeyboardShortcuts | `Amethyst/Managers/HotKeyRegistrar.swift:9-45`，commit `e65216e` | MASShortcut 已移除；只补 migration/冲突/国际键盘验证 |
| 多显示器坐标修复 | `Amethyst/Model/Screen.swift:53-74`，commit `3f9508a` | 已按 primary screen 翻转坐标；需加入拓扑回归矩阵 |
| Release target 空 entitlement | `Amethyst/Amethyst.entitlements` | Release 未携带 Debug 的 JIT/library-validation exception |
| SwiftPM lockfile | `Amethyst.xcworkspace/xcshareddata/swiftpm/Package.resolved` | 当前 checkout 可重现到 revision；project requirement 仍有 branch drift |

### 3.2 已确认 gap/risk

| ID | 严重度 | 证据 | 影响 | 处理方向 |
| --- | --- | --- | --- | --- |
| R0 | High | app/test target 仍为 macOS 12，README/appcast 还有更低 support floor | 与已确定的 macOS 26+/arm64-only 产品边界冲突 | 全部 target 提升到 26.0，显式 `ARCHS=arm64`，同步 README/appcast/release artifact |
| R1 | Critical | `CGInfo.swift:57-72,97-225`、`Screen.swift:146-169` 和 Silica 使用 private `CGS*`；Silica header 自身标注 private API | macOS update 可导致启动/Space 查询/跨 Space 行为失效 | 私有 API adapter、symbol/shape probe、fail-closed degradation、27.2 真机 contract suite |
| R2 | Critical | Silica `SIWindow.m` 用 `CGEventPost` + 固定 0.05/0.4 秒延迟模拟拖窗和切 Space | 动画时长、Secure Input、TCC 或 Mission Control 行为变化可造成鼠标卡住/窗口丢失 | 状态机、timeout/cleanup、行为 telemetry、真机压力测试；失败时禁用 throw-to-space |
| R3 | High | `AppDelegate.swift:102,131-137` → LoginServiceKit → deprecated `LSSharedFileList`；dependency README 建议使用 `SMAppService` | Start at Login 在新系统上不可预测，且 dependency 跟随 `master` | 直接改用 `SMAppService.mainApp`，删除 LoginServiceKit 和全部 legacy fallback |
| R4 | High | `AppDelegate.swift:53-67,165-168` 使用 deprecated `SUUpdater`；Info.plist 无 `SUPublicEDKey`；当前 appcast 未检出 `sparkle:edSignature` | 更新完整性、SDK 兼容和回滚链路不够显式 | 迁移 `SPUStandardUpdaterController/SPUUpdater`，启用 EdDSA feed/archive verification |
| R5 | High | `fastlane/Fastfile` 只有 archive/export；`exportOptions.plist` 只有 Developer ID export | 仓库不能证明 notarization、stapling、Gatekeeper 和 Sparkle signing | 建立可复现 release lane 和四重验证 gate |
| R6 | High | CI 仅 `macos-latest`；截至审计日它指向 macOS 26 arm64，`xcode-27` preview image 运行 27.0.1 而非 27.2 | 当前 CI 既未固定 Xcode，也未覆盖最终 runtime | 固定 SDK compile runner；27.2 physical/self-hosted runtime gate |
| R7 | High | `project.pbxproj:1233-1238,1273-1278` 中 LoginServiceKit、Silica 跟随 `master` | clean resolve 可引入未审计行为 | 移除 LoginServiceKit；Silica pin 到 tag/revision 或受控 fork |
| R8 | Medium | Lint phase 执行 `swiftlint --fix`，且每次 build 都运行；Brewfile 只有未锁定 formula | build 会修改源码，tool version 浮动；本地 SDK 27 build 被缺失 swiftlint 阻断 | Lint/check 和 format/fix 分离；pin toolchain；clean build 后 `git diff --exit-code` |
| R9 | Medium | support floor 分别为 README 10.15、appcast 11、Xcode target 12 | 用户、updater、binary 的可安装范围不一致 | 单一 support policy：本计划建议统一为 12 |
| R10 | Medium | macOS 27 SDK-linked AppKit 会改变 menu image 可见性；UI 仍以 XIB/AppKit 为主 | status/menu/preferences 可能出现视觉或键盘导航回归 | SDK 27 screenshot/keyboard/VoiceOver checklist，不要求 UI framework 重写 |
| R11 | Medium | 68 个已识别 test functions 以 layout/config 为主；只有 1 个 HotKeyManager、2 个 CGSpacesInfo、1 个 Screen test | 高风险系统边界缺少自动或半自动 contract coverage | 增加 adapter unit tests + physical-Mac integration harness |
| R12 | Medium | Debug entitlement 允许 JIT 并关闭 library validation；Release entitlement 为空 | Debug 与 Release 行为可能分叉，权限过宽可能掩盖问题 | 对 CustomLayout/JavaScriptCore 做双配置验证，删除不需要的 Debug exception |

### 3.3 本轮构建探针

审计机为 Apple silicon、macOS 26.6.2、Xcode 27.2、macOS 27.2 SDK、Swift 6.4.2。使用 SDK 27.2 的 arm64 Debug build 已成功解析并开始构建全部 14 个 SwiftPM pins，但在项目 `Lint` build phase 因本机缺少 `swiftlint` 以 exit 65 结束；因此不能声称当前源码已经通过 Xcode 27.2 compile/test。

同时观察到：

- `brew bundle check --verbose` 报告 fastlane、xcbeautify、swiftlint 未满足或需要更新。
- Xcode 报告本机 CoreSimulator framework 比 Xcode 27.2 期望版本旧；这不证明 macOS app build 失败，但应在可复现 runner 上消除环境噪声。
- 本机不是 macOS 27 runtime；任何 AX/CGS/TCC 结论都必须由 27.2 真机补证。

## 4. Scope 与 Out of Scope

### In scope

- macOS 27.x、Apple silicon、Xcode 27.2 / macOS 27.2 SDK 下的 Debug、Release、unit tests 和 arm64 archive。
- Accessibility/TCC、AX observers、window enumeration/mutation、Space/private CGS、synthetic events、多显示器/坐标。
- KeyboardShortcuts migration verification、AppKit/XIB/status menu/preferences compatibility。
- UserDefaults、YAML/JSON config、encoded layout state、custom JavaScript layouts 的向前兼容。
- Start at Login、Sparkle、Developer ID signing、Hardened Runtime、notarization/stapling。
- SwiftPM/tool dependencies、CI matrix、release gates、support docs。

### Out of scope

- 全量 Swift 6 language-mode/concurrency migration；Swift 5 mode 是 Xcode 27.2 官方支持路径。
- SwiftUI 重写、设计系统重做或 Liquid Glass 全量视觉改版。
- Mac App Store distribution；private CGS 和全局窗口管理模型与其审核/沙箱边界不一致。
- 新窗口布局、新快捷键、新配置语法等产品功能。
- `arm64e.x1` 专用 artifact 或性能优化。
- macOS 26 及更早系统、Intel/Rosetta、universal binary、`x86_64` CI/runtime support。

## 5. 分阶段 Work Packages

### WP0 — Support contract 与验收基线（P0，1–2 engineer-days）

**依赖：** 无。  
**涉及：** `README.md`、`docs/troubleshooting.md`、新 support policy、release checklist。

**预期改动**

- 冻结本计划第 1 节的 OS/architecture support matrix。
- 建立 macOS 27.2 baseline issue/checklist，记录机器型号、build、显示器/Space/TCC 设置和失败证据。
- 记录已决策的 D1/D2，并确认 D3–D5；未决定项不得被实现者静默假设。

**兼容策略**

- deployment target 明确提升到 26.0、architecture 明确收窄到 arm64；除此之外不改变 config schema 或用户数据语义。
- 新系统特性通过 availability/runtime probe 进入，旧系统保留原行为或明确降级。

**验收标准**

- support matrix、release blockers、feature degradation policy 获 maintainer sign-off。
- README/appcast/binary support floor 的目标值唯一且明确。

**测试**

- 对现有 binary/appcast/README 的 version-floor 做静态一致性检查。

**回滚/降级**

- 文档决策可在实现开始前回退；实现开始后变更 support floor 必须重新估算 WP2–WP7。

### WP1 — 可复现 Xcode 27 toolchain 与 CI（P0，2–3 engineer-days）

**依赖：** WP0。  
**涉及：** `.github/workflows/tests.yml`、`Brewfile`、`.swiftlint.yml`、Xcode Lint build phase、可选 `Gemfile/Gemfile.lock`、CI scripts。

**预期改动**

- 将 `actions/checkout@v2` 升级并 pin 到受信任 revision。
- 将浮动 `macos-latest` 拆成明确 jobs：
  - `xcode-27` arm64：Xcode 27.2 / SDK 27 compile + unit tests；在 GitHub image 未达到 27.2 runtime 时只算 SDK gate。
  - macOS 27.2 self-hosted/physical runner：只承载需要 TCC/AX/CGS 的 gated integration suite。
- 将 `swiftlint --fix` 从普通 build phase 移出；CI 只做不改源码的 lint，format/fix 作为显式 developer command。
- pin fastlane/xcbeautify/swiftlint versions；SwiftPM 使用 committed `Package.resolved` 并禁止 CI 隐式 update。
- 记录 `xcodebuild -version`、SDK、OS、architecture 和 dependency graph 到 artifact。

**兼容策略**

- Swift language mode 保持 5；先启用 compiler warnings inventory，不把 Swift 6 migration混入兼容路径。
- hosted runner 仅证明 compile/unit，不替代 GUI/TCC/Space runtime。

**验收标准**

- clean checkout 可一条命令完成 resolve → lint → build → test。
- build 前后 `git diff --exit-code` 通过。
- Release archive 经 `lipo -archs` 证明只包含 `arm64`；任何 `x86_64` slice 都使 gate 失败。
- CI 输出实际 OS/Xcode/SDK，不依赖 label 名推断。

**测试**

- Debug/Release arm64 compile；现有 68 个 test functions 全部执行。
- dependency resolution 离线/cache hit 和 fresh resolve 各跑一次。

**回滚/降级**

- 保留旧 workflow 仅作迁移期结果对照，不作为 merge/release gate；新 hosted image 不稳定时回到 macOS 27 self-hosted runner，不下调系统或恢复 Intel artifact。

### WP2 — AX/CGS/Screen 系统边界隔离与 macOS 27 contract suite（P0，5–9 engineer-days）

**依赖：** WP0、WP1。  
**涉及：** `Amethyst/Model/Application*.swift`、`Window.swift`、`CGInfo.swift`、`Screen.swift`、`Space.swift`、`Managers/WindowManager.swift`、`WindowTransitionCoordinator.swift`、`FocusFollowsMouseManager.swift`、`Events/HotKeyManager.swift`、`Managers/HotKeyRegistrar.swift`、Silica pin/fork、相关 tests。

**预期改动**

- 把直接系统调用收敛到四个 injectable adapters：`AccessibilityClient`、`SpaceClient`、`ScreenTopologyClient`、`EventPostingClient`。
- 为 private symbols 和返回 dictionary shape 做 launch-time/runtime probe；禁止 force-assume `ManagedSpaceID`、`Display Identifier`、`Current Space` 永远存在。
- `SpaceClient` 不可用时 fail closed：核心窗口发现/平铺/聚焦继续工作，throw-to-space/Space HUD 等功能明确 disabled，并输出可诊断 reason。
- 将 synthetic drag 的固定 delay 改为有状态、可取消、保证 mouse-up cleanup 的 transaction；处理 app termination、permission revoke、secure input、Space switch timeout。
- AX observer 对 `.cannotComplete`、`.invalidUIElement`、app termination/relaunch 建立 retry/backoff 和 stale-element cleanup。
- 复用现有坐标转换，不重写已修复逻辑；为 vertically offset、negative origin、scaled Retina、separate/shared Spaces 建 fixtures。
- 为 KeyboardShortcuts migration、重复注册、系统/应用 shortcut conflict、Secure Input 和 global event monitor unavailable 建立明确状态与 tests；不重复替换已经完成迁移的 shortcut library。

**兼容策略**

- 只维护 macOS 27.x CGS path；仍须每次 launch/runtime probe，因为 private API 可能在 27.x patch update 中变化。
- private API 失败不允许导致 app launch failure 或破坏鼠标按键状态。
- 不用“完全改成 public API”作为虚假承诺：public API 目前不能完整替代 Space inventory/move 能力。

**验收标准**

- 无 Accessibility 权限、权限运行中被撤销、目标 app 退出/重启时不 crash、不无限重试。
- private Space contract 被模拟为 missing symbol/missing key/unknown space type 时，核心 tiling 仍可用且相关 command 明确 disabled。
- macOS 27.2 真机完成窗口 create/destroy/move/resize/focus/minimize、Space switch/throw、多显示器 hot-plug 和 sleep/wake scenario。
- 每个 synthetic drag 路径都保证最终 mouse-up；压力测试后无 stuck drag。

**测试**

- Unit: adapter success/error/timeout、dictionary decoding、coordinate fixtures、AX lifecycle state machine。
- Contract: public AX + private CGS symbol/shape snapshot，不把 snapshot 值当稳定业务 schema。
- Physical: AppKit、SwiftUI、Electron/Chromium、Catalyst app；single/multi-display；separate Spaces on/off；Stage Manager on/off；full-screen window；ANSI/ISO/JIS keyboard；shortcut conflict 和 Secure Input。

**回滚/降级**

- runtime kill switch 只关闭 Space-dependent commands；保留普通 tiling、focus、screen move。
- 保留上一稳定版 Silica revision；新 adapter 可切回 legacy implementation 一个 release window。

### WP3 — Start at Login、dependencies 与 update API（P1，3–5 engineer-days）

**依赖：** WP1；Sparkle release verification 依赖 WP6。  
**涉及：** `Amethyst/AppDelegate.swift`、`project.pbxproj`、`Package.resolved`、`Amethyst-Info.plist`、Silica/LoginServiceKit/Sparkle references、preferences/status menu。

**预期改动**

- 直接使用 `SMAppService.mainApp.register()/unregister()` 和 `status`；状态 UI 区分 enabled/requiresApproval/notRegistered/notFound。
- 删除 LoginServiceKit adapter、package reference、lockfile pin 和所有 `LSSharedFileList` fallback，不保留 availability branch。
- Silica 改为 exact revision/tag 或项目可审计 fork；升级只能通过 WP2 contract suite。
- 迁移 deprecated `SUUpdater` 到 Sparkle 2 modern controller/updater API；稳定/canary feed 仍由配置选择。
- 对其余 SwiftPM pins 做 Xcode 27 compile/license/security/maintenance audit，只有证据支持时才升级，避免“全部更新”扩大变量。

**兼容策略**

- 新 binary 不读取或修改 legacy `LSSharedFileList` 状态。首次运行展示一次 breaking-change notice，并以 `SMAppService.status` 为唯一真相；需要 Start at Login 的用户显式重新启用。这是放弃旧系统后接受的、边界明确的一次性行为变化。
- 保持 stable/canary preference key 和 feed selection 语义。

**验收标准**

- macOS 27 上 register/unregister/status 与 System Settings 登录项状态一致；requiresApproval 有可操作提示。
- dependency graph 中不再存在 LoginServiceKit，二进制不再引用 `LSSharedFileList*` symbol。
- fresh resolve 不依赖任何 unpinned branch（若 Silica 必须临时用 branch，CI 必须校验 expected revision 并设到期条件）。
- updater 可检查 stable/canary feed，失败不会影响 app launch。

**测试**

- Unit: login-state mapping、一次性 migration notice、feed selection。
- Integration: login/logout/reboot、app moved/renamed、duplicate registration、canary toggle、no-network/bad-feed。

**回滚/降级**

- login registration 失败时只降级为 requires-action/disabled UI，不回退 deprecated API。
- Sparkle 保留旧 feed endpoint 和上一签名 key 的 key-rotation window。

### WP4 — AppKit/XIB/status UI 的 SDK 27 linked behavior（P1，2–4 engineer-days）

**依赖：** WP1、WP2 的 degradation states。  
**涉及：** `Base.lproj/MainMenu.xib`、`Preferences/*.xib`、`AppDelegate.swift`、`PreferencesWindow.swift`、layout/status HUD views、assets。

**预期改动**

- 检查 macOS 27 SDK 对 `NSMenuItem` image visibility 的 linked-on behavior；只有 icon-only item 必须显式设置 visibility。
- 让 Space/Accessibility/login degradation reason 在现有 UI 中可发现，不新增大规模设置框架。
- 修正 SDK 27 下的 clipping、focus ring、keyboard loop、contrast、scale 和 localization 问题。
- 更新 XIB tool metadata 只在 diff 可审计且确有需要时执行，避免 Xcode 自动改写噪声。

**兼容策略**

- 以 macOS 27 SDK behavior 为唯一 UI baseline；不增加旧系统 availability branches。
- 不以 SwiftUI/Liquid Glass 重写作为适配前提。

**验收标准**

- status menu、preferences、layout HUD 在 macOS 27.2 无 missing label/icon、不可达 control、截断或错误 focus order。
- VoiceOver 能读出关键状态；Full Keyboard Access 可完成主要设置。

**测试**

- macOS 26.x/27.2 light/dark、1x/2x/scaled、英文与伪本地化、VoiceOver、Full Keyboard Access。
- 对稳定窗口做 reference screenshots；视觉差异人工审批。

**回滚/降级**

- 新 appearance customization 可按 OS availability 回退到旧 XIB 样式，不影响 window management core。

### WP5 — 配置、状态恢复与 custom layouts 兼容（P1，2–3 engineer-days）

**依赖：** WP1。  
**涉及：** `Preferences/UserConfiguration.swift`、`Managers/WindowManager.swift`、`ScreenManager.swift`、`Layout/Layouts/CustomLayout.swift`、configuration/custom-layout docs 和 tests。

**预期改动**

- 固化配置 precedence：YAML (`~/.amethyst.yml` / XDG) → legacy JSON → UserDefaults/default config，保持当前公开行为。
- 为 encoded `WindowManager`/layout state 添加 version envelope 和 decode failure fallback；坏数据不得阻止 launch。
- 验证 macOS 27 文件权限/SIP/TCC 下只访问用户主动配置的路径，不尝试其他开发者 app containers。
- 对 JavaScriptCore custom layouts 同时验证 Debug/Release；确认 Release 不需要 JIT/library-validation exceptions 后，最小化 Debug entitlements。
- 对 config parse error、deleted layout file、schema drift 输出 actionable diagnostics。

**兼容策略**

- 不改现有 key、文件位置和 custom layout API；如需 schema version，只做向后读取。
- state restore 失败时回到 default layouts，不删除用户文件。

**验收标准**

- 当前 0.24.3 profile 原地升级/回滚验证按维护者决定移出当前范围；当前配置/state 的损坏回退与 Display × Space layout 持久化仍需保持。
- malformed YAML/JSON/encoded state 不 crash；用户可看到文件和错误原因。
- Debug/Release custom layout results 一致，Release entitlement 仍为最小集合。

**测试**

- Golden fixtures：empty/default、YAML、JSON、conflict precedence、old encoded state、corrupt state、missing JS、throwing JS。
- 旧版 0.24.3 profile upgrade-and-rollback test 暂不执行；不将其作为当前 macOS 26.6.2 使用/代码发布 gate。

**回滚/降级**

- 写入新 state 前保留一次可恢复 backup；旧 binary 不认识新 state 时允许忽略并回到 defaults。

### WP6 — Developer ID、Hardened Runtime、notarization 与 Sparkle supply chain（P0 release gate，3–5 engineer-days）

**依赖：** WP1、WP3、WP5。  
**涉及：** `fastlane/Fastfile`、`Gymfile`、`exportOptions.plist`、entitlements、Info.plist、release workflow、appcast generation/signing docs/scripts。

**预期改动**

- 建立显式 pipeline：archive → Developer ID sign → verify nested code → notarize (`notarytool`) → staple → Gatekeeper assess → zip → Sparkle EdDSA sign → appcast publish。
- 在 Info.plist 配置 `SUPublicEDKey`，feed/archive 添加并验证 `sparkle:edSignature`；所有 feed/release notes/enclosure URL 使用 HTTPS。实现上由 release pipeline 从 `SPARKLE_PUBLIC_KEY` 在归档后注入 built Info.plist，并由 `release-preflight.sh --post-archive` 在签名前校验；source Info.plist 不保存生产公钥。
- 新 appcast item 显式声明 minimum macOS 26.0；保留最后一个 Intel-compatible item/artifact 供旧系统停留，但不再继续维护或向其提供新版本。
- 将 signing identity/team/keychain profile 作为 CI secret inputs，日志不得输出凭据。
- 生成 artifact manifest：version/build、commit、OS/Xcode/SDK、architectures、dependency revisions、SHA-256、notarization submission ID。
- 审计 Debug entitlement 中 `allow-jit`/`disable-library-validation` 的必要性；Release 不新增无证据 entitlement。

**兼容策略**

- key rotation 支持 old+new 验证窗口；旧客户端仍能获取最后一个兼容 update。
- stable/canary 分开 appcast 和 release approval，不共享误发布状态。

**验收标准**

- `codesign --verify --deep --strict --verbose=2`、`spctl --assess --type execute --verbose=4`、`stapler validate` 全通过。
- 下载后的 ZIP 经 Sparkle public key verification，篡改一个 byte 必须失败。
- `lipo -archs` 只返回 `arm64`；Info.plist minimum version、target、README、appcast 均为 macOS 26.0。
- 在一台无开发证书的 clean macOS 27.2 Mac 上下载、首次启动、授权、更新、重启成功。

**测试**

- Happy path + expired cert/wrong team/missing nested signature/failed notarization/bad staple/bad EdDSA/offline/rollback feed。
- Stable → newer stable、stable → canary opt-in、canary → stable policy scenario。

**回滚/降级**

- appcast 保留上一 notarized artifact；新 artifact 任一 gate 失败即不 publish。
- publish 后发现 runtime blocker，先从 feed 撤下并发布已签名 hotfix，不远程执行未签名脚本。

### WP7 — macOS 27.2 validation matrix 与 release candidate soak（P0 release gate，4–6 engineer-days）

**依赖：** WP2–WP6。  
**涉及：** integration harness、test fixtures、manual checklist、CI/self-hosted runners、release report。

**测试矩阵**

| 维度 | 必测值 |
| --- | --- |
| OS / architecture | macOS 26.0 arm64（deployment floor，含 26.6.2 当前测试机和当前 runtime baseline）；macOS 27.2 arm64（暂缓的后续验证） |
| Apple silicon | M1 oldest baseline；一台当前代/M6+；laptop + desktop 至少各一 |
| Displays | single；built-in+external；2 external；vertical offset；negative origin；scaled Retina；hot-plug |
| Spaces | separate Spaces on/off；1/多 Space；full screen；Stage Manager on/off；Mission Control animation setting variants |
| Permissions | fresh install denied/granted；runtime revoke；TCC reset；Screen Recording not granted（应不被误要求） |
| Target apps | AppKit、SwiftUI、Electron/Chromium、Catalyst、不可 resize window、dialog/sheet、full-screen app |
| Lifecycle | launch/login/reboot；sleep/wake；display sleep；target app crash/relaunch；Amethyst update/relaunch |
| Configuration | defaults；YAML；JSON；custom JS；corrupt state；Display × Space layouts（旧版 0.24.3 profile 暂不验证） |

**预期改动**

- 将 deterministic 部分自动化；TCC、display、Space、login/reboot 保持受控 physical-Mac suite，不伪装成普通 unit test。
- 记录每个 scenario 的 machine/OS/build/config、预期、实际、日志/截图和 pass/fail。
- RC 在日常工作负载下 soak 48 小时，期间至少覆盖 sleep/wake、monitor reconnect 和多次 Space/window churn。

**兼容策略**

- 同一 RC artifact 跨矩阵验证，禁止为某个 OS 临时制作不可追溯的特殊 binary。
- 自动化覆盖不到的 TCC/Space/display lifecycle 使用同一版本化 checklist 和 evidence schema；不以“手工测过”但无机器/系统/build 记录作为通过。
- M1 与当前代/M6+ 使用同一 arm64 artifact，避免按机型制作不可追溯的特殊 binary。

**验收标准**

- P0 scenarios 100% pass；P1 failure 有 owner、workaround、ship/no-ship decision。
- crash/hang/stuck input 为 0；Space 功能若被降级，core tiling 仍通过。
- CPU/memory/event monitor 无相对当前稳定版的显著持续回退；阈值在首轮 baseline 后固化。

**回滚/降级**

- RC 不自动推 stable；任一 Critical failure 回到对应 WP。
- 仅 private Space path 失败时允许 ship core-compatible build，但必须由 maintainer 明确批准并在 release notes 标注。

### WP8 — 文档、support 和 rollout（P1，1–2 engineer-days）

**依赖：** WP0、WP7。  
**涉及：** `README.md`、`docs/troubleshooting.md`、configuration/custom-layout docs、issue template、release notes。

**预期改动**

- 将安装要求统一为 macOS 26.0+、Apple silicon-only，并明确新 artifact 不含 Intel/Rosetta support。
- 发布 Intel/macOS 26 end-of-support notice，保留最后兼容版本下载链接；Sparkle 必须让旧系统停留在该版本而不是下载 arm64-only update。
- 更新 Accessibility、Login Items、故障诊断的 System Settings 路径和截图。
- 记录 Space/private API degradation、日志收集、TCC reset 和 safe rollback 方法。
- Bug template 增加 exact OS build、Mac model/chip、display topology、separate Spaces/Stage Manager、permission state、Amethyst build。

**兼容策略**

- 文档按 architecture + OS range 表述，不再使用含糊的“latest macOS supported”。
- 已公开的 config、shortcut 和 rollback 文档保留旧版本入口；新版说明不得让旧系统用户执行只在 27 可用的步骤。

**验收标准**

- 新用户可按文档完成安装、授权、登录启动和 update。
- support 信息与 binary/appcast/CI contract 一致。

**测试**

- 链接检查、support-floor 静态一致性检查、clean-machine 安装步骤 dry run。
- 由未参与实现的 reviewer 按文档完成 fresh install、TCC grant、login registration、update 和 rollback。

**回滚/降级**

- stable rollout 分 canary → 小比例/观察窗口 → stable；文档始终保留上一版本下载/回退说明。

## 6. 依赖顺序与工作量

```text
WP0 Support contract
 └─ WP1 Toolchain/CI
     ├─ WP2 AX/CGS/Screen contracts ─┐
     ├─ WP3 Login/dependencies/update ├─ WP7 Validation/soak ─ WP8 Rollout
     └─ WP5 Config/state ─────────────┤
WP2 degradation states ─ WP4 UI ─────┤
WP3 + WP5 ─ WP6 Release supply chain ┘
```

## 7. Release gates

| Gate | 必须证明的事实 | Authoritative evidence |
| --- | --- | --- |
| G0 Toolchain | Xcode 27.2/SDK 27.2 clean build/test 可复现，build 不改源码 | CI logs、tool versions、`git diff --exit-code` |
| G1 Core runtime | AX denied/granted/revoked、window lifecycle、多显示器 core tiling 通过 | macOS 27.2 physical test report |
| G2 Space safety | CGS contract 通过或明确降级；无 stuck drag/input | contract logs、stress/soak report |
| G3 Services/state | login、Sparkle、config/state migration 通过 | integration tests、upgrade profile artifacts |
| G4 Distribution | arm64-only、minimum macOS 26.0、Developer ID、notarization、staple、Gatekeeper、EdDSA 全通过；当前发布事务暂缓 | signed manifest、notary result、verification command outputs |
| G5 Product/support | support floor、docs、appcast、binary 一致 | static consistency check、maintainer sign-off |

只有 G0–G5 全部有证据时，才能宣称“完成 macOS 27 适配”。单次编译通过、unit tests 通过或在 macOS 26 上运行正常都不足以替代 G1/G2/G4；macOS 26 结果不再构成新版本的 compatibility evidence。

## 8. 已确定与待人工决策的事项

已确定：

- D1 Architecture：Apple silicon-only，artifact 只含 `arm64`。
- D2 System floor：macOS 26.0（2026-11-03 修订）；删除 macOS 12–25、Intel/Rosetta 和 LoginServiceKit fallback。

仍需确认：

| Decision | 推荐选项 | 备选与代价 | 最晚决策点 |
| --- | --- | --- | --- |
| D3 Private Space failure policy | 自动禁用 Space-dependent commands，core tiling 可用 | hard fail 会把单一私有 API break 扩大为整个 app 不可用 | WP2 adapter API 冻结前 |
| D4 Release runtime gate | 暂缓 macOS 27.2 physical gate；macOS 26.6.2 stable-signed runtime 是当前使用/代码发布 gate | 不可宣称已完成 macOS 27.2 真机验证；未来需恢复 matrix 才能作该声明 | 恢复 27.2 发布验证前 |
| D5 Sparkle trust | 暂缓生产发布决策；恢复时采用 EdDSA + Developer ID/notarization 双重验证 | 只依赖 code signing 无法获得同等明确的 feed/archive integrity contract | 恢复 WP6 前 |

## 9. 实施前置条件与阻塞项

2026-11-03 责任更新：按维护者明确指示，真实 Developer ID、notarytool、生产 Sparkle EdDSA key、appcast 发布/撤回和 D3–D5 决策交由维护者执行。D4 物理验证与所有发布事务（D5/WP6/WP8）现已暂缓。AI 保留 [维护者操作清单](release-maintainer-handoff.md)，继续不依赖生产凭据的代码、脚本和自动验证。暂缓不等于相应 release gate 已通过。

以下外部条件影响发布验证，由维护者或其安排的测试者提供证据：

| Blocker | 阻塞范围 | 解除证据 |
| --- | --- | --- |
| macOS 27.2 physical Mac（至少 M1，另有当前代/M6+）暂不可用 | 已按维护者决定暂缓的 WP7/27.2 compatibility claim | 恢复 27.2 matrix 时提供 runner inventory + 可复现 test session |
| 无 Developer ID Application certificate、notarytool profile/team access | WP6/G4 | secret 已配置；最小验证 artifact notarized |
| 无 Sparkle EdDSA private key 管理/rotation 方案 | WP3/WP6/G3/G4 | offline key procedure + test-signed appcast |
| 无 appcast/Canary hosting 发布与撤回权限 | WP6/WP8 rollout | staging feed publish/rollback drill |
| D3–D5 未签署 | 对应所有有分歧的 WP | maintainer decision record |

不得用降低目标来绕过 blocker。例如，没有 27.2 真机时可以继续 adapter/unit/release pipeline 工作，但不能把 27.0.1 hosted runner 的结果宣称为 27.2 runtime completion。

## 10. Completion checklist

- [ ] Apple baseline 在实施开始时重新核对；若 27.x/Xcode 27.x 已更新，记录新 patch baseline。
- [ ] [实施状态表](macos-27-implementation-status.md) 的本地证据和 external evidence required 项在 release 前逐项复核。
- [ ] D1/D2 已作为维护者决策记录；D3/D5 已签署，D4 暂缓决定已记录，support range 未被实现者隐式改变。
- [ ] G0–G5 均有可追溯 evidence。
- [ ] 所有 P0/P1 risk 已 closed、accepted 或有明确 degradation/owner。
- [ ] README、appcast、Info.plist、Xcode target 和 release artifact 的 minimum OS 一致。
- [ ] Stable artifact 可验证、可更新、可回退；上一版本仍可获取。
- [ ] macOS 27.2 physical RC soak 完成，无 crash/hang/stuck input。



