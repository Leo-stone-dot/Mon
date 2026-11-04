## 2026-11-03 15:41 CST 发现仓库执行规则

### 发现的事实

仓库根目录出现 `AGENTS.md`，要求新增术语维护到 `glossary.md`，并在执行偏离时维护 `implementation-notes.md`。

### 偏离原计划

原计划继续推进 Sparkle feed selection 的测试化；由于新增仓库规则，先补充 `glossary.md` 和本记录，再继续实现。

### AI 自作主张的决策

选择从本轮新增术语开始维护 glossary，没有追溯定义仓库中所有既有术语。

### 需要人类复核的点

`AGENTS.md` 要求“当前仓库出现的所有术语”均定义；是否需要后续专门补全既有术语，需要维护者确认。

### 测试与验证结果

尚未运行新的测试；这是执行规则变更记录。

## 2026-11-03 15:45 CST 状态菜单显示 Space 命令降级原因

### 发现的事实

Space 命令失败目前只写入 log，状态菜单不显示 Space 命令是否可用；WP4 要求降级原因在现有 UI 中可发现。

### 偏离原计划

原计划继续 WP3 的 Sparkle 真实签名验证；由于该部分依赖外部 secrets，改为先完成可本机验证的 WP4 降级可见性。

### AI 自作主张的决策

选择在状态菜单打开时动态插入一个 disabled 菜单项，不改 XIB；只在 Space 命令不可用时显示，避免新增设置框架。

### 需要人类复核的点

状态菜单插入位置为第 0 项；是否需要固定放在版本项之后，需要 UI 维护者确认。

### 测试与验证结果

`Scripts/lint.sh` 通过；`build-for-testing` 通过；`Scripts/release-pipeline.sh unsigned` 通过；support contract 与 manifest gate 通过（minimum 27.0、arm64-only）。新增 `SpaceCommandAvailability` tests 已编译，未在本机执行 test runner（本机非 macOS 27）。

## 2026-11-03 15:50 CST appcast gate 自测

### 发现的事实

`Scripts/verify-appcast.sh` 已有正向验证，但没有测试它是否会拒绝缺签名、非 HTTPS、最低系统版本错误、版本不匹配、签名或长度不匹配的 feed。

### 偏离原计划

原计划继续真实签名链路；该链路依赖外部 secrets，因此改为先证明 appcast gate 本身可靠。

### AI 自作主张的决策

选择新增 `Scripts/test-verify-appcast.sh`，用临时目录构造最小 app bundle 和多种非法 appcast；没有引入 XCTest 或新依赖。

### 需要人类复核的点

自测使用合成 appcast，不替代真实 staging feed 验证；真实 feed 仍需在 signed pipeline 中验证。

### 测试与验证结果

`Scripts/test-verify-appcast.sh` 通过，覆盖 valid、missing edSignature、non-HTTPS、wrong minimumSystemVersion、version mismatch、signature mismatch、length mismatch。

## 2026-11-03 15:55 CST 配置加载错误带出路径与原因

### 发现的事实

`UserConfiguration` 的 YAML/JSON 加载失败只显示通用 alert，未说明文件路径和解析错误；WP5 要求 config parse error 输出 actionable diagnostics。

### 偏离原计划

原计划继续 release gate 相关验证；本项属于 WP5 中可直接在仓库内完成且可测试的 diagnostics 补强。

### AI 自作主张的决策

选择引入 `ConfigurationFileLoad` 包装值与 diagnostic，并把 YAML/JSON 解析抽成 internal static helper 以便测试；没有改变配置优先级与 schema。

### 需要人类复核的点

alert 现在包含完整文件路径与解析错误文本，是否需要脱敏或只显示文件名，需要维护者确认。

### 测试与验证结果

`Scripts/lint.sh` 通过；`build-for-testing` 通过；`Scripts/release-pipeline.sh unsigned` 通过；support contract、appcast self-test、manifest gate 通过。新增 diagnostics tests 已编译，未在本机执行 test runner（本机非 macOS 27）。

## 2026-11-03 16:00 CST 状态菜单同时显示 Accessibility 与 Space 降级

### 发现的事实

状态菜单此前只显示 Space 命令降级；WP4 还要求 Accessibility 降级原因在现有 UI 中可发现。

### 偏离原计划

原计划继续 WP5 配置项；本轮改为补齐 WP4 中同类且可测试的 Accessibility 降级可见性。

### AI 自作主张的决策

选择把状态菜单项从 `space-command-status` 改为统一的 `runtime-status`，由 `RuntimeStatusPresentation` 决定显示条目；未新增偏好设置或 XIB 改动。

### 需要人类复核的点

Accessibility 提示使用固定英文文案；是否需要本地化或跳转到 System Settings 的按钮，需要维护者确认。

### 测试与验证结果

`Scripts/lint.sh` 通过；`build-for-testing` 通过；`Scripts/release-pipeline.sh unsigned` 通过；support contract、appcast self-test、manifest gate 通过。新增 `RuntimeStatusPresentation` tests 已编译，未在本机执行 test runner（本机非 macOS 27）。

## 2026-11-03 16:10 CST D2 修订为 26.0 并在本机执行测试

### 发现的事实

当前测试机为 macOS 26.6.2 (25G83)，Xcode 27.2 / SDK 27.2；原 27.0 deployment target 使 test bundle 无法在本机运行。用户明确表示不要求 Intel 兼容，只想现在开始在 26.6.2 上使用和测试。

### 偏离原计划

计划 D2 原为 macOS 27.0；按用户决定改为 macOS 26.0。支持矩阵变为 Apple silicon `arm64` + macOS 26.x–27.x，仍不支持 Intel/Rosetta 与 macOS 25 及更早。

### AI 自作主张的决策

把 6 处 `MACOSX_DEPLOYMENT_TARGET` 改为 26.0，并同步 `verify-support-contract.sh`、`ci-archive.sh`、`verify-signed-release-artifact.sh`、`ci-build-and-test.sh`、appcast self-test fixture、CI sdk runner label（`macos-26`）、README 与 support/validation 文档。保留 macOS 27.2 physical gate 作为 release runtime baseline。未增加 Intel 架构过滤机制，因为用户明确不要求 Intel 兼容。

### 需要人类复核的点

Sparkle appcast 无法按 CPU 架构过滤，macOS 26 上的 Intel 用户理论上仍可能看到 `arm64`-only 更新；按当前决定不处理，但需要维护者在发布前确认。D4（27.2 physical 是否仍为 hard blocker）本轮保持不变，需要最终签署。

### 测试与验证结果

在 macOS 26.6.2 上实际执行 `xcodebuild test`：222 tests，0 failures。`Scripts/lint.sh` 通过；`Scripts/verify-support-contract.sh` 通过；`Scripts/test-verify-appcast.sh` 通过；`Scripts/release-pipeline.sh unsigned` 通过，built `LSMinimumSystemVersion=26.0`、全部 Mach-O `arm64`；manifest gate 通过（minimum 26.0、SDK 27.2、arch `arm64`）。

## 2026-11-03 16:15 CST macOS 26.6.2 运行时探针

### 发现的事实

Debug app 可在本机运行；`--debug-info` 输出 Accessibility trusted=false、Secure Input=false、Separate Spaces=false、Space inventory all=4/user=2，current Space 因无 Accessibility 权限无法解析。机器为双显示器，第二块屏位于负 y 坐标。

### 偏离原计划

原计划只做 build/test；floor 改为 26.0 后可以在本机做真实 runtime probe，因此补充本机 runtime evidence。

### AI 自作主张的决策

把 current Space 的 `unavailable` 细分为“Accessibility 未授权”和“无 focused window”两种原因；把探针输出保存到 `build/runtime-probe-macos26/`。未自动授予 Accessibility 权限。

### 需要人类复核的点

本机 Accessibility 未授权，因此 AX 窗口管理、current Space 和 Space command 尚未真实验证；需要在授权后复测。本机 Separate Spaces=false，只覆盖 shared Spaces 配置。

### 测试与验证结果

`--debug-info` exit 0；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 222 tests、0 failures；`Scripts/release-pipeline.sh unsigned` 通过（minimum 26.0、arm64-only）；support contract、appcast self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 16:18 CST physical evidence 包含 debug-info

### 发现的事实

`capture-physical-validation-evidence.sh` 会收集系统、显示器、Space 默认值，但没有收集 `--debug-info` 的运行时诊断；Accessibility/Secure Input/Space inventory 只能靠手工补充。

### 偏离原计划

无计划偏离；这是 WP7 evidence bundle 的补强。

### AI 自作主张的决策

选择让脚本依次尝试 archive、Debug、Release 三处 app executable，找到第一个可执行文件后运行 `--debug-info` 并写入 `debug-info.txt`；没有新增参数或权限。

### 需要人类复核的点

`debug-info.txt` 在未授权 Accessibility 的机器上会显示 false；物理验证时必须确认输出中的 Accessibility 状态符合预期。

### 测试与验证结果

在本机运行 capture 脚本：生成 `debug-info.txt` 且包含 runtime diagnostics；脚本按预期因 macOS 26 不满足 27.2 physical preflight 而以非 0 退出。`Scripts/verify-support-contract.sh` 与 `git diff --check` 通过；本轮无 Swift 代码改动，未重跑 test suite。

## 2026-11-03 16:25 CST 登录项迁移提示可测试化

### 发现的事实

`presentLoginItemMigrationNoticeIfNecessary()` 直接读写 `UserDefaults.standard`，无法在隔离 defaults 中验证“只展示一次”的行为。

### 偏离原计划

原计划等待 Accessibility 授权后做 AX runtime 验证；授权尚未完成，因此先做不依赖 TCC 的 WP3 可测试项。

### AI 自作主张的决策

抽取 `LoginItemMigrationNotice`，提供 `shouldPresent(in:)` 与 `markPresented(in:)`；AppDelegate 使用共享实例，测试使用独立 `UserDefaults` suite。

### 需要人类复核的点

提示文案仍是固定英文，是否需要本地化由维护者决定。

### 测试与验证结果

`Scripts/lint.sh` 通过；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 224 tests、0 failures（新增 2 个登录项提示 tests）；`Scripts/release-pipeline.sh unsigned` 通过（minimum 26.0、arm64-only）；support contract、appcast self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 16:32 CST 开发签名身份与 TCC 授权失效

### 发现的事实

用户已在 System Settings 中启用 Amethyst 的 Accessibility 权限，但 `--debug-info` 仍显示 `Accessibility trusted: false`。Debug app 使用 ad-hoc/linker 签名（`Info.plist=not bound`、`Internal requirements=none`），每次重建都会改变 cdhash，导致 TCC 授权对应旧签名。

### 偏离原计划

原计划在用户授权后直接跑 AX runtime 验证；实际因签名漂移无法匹配授权，改为先建立稳定开发签名。

### AI 自作主张的决策

新增 `Scripts/bootstrap-dev-signing.sh` 创建本地自签名 `Amethyst Dev` 身份，`Scripts/sign-dev-app.sh` 在 Debug 构建后重新签名；并把开发 keychain 加入用户 keychain search list。未修改 Xcode 项目的签名设置，避免影响发布构建。

### 需要人类复核的点

需要用户在 Accessibility 列表中移除旧的 Amethyst 条目，再重新添加 `build/DerivedData/Build/Products/Debug/Amethyst.app` 并启用；否则 TCC 仍匹配旧签名。该开发 keychain 位于 `build/signing/`，是否需要长期保留由维护者决定。

### 测试与验证结果

`Scripts/bootstrap-dev-signing.sh` 成功创建并信任 `Amethyst Dev`；`Scripts/sign-dev-app.sh` 签名后 `codesign -dv` 显示 `Identifier=com.amethyst.Amethyst`、`Authority=Amethyst Dev`。签名后 `--debug-info` 仍为 `Accessibility trusted: false`，等待用户重新添加授权条目。










## 2026-11-03 16:40 CST support 文档一致性 gate 与状态恢复 tests

### 发现的事实

`verify-support-contract.sh` 只校验 README 与 Info.plist，没有校验 support policy / checklist 是否仍声明 26.0；`VersionedStatePersistence.restore` 在 corrupt 与 future envelope 下的行为只有 codec 级测试。

### 偏离原计划

原计划等待用户重新授权后做 AX runtime；授权未就绪，继续做不依赖 TCC 的静态 gate 与状态恢复测试。

### AI 自作主张的决策

在 support contract gate 中增加 policy/checklist 的 26.0 声明检查，并拒绝 README/support 文档中的旧 27.0 floor 文案；在 persistence 测试中增加 no-state、corrupt、future-version 三个用例。

### 需要人类复核的点

文档一致性 gate 只覆盖 README、support policy、support guide、checklist；计划文档保留历史 27.0 记录，不纳入 stale 检查。

### 测试与验证结果

`Scripts/lint.sh` 通过；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 227 tests、0 failures（新增 3 个 persistence tests）；`Scripts/release-pipeline.sh unsigned` 通过（minimum 26.0、arm64-only）；support contract、appcast self-test、manifest gate 与 `git diff --check` 通过。注意 `ci-build-and-test.sh` 会重新以 ad-hoc 签名构建 Debug app，之后必须重跑 `Scripts/sign-dev-app.sh` 才能匹配 TCC 授权。

## 2026-11-03 16:48 CST Space contract probe

### 发现的事实

Space 字典解析失败只写 warning，没有统一 probe 结果；`--debug-info` 已显示 inventory 数量，但没有说明 private Space contract 是否健康。

### 偏离原计划

原计划等待 TCC 授权后做 AX runtime；授权仍未匹配，因此先补不依赖 AX 的 private Space contract probe。

### AI 自作主张的决策

新增 `SpaceContractProbe`（generic 通过 `windowType:` 传入类型），在 debug-info 输出 `Space contract: ok (user Spaces: N)` 或 `failed (...)`；新增 4 个 probe tests。第一次实现用 `run<Window>()` 被 Swift 拒绝，改为显式 metatype 参数。

### 需要人类复核的点

probe 只覆盖 inventory 解析，不覆盖 current Space（后者需要 focused window 与 Accessibility）；27.x patch 后是否需要扩展 probe 字段，需要维护者确认。

### 测试与验证结果

`Scripts/lint.sh` 通过；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 231 tests、0 failures；`--debug-info` 实际输出 `Space contract: ok (user Spaces: 2)`；`Scripts/release-pipeline.sh unsigned` 通过（minimum 26.0、arm64-only）；support contract、appcast self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 16:55 CST release preflight 自测

### 发现的事实

`release-preflight.sh` 只有手工验证过缺 env 与缺 identity 的失败路径，没有可重复的自测；CI 也没有执行它。

### 偏离原计划

原计划等待 TCC 授权后做 AX runtime；授权仍未匹配，继续补 release gate 的可重复验证。

### AI 自作主张的决策

新增 `Scripts/test-release-preflight.sh`，用 `env -u` 与伪身份验证两个失败路径；把该自测加入 CI sdk job 与 G4 checklist；未尝试伪造成功路径，因为成功路径需要真实 Developer ID 与 SUPublicEDKey。

### 需要人类复核的点

自测只覆盖失败路径；真实成功路径仍依赖外部证书与 key。

### 测试与验证结果

`Scripts/test-release-preflight.sh` 通过（缺 env 返回 64、缺 identity 返回 1）；`Scripts/verify-support-contract.sh`、`Scripts/test-verify-appcast.sh` 与 `git diff --check` 通过；本轮无 Swift 代码改动，未重跑 test suite。

## 2026-11-03 17:05 CST 状态菜单选择 layout 不生效修复

### 发现的事实

用户点击状态菜单 Layouts 子菜单无效果。`selectLayout(_:)` 依赖 `focusedScreenManager()`，而后者要求存在 focused window；在未授权 Accessibility 或没有 focused window 时直接静默 return。`populateLayoutsMenu()` 已有鼠标所在屏 fallback，但选择动作没有复用。

### 偏离原计划

用户报告的是真实使用问题，优先修复；原计划的 AX runtime 验证仍受 TCC 授权影响。

### AI 自作主张的决策

在 AppDelegate 抽取 `screenManagerForMenuAction()`：优先 focused screen，失败时回退到鼠标所在屏；`populateLayoutsMenu` 与 `selectLayout` 共用。另把 `Screens` CLI 从空实现补成输出 screenID/frames，并把 `screenID()` 的强制解包改为安全回退。

### 需要人类复核的点

菜单选择在无 Accessibility 时仍只能更新布局状态，实际 reflow 需要授权；鼠标所在屏 fallback 是否符合多屏预期需要 UI 维护者确认。

### 测试与验证结果

`Scripts/lint.sh` 通过；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 231 tests、0 failures；`Scripts/release-pipeline.sh unsigned` 通过（minimum 26.0、arm64-only）；support contract、appcast self-test、release preflight self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 17:12 CST custom layout 加载失败诊断

### 发现的事实

`CustomLayout` 读取布局文件失败时只 `log.error(error)`，没有明确带出布局文件路径；也没有测试覆盖“布局文件被删除”时不会崩溃。

### 偏离原计划

原计划继续等待 TCC 授权做 AX runtime；授权仍未匹配，继续补 WP5 中不依赖 TCC 的 diagnostics。

### AI 自作主张的决策

把加载失败日志改为 `Failed to load custom layout at <path>: <error>`，JSContext 创建失败也带出路径；新增 1 个缺失布局文件测试，断言 `frameAssignments` 为 nil 而不是崩溃。

### 需要人类复核的点

缺失布局文件时布局会保持无 frame assignment；是否需要在 UI 中提示“布局文件已删除”，需要维护者决定。

### 测试与验证结果

`Scripts/lint.sh` 通过；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 232 tests、0 failures；`Scripts/release-pipeline.sh unsigned` 通过（minimum 26.0、arm64-only）；support contract、appcast self-test、release preflight self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 17:22 CST 布局选择程序化验证与等高分栏

### 发现的事实

用户报告状态菜单选择 layout 仍不生效。已新增 `ScreenManager` 选择测试，证明 `selectLayout` 本身能正确切换、忽略未知 key、并在重复选择当前布局时回到上一个布局。用户正在运行的 app 是修复前的旧二进制，菜单 fallback 修复未生效。

### 偏离原计划

无计划偏离；这是针对用户实际使用问题的验证与功能补充。

### AI 自作主张的决策

新增 3 个 `ScreenManager.selectLayout` 测试；按用户“等分高度”的需求创建 `~/Library/Application Support/Amethyst/Layouts/equal-row.js` 自定义布局，并用 node 验证 5 个窗口时高度均为 200、总和 1000；同时把示例写入 `docs/custom-layouts.md`，并说明内置 Row 可通过增加 main pane count 达到等分。

### 需要人类复核的点

`equal-row.js` 写在用户 Application Support 目录，不属于仓库；是否要改为内置布局或纳入仓库示例，需要维护者决定。用户需要重启 app 才能加载新布局。

### 测试与验证结果

`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 235 tests、0 failures；`node --check` 与等分计算验证通过；`Scripts/lint.sh`、support contract、appcast self-test、release preflight self-test 与 `git diff --check` 通过。

## 2026-11-03 17:30 CST 诊断 CLI 去强制解包

### 发现的事实

`Windows` 调试命令对 `AXWindow(element: window)!` 强制解包；`DebugInfo.version()` 对 Info.plist 字段强制解包。缺少 Accessibility 或 bundle 字段异常时可能崩溃。

### 偏离原计划

无计划偏离；这是 diagnostics 稳定性补强。

### AI 自作主张的决策

把 `AXWindow` 解包改为 `guard let` 并打印 `<unable to wrap window element>`；版本字段改为安全回退 `unknown`。未改变 CLI 参数或输出结构。

### 需要人类复核的点

`debug windows` 在无 Accessibility 时只能列出应用、列不出窗口，这是预期限制；是否需要提示用户授权，需要维护者决定。

### 测试与验证结果

`Scripts/lint.sh` 通过；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 235 tests、0 failures；`Amethyst debug windows` 正常退出（列出应用、无窗口）；`Scripts/release-pipeline.sh unsigned` 通过（minimum 26.0、arm64-only）；support contract、appcast self-test、release preflight self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 17:40 CST macOS 26 user Space type = 4

### 发现的事实

Accessibility 授权成功后，`--debug-info` 显示 CGS Space 为 `1:0:"", 222:4, 542:4, 854:0`，当前 Space 是 `222`、type `4`。`defaults read com.apple.spaces` 也把当前桌面 222 标为 `type = 4`，说明 macOS 26 用 type 4 表示用户桌面；旧代码把 `CGSSpaceTypeUser == 0` 当作用户 Space，导致 `ScreenManager.reflow` 直接跳过，布局切换看起来无效。

### 偏离原计划

计划假设 macOS 27 仍使用旧 CGS type 值；实测 macOS 26 已改变语义，属于 WP2 R1 private API 行为变化。

### AI 自作主张的决策

新增 `Space.isUserSpace`：type 4 视为用户桌面，legacy type 0 且 UUID 非空也视为用户桌面，type 1/2 及其他视为非用户；替换所有 `type == CGSSpaceTypeUser` 判断；debug-info 增加每个 Space 的 id:type:uuid 与 per-screen 明细。

### 需要人类复核的点

type 0 且 UUID 非空的 Space（如 854）当前也计入用户 Space，可能是另一桌面或遗留 Space；需要在 macOS 27.2 真机核对 type 语义是否再次变化。

### 测试与验证结果

新增 4 个 `Space.isUserSpace` tests；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 239 tests、0 failures；`--debug-info` 显示 `user=3`、当前 Space `222:4`；`Scripts/lint.sh`、release pipeline（minimum 26.0、arm64-only）、support contract、appcast self-test、release preflight self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 17:48 CST debug windows 无法读取窗口

### 发现的事实

授权 Accessibility 后运行 `Amethyst debug windows`，大量窗口显示 `<unable to wrap window element>`。原因是 `AXWindow(element:)` 带有 `AXRole == "AXWindow"` 检查，部分元素无法通过；应用自身的窗口枚举走 `Window(axElement:)`，不走该检查。

### 偏离原计划

无计划偏离；这是 diagnostics 正确性问题。

### AI 自作主张的决策

把 `Windows` 命令改为直接 `AXWindow(axElement: window.axElementRef)`，与 `SIApplication.windows()` 的转换路径一致；仍然保留安全解包（该初始化器非 failable）。同时把 debug-info 的 Space 明细改成 `id:type:uuid` 与 per-screen 输出。

### 需要人类复核的点

`debug windows` 对 Finder 桌面窗口仍会输出零 frame / id 0，这是窗口本身属性；是否需要过滤桌面窗口由维护者决定。

### 测试与验证结果

`Scripts/lint.sh` 通过；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 239 tests、0 failures；`Amethyst debug windows` 不再输出 `<unable to wrap window element>`；`--debug-info` 显示 Accessibility true、current Space `222:4`、user=3；release pipeline、support contract、appcast self-test、release preflight self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 17:49 CST Sparkle EdDSA 自测与 per-Space 布局隔离测试

### 发现的事实

Sparkle artifact 提供 `generate_keys` 与 `sign_update`；`sign_update` 支持 `--ed-key-file` 和 `--verify`。OpenSSL 生成的 Ed25519 PKCS#8 DER 末尾 32 字节可作为 Sparkle 私钥种子，base64 后可直接用于 `--ed-key-file`。现有 `Scripts/verify-appcast.sh` 只做 appcast 与签名输出的一致性检查，密码学验签由 `Scripts/release-pipeline.sh signed` 单独调用；缺少无真实密钥环境可运行的自动化自测。`ScreenManager` 已按 Space UUID 保存 `currentLayoutIndexBySpaceUUID`，但现有测试没有覆盖跨 Space 隔离。

### 偏离原计划

WP6 的真实 `SUPublicEDKey`、Developer ID、notarytool 与生产 Sparkle 私钥仍被外部 secret 阻塞；本轮用临时 Ed25519 密钥验证同一签名/验签路径，不声称 G4 完成。用户新增“不同桌面不共享 layout”要求；代码已按 Space UUID 支持，本轮补测试锁定行为，未改产品代码。

### AI 自作主张的决策

新增 `Scripts/test-sparkle-eddsa.sh`，使用 OpenSSL 在临时目录生成密钥，不写入 Keychain、不读取生产 key；CI 在 `ci-build-and-test.sh` 之后运行该自测。新增两条 `ScreenManagerTests`：跨 Space 索引隔离与多 Space 编码。未新增 per-screen/per-desktop 配置键，因为现有运行时选择已按聚焦屏幕与 Space UUID 工作；声明式映射仍需单独设计。

### 需要人类复核的点

生产 Sparkle EdDSA 私钥的离线生成、保管与 rotation 流程仍需维护者确认；本自测只证明密钥格式与签名路径。`sign_update --verify` 使用私钥文件派生公钥，生产环境仍应以 `SUPublicEDKey` 和 appcast 验签链路做独立核对。macOS 27.2 真机、Developer ID、notarization、staging feed publish/rollback 仍未完成。

### 测试与验证结果

`Scripts/test-sparkle-eddsa.sh` 通过（签名、验签、篡改拒绝、错误密钥拒绝、错误签名拒绝、appcast gate 接受真实签名）；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 242 tests、0 failures；`Scripts/lint.sh` 0 violations；`git diff --check` 通过；`Scripts/verify-support-contract.sh`、`Scripts/test-verify-appcast.sh`、`Scripts/test-release-preflight.sh` 通过；`Scripts/release-pipeline.sh unsigned` 通过（minimum 26.0、arm64-only、manifest）。未运行：signed pipeline（缺 Developer ID/notarytool/真实 Sparkle key）、macOS 27.2 physical suite、48h soak。

## 2026-11-03 17:54 CST SPARKLE_PUBLIC_KEY 注入与 post-archive preflight

### 发现的事实

`Amethyst/Amethyst-Info.plist` 没有 `SUPublicEDKey`，而 `Scripts/release-preflight.sh` 在归档前读取 source Info.plist、归档后读取 built Info.plist 都要求该键存在。`Scripts/release-pipeline.sh signed` 在归档前后各调用一次 preflight，因此没有生产公钥时 signed 流程在第一步就失败，无法验证后续签名链路。

### 偏离原计划

计划写的是“在 Info.plist 配置 SUPublicEDKey”；当前没有生产公钥，且不应把生产公钥硬编码进 source。改为从 `SPARKLE_PUBLIC_KEY` 环境变量在归档后注入 built Info.plist，source Info.plist 保持不含生产密钥。

### AI 自作主张的决策

新增 `Scripts/inject-sparkle-public-key.sh`，校验 base64 解码后为 32 字节并替换/写入 `SUPublicEDKey`；`release-preflight.sh` 增加 `--post-archive` 模式，校验 built Info.plist 与 `SPARKLE_PUBLIC_KEY` 一致；`release-pipeline.sh signed` 在归档后、签名前调用注入与 post-archive preflight；新增 `Scripts/test-inject-sparkle-public-key.sh` 覆盖写入、替换、坏 key 与缺失 Info.plist。

### 需要人类复核的点

生产环境是否允许在 CI 中以环境变量注入公钥，还是要求 source Info.plist 固化公钥，需要维护者确认。`SPARKLE_PUBLIC_KEY` 只校验格式，未在 preflight 中证明它与 `SPARKLE_ED_KEY_FILE` 私钥配对；该配对关系仍需生产签名流程或额外自测证明。

### 测试与验证结果

`Scripts/test-inject-sparkle-public-key.sh`、`Scripts/test-release-preflight.sh`、`Scripts/test-sparkle-eddsa.sh` 通过；修改脚本 `bash -n` 语法检查通过。未运行 signed pipeline（缺 Developer ID/notarytool/真实 Sparkle key）与 macOS 27.2 physical suite。

## 2026-11-03 17:58 CST 三个使用问题：TCC 反复授权、equal-row 不生效、layout 被改回 tall

### 发现的事实

1. 每次 `xcodebuild` 都会以 ad-hoc 重新签名，用户从 Finder/Xcode 启动时会触发新的 TCC 授权。
2. `equal-row.js` 在 JavaScriptCore 中可正常执行，5 个窗口返回等高 200pt；不生效来自布局状态被重置与 reflow 条件。
3. `ScreenManager` 没有持久化 `currentLayoutIndexBySpaceUUID`，重启或新 Space 都回落到索引 0（tall）；`selectLayout` 在重复选择当前布局时会切回上一个布局。

### 偏离原计划

无计划偏离；这是用户实际使用问题的修复。

### AI 自作主张的决策

新增 `Scripts/dev-build.sh`（构建 + 稳定签名 + 可选重启）；`ScreenManager` 编码/解码 `currentLayoutIndexBySpaceUUID`，选择布局时立即记录当前 Space 的索引；`selectLayout` 改为幂等，不再切换到 previous layout；移除 `previousLayoutKey`。

### 需要人类复核的点

`selectLayout` 不再是 toggle 语义，依赖“再次选择当前布局回到上一个”的用户可能需要注意；布局索引持久化按 Space UUID 记录，跨显示器共享 Spaces 时以当前 Space UUID 为准。

### 测试与验证结果

`Scripts/lint.sh` 通过；`Scripts/ci-build-and-test.sh` 在 macOS 26.6.2 上 240 tests、0 failures；JavaScriptCore 脚本验证 equal-row 返回 5 个 200pt 等高 frame；release pipeline、support contract、appcast self-test、release preflight self-test、manifest gate 与 `git diff --check` 通过。

## 2026-11-03 18:08 CST 布局恢复实测修复与发布责任交接

### 发现的事实

上一轮只证明了运行中切换桌面和写入索引，未执行重启对应的真实编码/解码。当前 `ScreenManager.init(from:)` 的活动列表为空，而 `updateSpace` 在填充列表之前恢复索引，导致非首项选择被忽略。布局配置重排、插入、删除后，保存的索引也未按原有 key 对应新列表。修复前新增测试运行 18 tests，出现 7 处失败断言。因此之前“正常退出后重启会恢复”的结论证据不足，本轮补证并修复。

维护者明确将真实 Developer ID、notarytool、生产 Sparkle EdDSA key、appcast 发布/撤回和 D3–D5 签署留给自己执行，只要求 AI 交付操作说明。这项分工未代表维护者接受 D3–D5 的推荐选项。

### 偏离原计划

无目标缩减。生产资源和人工决策转入交接，代码与自动验证继续推进。更正上一条记录中“不应把生产公钥硬编码进 source”的表述：公钥不需要保密，放入源码或发布配置均可；当前环境变量注入只是实现选择。私钥仍需保密。

### AI 自作主张的决策

保留已有存档格式：用存档列表的 key 将旧索引映射到新列表，先加载桌面的布局再恢复选择；被删除或越界的选择回退到该桌面的首项，空列表保持无选择并允许安全调用循环命令。解码时通过 `JSONDecoder.userInfo` 注入测试配置，默认仍使用共享配置；窗口限制也使用实例配置。恢复的 reflow queue 与新实例采用相同队列设置。

新增 `docs/release-maintainer-handoff.md`，记录资源准备、命令、发布/撤回顺序、D3–D5 记录表及 AI 仍需完成的发布代码缺口。不会把公钥配对验签、嵌套签名顺序、最终 appcast 生成和 ZIP hash 缺失交给维护者手工修复。测试在 `build/LayoutRestoreValidation` 构建，未替换当前运行 App。自定义布局测试使用唯一命名的临时脚本，并在结束时删除。

### 需要人类复核的点

维护者按交接文件自行准备生产资源和填写 D3–D5；这些步骤不再作为独立代码工作的前置要求。macOS 27.2 真机与 RC soak 仍须由实际环境提供证据，不要求升级当前工作机。

### 测试与验证结果

定向测试修复前 18 tests / 7 failures，修复后 18 tests / 0 failures。新增自定义布局用例最初因缺脚本文件出现 2 处失败，补入实际临时 fixture 后，完整 Debug 测试 250 tests / 0 failures，含本轮新增的 8 个恢复测试。证据位于 `build/layout-restore-evidence/` 的 `before.xcresult`、`after.xcresult`、`full.xcresult` 和 `full-fixed.xcresult`。SwiftLint 0 violations、support contract 与 `git diff --check` 通过；交接文件的 4 个本地链接及所有 shell 示例语法通过检查。实际退出/重启用户正在运行的 App、生产发布、macOS 27.2 runtime 与 48 小时 soak 尚未执行。

## 2026-11-03 18:15 CST 发布密钥配对、公钥验签与归档证据

### 发现的事实

此前 release preflight 只验证 `SPARKLE_PUBLIC_KEY` 可解码为 32 字节，未证明其与 `SPARKLE_ED_KEY_FILE` 的 32 字节 Ed25519 seed 属于同一密钥对。signed pipeline 的 `sign_update --verify` 使用私钥文件验签，不能独立代表客户端从 `SUPublicEDKey` 获得的验证结果。artifact manifest 在 ZIP 创建之前写入，只包含 Package.resolved hash，不包含逐个 dependency revision 或最终 ZIP 的 SHA-256。

### 偏离原计划

无。WP6 要求 EdDSA 和可追溯 artifact manifest；本轮把缺失的本地 gate 补齐。Developer ID、notarization、生产密钥、托管发布和维护者签署仍按明确责任交接由维护者完成，未据此声称 G4 通过。

### AI 自作主张的决策

新增 `verify-sparkle-key-pair.sh`：将 Sparkle 的 32 字节私钥 seed 以 PKCS#8 Ed25519 DER 形式交给 OpenSSL 推导公钥，并与发布公钥比较，不输出任何密钥。新增 `verify-sparkle-archive-public-key.sh`：以 SubjectPublicKeyInfo Ed25519 公钥验证 ZIP 的 64 字节 EdDSA signature。两个脚本进入 signed pipeline；`test-sparkle-eddsa.sh` 现在覆盖公钥验签、篡改 ZIP、错误公钥、错误签名和 appcast。

manifest 支持可选归档输入，记录 path、bytes、SHA-256，并解析 Package.resolved 写入 13 个 dependency 的 identity/location/revision/version。signed pipeline 改为签完 ZIP 后生成 manifest。新增密钥配对和 manifest 自测，CI sdk job 执行它们。保留私钥文件输入模型，不改维护者已选择的凭据托管责任。

### 需要人类复核的点

发布机需要使用本机 OpenSSL 支持的 Ed25519 `pkeyutl -rawin`；当前 macOS 26.6.2 已验证。真实私钥若是 Sparkle 旧格式（非 32 字节 seed），新 gate 将拒绝，需要维护者按 Sparkle migration/rotation 方案处理，而不是静默降级。生产签名、公证、staple、Gatekeeper、网络下载、更新与撤回仍须由维护者在实际发布环境执行。

### 测试与验证结果

`test-verify-sparkle-key-pair.sh` 通过（匹配、错误配对、错误公钥和错误私钥）；`test-sparkle-eddsa.sh` 通过（Sparkle 私钥验签、公钥验签、篡改、错误签名/公钥、appcast）；`test-generate-artifact-manifest.sh` 通过（ZIP bytes/SHA-256/dependency revision 与缺归档失败）。`test-release-preflight.sh`、`test-inject-sparkle-public-key.sh`、`test-verify-appcast.sh`、support contract、`git diff --check` 与 `bash -n` 通过。实际 `Scripts/ci-archive.sh` 通过：minimum 26.0、arm64-only，并生成含 13 个 dependencies、8 个 Mach-O 的 unsigned manifest。SwiftLint 0 violations。当前运行的 Debug app PID 29479 和二进制时间仍为 17:47:26，未被验证覆盖。未运行：signed pipeline、macOS 27.2 physical suite、48 小时 soak。

## 2026-11-03 18:21 CST 本地 appcast 生成与发布前验证

### 发现的事实

Sparkle artifact 已提供 `generate_appcast`。它从 archive 内的 app Info.plist 读取 `LSMinimumSystemVersion` 和 `SUPublicEDKey`；没有公钥时会生成不带 EdDSA signature 的 enclosure。它在同一 archive directory 已有 `appcast.xml` 时更新现有条目，并可配置 URL prefix、channel、保留版本和 delta 数量。直接手写 XML 会重复 Sparkle 的版本、签名和历史 item 逻辑。

### 偏离原计划

无。计划要求生成并验证 appcast；发布/撤回权限仍按维护者责任交接保留。实现选择为封装仓库已经 pin 的 Sparkle 工具，在本地 staging directory 产出候选 feed，不调用网络、不持有上传凭据。

### AI 自作主张的决策

新增 `Scripts/generate-appcast.sh`：要求已签名 app、含 ZIP/release notes 的 staging directory、配对 EdDSA 私钥、HTTPS 下载前缀；仅传入当前 build、保留所有历史版本、不产生 delta，并把输出固定为 staging directory 的 `appcast.xml`。生成后调用 appcast gate。新增 `Scripts/test-generate-appcast.sh`，以临时 app/keys/archive 证明非 HTTPS 与错误私钥拒绝、生成项目包含真实签名和正确 archive length/release notes URL、重复生成同 build 只更新不重复插入。CI 将这项测试放在 package resolve/build 后，避免 fresh checkout 找不到 Sparkle binary。

维护者交接文档增加本地 staging 操作示例：先生成/验证 feed，再分别上传 ZIP、release notes 和已验证的 XML，并执行 canary/stable 与撤回流程。未把上传、缓存刷新或撤回自动化，因为托管服务和权限不在仓库范围。

### 需要人类复核的点

维护者需要在自己的 stable/canary staging directories 保留现有 `appcast.xml`，并确保 ZIP 与 release notes 同 basename；将真实 HTTPS URL 接入 app 后要在清洁 macOS 27.2 机器验证实际更新。官方 `generate_appcast` 的 archive history pruning 行为与本项目的长期保留策略应在首次正式发布前复核；当前脚本显式传入 `--maximum-versions 0`。

### 测试与验证结果

`bash -n`、`test-generate-appcast.sh`、`test-sparkle-eddsa.sh`、`test-verify-sparkle-key-pair.sh`、`test-generate-artifact-manifest.sh`、`test-inject-sparkle-public-key.sh`、`test-verify-appcast.sh`、support contract 与 `git diff --check` 全部通过。appcast 自测显示首轮写入 1 item，第二轮更新 1 item，未重复。当前运行 Debug app PID 29479 的可执行文件时间仍为 17:47:26，未被测试覆盖。未运行 signed pipeline、生产上传/撤回、macOS 27.2 physical suite 或 soak。

## 2026-11-03 18:27 CST private Space 降级下保持核心 tiling

### 发现的事实

此前 `ScreenManager.reflow` 要求 `CGSpacesInfo.currentSpaceForScreen` 成功且与已跟踪 Space 相等；私有 CGS 数据缺失时直接停止 reflow。即使放宽该 guard，`Windows.activeWindows` 仍在当前 Space 查询为空时返回空数组，因此普通平铺仍不能工作。这与 D3 推荐边界“只禁用 Space-dependent commands，保留 core tiling”不一致。

### 偏离原计划

无。WP2 要求 private API fail closed 但 core tiling 可用；本轮将“Space 命令 fail closed”和“普通 tiling 不因 Space 数据缺失而停止”分别实现。D3 本身仍待维护者签署，不因代码实现而标记为已接受。

### AI 自作主张的决策

新增 `SpaceReflowPolicy`，只有在 tiling 禁用、非用户 Space 或已知的 current/tracked Space 不匹配时阻止 reflow；Space 查询为 nil 时继续。将 `SpaceClient` 注入 `ScreenManager` 和 `Windows`，用同一 adapter 服务 reflow、Space command 与窗口筛选。窗口在 Space 信息可用时仍按 Space ID 精确过滤；不可用时按当前显示器、活动状态、隐藏/浮动状态选择。CGWindow active-ID cache 不可用时使用窗口的 AX active 状态，避免另一个系统查询失败使集合为空。

在无法识别 Space 时选择 Wide 等 layout，随后恢复 Space 信息时把现有 layout/索引映射到重新识别的 UUID，避免恢复瞬间回到 Tall。文档明确降级期间保持当前选择、恢复后按桌面选择恢复。未更改 throw-to-Space：它仍由 `SpaceClient` 和 secure input preflight fail closed。

### 需要人类复核的点

若 private Space 数据连续不可用且用户切换到另一桌面，普通 tiling 会按当前显示器可见活动窗口继续，但在识别恢复前暂时使用上一已知 layout；这是保持 core tiling 的保守选择。macOS 27.2 真机仍需确认 CGWindow active list 与 AX screen 归属在此降级模式下不会把不可见桌面窗口纳入。D3 的发布决策仍由维护者填写。

### 测试与验证结果

先运行定向测试：ScreenManager + CGSpacesInfo 共 64 tests、0 failures；随后独立 DerivedData 全量测试 258 tests、0 failures。新增测试覆盖无 tracked Space、查询 nil、已知 stale Space、fullscreen Space、全局 tiling disable、无 Space 数据仍有 active window、已知 Space 仍精确过滤、降级期间选择 layout 后恢复 UUID。SwiftLint 0 violations，`git diff --check` 通过。unsigned release pipeline 再次通过：minimum 26.0、arm64-only、manifest 13 dependencies/8 Mach-O。当前运行 Debug app PID 29479 及其 17:47:26 二进制未被测试覆盖。未运行 macOS 27.2 physical runtime、signed release、公证、appcast 上传/撤回和 soak。

## 2026-11-03 18:33 CST Release custom layout 自动验证

### 发现的事实

Release configuration 启用 Hardened Runtime、使用空的 `Amethyst.entitlements` 与 `-O` 优化。直接用 `xcodebuild test -configuration Release` 时，默认关闭 `ENABLE_TESTABILITY`，使测试 bundle 的 `@testable import Amethyst` 不能解析；这不是 JavaScriptCore/custom layout 的运行失败。将 testability 仅用于测试构建后，CustomLayoutTests 能在 Release configuration 运行。

### 偏离原计划

无。WP5 要求验证 Debug/Release custom layout 一致性；本轮把 Release runtime 的可自动部分纳入 CI。不能从未签名 XCTest 推出 Debug entitlement 可删除，故不提前移除 `allow-jit` 与 `disable-library-validation`。

### AI 自作主张的决策

新增 `Scripts/test-release-custom-layouts.sh`：确认 Release 的 Hardened Runtime build setting、空 Release entitlement，随后用 `ENABLE_TESTABILITY=YES` 在独立 DerivedData 运行 25 个 CustomLayoutTests。result bundle 默认使用 UTC 时间戳；调用者显式指定已经存在的路径时拒绝，而不删除历史 evidence。CI 在 Debug unit tests、Sparkle appcast 自测后运行该脚本。

### 需要人类复核的点

Debug entitlement 的 JIT/library-validation 例外是否可以删除，仍需要使用实际签名的 Hardened Debug app 完成 JavaScriptCore runtime 验证；该动作可能影响本地 TCC 身份，不对当前正在使用的 Debug app 自动执行。Release 的真实 Developer ID/notarized runtime 同样仍待维护者环境验证。

### 测试与验证结果

首次 Release test 因默认 `ENABLE_TESTABILITY=NO` 无法加载测试模块；修正后脚本在 Release/arm64/空 Release entitlement 配置运行 CustomLayoutTests 25 tests、0 failures，输出 `Release custom layout tests: ok`。脚本 `bash -n`、`git diff --check` 通过；当前运行 Debug app PID 29479 与 17:47:26 二进制未被替换。未运行实际签名 Debug entitlement removal test、Developer ID/notarization 或 macOS 27.2 physical runtime。

## 2026-11-03 18:41 CST 损坏布局状态的可见回退

### 发现的事实

`VersionedStatePersistence.restore` 会对损坏或未来版本的状态抛错，`AppDelegate` 捕获后创建默认 WindowManager 并保留 UserDefaults 数据；但此前只写 log，用户无法从 status menu 得知已经回退。现有 `Reset Layouts` 会同时删除 state 和 backup，适合作为明确用户动作。

### 偏离原计划

无。WP5 要求 corrupt encoded state 不 crash、用户能看到原因且 state restore failure 回退默认而不删除用户文件。本轮补的是可见性和保留状态测试，不改变 YAML/JSON/custom layout 路径或其他偏好。

### AI 自作主张的决策

新增 `LayoutStateRestorePresentation.failureTitle`，在启动恢复 catch 时将其加入既有 status menu runtime status items；用户选择 `Reset Layouts` 后移除提示并清理保存状态/backup。新增纯展示测试和 corrupt state/backup 保留测试。文档说明先记录 `--debug-info` 后执行 Reset Layouts。未自动从 backup 恢复，因为无法判断 backup 是否与当前配置兼容。

### 需要人类复核的点

状态菜单提示只在用户打开 menu 时刷新；若维护者希望启动即弹 alert，需要单独决定提示干扰与可访问性取舍。backup 目前仅为可恢复证据，尚未提供“Restore Backup”UI；是否增加该产品功能不属于当前迁移范围。

### 测试与验证结果

AppDelegate/state 定向测试 33 tests、0 failures；完整独立测试 261 tests、0 failures。覆盖 corrupt state 回退文案、runtime status title、legacy/current/future codec、backup 保留与显式 reset。SwiftLint 0 violations、`git diff --check` 通过。当前运行 Debug app PID 29479 及 17:47:26 二进制未被替换。未运行真实用户 profile upgrade/rollback、macOS 27.2 physical validation、signed release 或 production update。

## 2026-11-03 18:48 CST TCC-safe local test policy

### 发现的事实

隔离 `xcodebuild test` 使用 `CODE_SIGNING_ALLOWED=NO` 启动 test host；虽然 bundle identifier 相同，但未签名二进制的 code identity 随构建变化，会触发新的 Accessibility/TCC 请求。此前为 WP2/WP5 运行多个隔离 runtime test，造成了用户可见的频繁授权提示。运行中的 development app 以 `Amethyst Dev` 签名且 Accessibility 为 true。

### 偏离原计划

迁移计划要求自动测试，但未明确区分 dedicated CI runner 与日常用户桌面。此前把隔离 runtime test 直接运行在用户工作机，违背了稳定 TCC 身份的本地验证边界。

### AI 自作主张的决策

新增 `Scripts/dev-test.sh`：先 `build-for-testing`，用 `Amethyst Dev` 对 Debug test host 稳定签名，再 `test-without-building`；默认 result bundle 使用 UTC 时间戳且拒绝覆盖已有 evidence。GitHub sdk job 增加 `ci` runner label，避免被未标为 CI 的日常 Mac 接走。支持文档和 validation checklist 明确禁止在已授权开发桌面直接运行 raw `xcodebuild test`。本轮只做 shell/YAML 静态验证，未执行新脚本。

### 需要人类复核的点

新脚本的 stable test host 路径尚未在当前用户桌面执行，以避免再次触发 TCC；下次需要 local runtime test 时，由用户明确指示后再运行。CI runner 必须实际配置 `ci` label，否则 workflow 会正确保持 queued 而不是落到当前机器。`test-without-building` 下 test bundle 与 stable host 的实际 TCC attribution 仍需在专用环境确认。

### 测试与验证结果

`bash -n Scripts/dev-test.sh`、workflow YAML parse、`git diff --check` 通过；未启动 test host。静态验证后运行中的 app 仍为 PID 83852、`Amethyst Dev` 签名、二进制时间 18:45:54，未被替换。

## 2026-11-03 18:51 CST AccessibilityClient 与无提示诊断

### 发现的事实

辅助功能信任查询散落在 UserConfiguration（请求 prompt）和 DebugInfo（不请求 prompt）两处直接 AX 调用，测试只能依赖机器真实 TCC 状态。此前未稳定签名 test host 的 repeated runtime test 会触发用户可见授权请求。

### 偏离原计划

无。WP2 明确要求 AccessibilityClient adapter；本轮按用户 TCC 边界只执行编译而不运行新增单元测试。

### AI 自作主张的决策

新增可注入 `AccessibilityClient`：系统实现接收 `shouldPrompt`，UserConfiguration 明确传 true，DebugInfo 明确传 false。新增 fake-client tests，验证配置检查请求 prompt、诊断检查不请求 prompt。保留原有系统实现和首次授权语义，不自动修改用户 TCC 或重启 app。

### 需要人类复核的点

新增 fake-client tests 已被编译但未在当前桌面运行；若需要执行它们，使用 `Scripts/dev-test.sh` 或 dedicated `ci` runner，并在运行前由用户明确要求。当前未运行 Amethyst 进程，不自行重新启动。

### 测试与验证结果

`xcodebuild build-for-testing` 在独立 `build/StaticCompileValidation` 完成并输出 `TEST BUILD SUCCEEDED`，未执行 test 或 launch。SwiftLint 0 violations、`git diff --check`、`bash -n Scripts/dev-test.sh` 通过。静态验证后未发现 Amethyst/test host 进程；现有 Debug app 文件仍为 18:45:54、`Amethyst Dev` 签名。

## 2026-11-03 18:53 CST AccessibilityClient Release archive 编译

### 发现的事实

AccessibilityClient 与 fake-client tests 可通过 `build-for-testing` 编译；不执行 test 即不会启动 test host。unsigned release archive 同样可在不启动测试的情况下验证 production configuration。观察到 Debug app 进程 PID 87037 于 18:52:07 启动，路径和稳定签名仍为 `Amethyst Dev`；archive 命令本身不含 launch/open 操作，未将该启动归因于 archive。

### 偏离原计划

无。按用户 TCC 边界，本轮用 build/archive 替代测试执行；不把编译成功表述为 fake-client 单元测试已经运行。

### AI 自作主张的决策

运行 `Scripts/release-pipeline.sh unsigned` 仅构建 archive、thin arm64、生成 manifest；未执行 signed pipeline、notary、appcast publish 或任何 `xcodebuild test`。保留运行中的 development app，不主动 quit、relaunch 或修改其 TCC 状态。

### 需要人类复核的点

AccessibilityClient fake-client tests 仍待 dedicated `ci` runner 或用户明确批准的 stable test host 执行。PID 87037 的启动来源未做推断；若用户未手动启动且再次发生，应在不重启的前提下检查 macOS unified log/launch source。

### 测试与验证结果

`build-for-testing` 输出 `TEST BUILD SUCCEEDED`；unsigned release pipeline 通过并报告 `LSMinimumSystemVersion=26.0`、所有 Mach-O 为 arm64、manifest 13 dependencies。support contract 与 `git diff --check` 通过。未运行 runtime test、signed pipeline 或任何需要新 TCC 授权的动作。

## 2026-11-03 18:56 CST ScreenTopologyClient adapter

### 发现的事实

`Screens` 直接读取 `Screen.availableScreens`、`Screen.screensHaveSeparateSpaces` 和 CGS screen descriptions，不能在显示器热插拔、共享桌面或私有 API shape 变化时替换拓扑来源。`ScreenTopologyClient` 是 WP2 指定但此前尚未落实的 adapter。

### 偏离原计划

无。按用户 TCC 边界只编译、不运行新的 topology test；不会把 `TEST BUILD SUCCEEDED` 误称为 runtime topology 验证。

### AI 自作主张的决策

新增 `ScreenTopologyClient`，提供显示器列表、独立 Spaces 开关和 descriptions。`WindowManager` 以默认系统 client 持有它，传给 `Screens.updateScreens` / `updateSpaces`；解码后的 WindowManager 同样默认系统 client，不改变已有编码数据。`CGScreensInfo` 也接受可选 topology client。新增 fake topology fixture test，使纯解析路径可脱离 CGS。

### 需要人类复核的点

fake topology test 已编译但未执行；显示器 hot-plug、negative origin、shared/separate Spaces 的实际运行时行为仍需 dedicated CI 或 macOS 27.2 physical validation。FocusFollowsMouseManager 和诊断 CLI 仍有独立显示器读取，不属于 `Screens` 这条核心状态更新路径。

### 测试与验证结果

`xcodebuild build-for-testing` 在独立 `build/StaticCompileValidation` 输出 `TEST BUILD SUCCEEDED`，未执行 test 或 launch。SwiftLint 0 violations、`git diff --check` 通过。验证时 Debug app 仍为 PID 87037、18:45:54 的稳定签名文件；未由本轮操作重启或替换。

## 2026-11-03 18:59 CST EventPostingClient adapter

### 发现的事实

跨 Space drag 已有可注入 SpaceDragEventClient，但其 CGEvent 创建/投递与 WindowManager 的 mouse-follows-focus 各自直接调用 CGEvent。WP2 要求的 EventPostingClient 尚不存在，导致这两条路径不能共享 fake event source。

### 偏离原计划

无。按用户 TCC 边界只编译包含 fake-client 测试的 targets，不执行任何合成鼠标事件或 runtime test。

### AI 自作主张的决策

新增 EventPostingClient，集中创建零 flags 的 cghid mouse event 与投递操作。SpaceDragEventClient 的系统实现复用它；WindowManager 的 mouse-follows-focus 回移也通过它。保留 SpaceDragEventClient 的 Secure Input、switch-to-Space 和 scheduler 责任，未改变 timeout/mouse-up cleanup 行为。新增 closure-route fixture test。

### 需要人类复核的点

AMScreen.focusScreen 和 AXWindow 的其他合成 mouse move 仍是独立操作点；是否将所有 UI focus 行为改由同一 client 管理，需要确认其失败语义和 event tap contract。新增 fake event test 已编译但未运行；Secure Input、stuck input 和实际 EventTap 行为仍需 dedicated CI 或 macOS 27.2 physical validation。

### 测试与验证结果

`xcodebuild build-for-testing` 输出 `TEST BUILD SUCCEEDED`，未执行 test 或 launch。SwiftLint 0 violations、`git diff --check` 通过。验证时运行中的 Debug app 仍为 PID 87037、18:45:54 文件，未被重启或替换。

## 2026-11-03 19:03 CST Toolchain lock verifier

### 发现的事实

Mintfile 和 Gemfile.lock 已锁 SwiftLint、xcbeautify、fastlane，但 bootstrap 使用默认 `brew bundle`，Homebrew 会升级已过期 dependency；bundle install 也没有显式 frozen 约束。Xcode build phase 已移除 `swiftlint --fix`，但缺少一个集中 gate 来防止这些约束回退。

### 偏离原计划

无。WP1 要求 pin tools、禁止 build 修改源码；本轮只检查和修改 bootstrap 脚本，不执行 brew 或 bundle 安装，避免联网/升级副作用。

### AI 自作主张的决策

bootstrap 改为 `brew bundle install --no-upgrade` 和 `bundle install --frozen`。新增 `verify-toolchain-locks.sh`，检查 Brew/Mint/Gem exact entries、SwiftPM revision、bootstrap flags 和 Xcode formatting build phase；CI 在 bootstrap 后运行它。未试图对 Homebrew formula 做无法由 Brewfile 保证的精确版本 pin，Mint/Gem lock 承担项目工具版本锁定。

### 需要人类复核的点

本机系统 Ruby 2.6 不能读取 lockfile 需要的 Bundler 4.0.23；这是 bootstrap 的 `ruby@3.4` / vendor bundle 解决的预期环境差异。本轮没有运行 bootstrap，因此未验证干净 runner 的网络安装。`ci` runner 需实际具有工具与标签，GitHub workflow 才会执行。

### 测试与验证结果

`verify-toolchain-locks.sh` 通过，workflow YAML parse、shell syntax 和 `git diff --check` 通过。未执行 brew/bundle install、build、test 或 app launch。验证后运行中的 Debug app 保持 PID 87037、18:45:54 文件。

## 2026-11-03 19:05 CST 实施状态证据索引

### 发现的事实

迁移工作已经横跨 support contract、adapters、状态恢复、Release pipeline、appcast 和 runtime safety，但计划文档本身没有把已实现的本地证据与必须由维护者/27.2 真机提供的证据集中区分，容易把绿色本地检查误读为 release completion。

### 偏离原计划

无。该索引是计划的审计附属物，不改变 support floor、release gate 或外部责任。

### AI 自作主张的决策

新增 `docs/macos-27-implementation-status.md`，逐 WP 标明 Implemented、Compiled only、External evidence required 或 Partially implemented，并列出当前文件/脚本证据和剩余完成证据。计划 completion checklist 链接到该索引。明确禁止以此文件将 G1–G5 标记通过。

### 需要人类复核的点

状态表中的 physical、credential、hosting、D3–D5 事项仍由维护者或独立 reviewer 提供证据；首次正式 release 前需逐项复核，不能仅按本地实现状态批准发布。

### 测试与验证结果

Markdown 表和链接路径、`git diff --check` 均通过；未执行 build、test、app launch、网络或发布操作。验证时稳定签名 Debug app 仍为 PID 87037。

## 2026-11-03 19:07 CST Focus-follows-mouse topology injection

### 发现的事实

ScreenTopologyClient 已进入 Screens 状态更新，但 FocusFollowsMouseManager 仍直接读取 `Screen.availableScreens` 来把鼠标点映射到显示器，导致同一显示器拓扑在两个核心路径中不一致。

### 偏离原计划

无。按用户 TCC 边界只编译，未启动 global mouse monitor、test host 或 app。

### AI 自作主张的决策

FocusFollowsMouseManager 和 FocusTransitionCoordinator 均新增带默认系统值的 ScreenTopologyClient 参数，WindowManager 将已有 client 传入。保留默认行为和 public initializer 调用兼容性；不改变 focus 选择算法。

### 需要人类复核的点

focus-follows-mouse 的真实 global monitor、multi-display offset 和 hot-plug 行为尚未运行；应在 dedicated CI 或 macOS 27.2 physical matrix 执行。当前运行的 app 未载入本轮源码，避免重启和潜在 TCC 影响。

### 测试与验证结果

`xcodebuild build-for-testing` 在独立 DerivedData 输出 `TEST BUILD SUCCEEDED`，未执行 test 或 launch。SwiftLint 0 violations、`git diff --check` 通过；Debug app 保持 PID 87037、18:45:54 文件。

## 2026-11-03 19:10 CST Model event posting adapter coverage

### 发现的事实

EventPostingClient 已覆盖 Space drag 和 mouse-follows-focus，但 AXWindow.raise() 的 mouse-follows-focus 回移及 AMScreen.focusScreen 仍在 Model 层直接创建/投递 CGEvent，adapter 不是全路径唯一入口。

### 偏离原计划

无。按用户 TCC 边界只编译；不执行新 adapter test 或任何 CGEvent 投递。

### AI 自作主张的决策

将 EventPostingClient 移到 CGInfo 的 Model 边界，令 WindowManager、SpaceDragEventClient、AXWindow 和 AMScreen 复用同一 cghid implementation。保留各调用点已有的焦点/失败语义，未引入自动重试或修改 event flags。

### 需要人类复核的点

EventPostingClient 的实际 EventTap、辅助功能授权、鼠标移动和焦点转换仍须在 dedicated CI/macOS 27.2 physical matrix 验证。fixture event test 仅完成编译，未在当前桌面运行。

### 测试与验证结果

`xcodebuild build-for-testing` 输出 `TEST BUILD SUCCEEDED`，直接 CGEvent 创建/投递搜索仅保留在 EventPostingClient。SwiftLint 0 violations、`git diff --check` 通过。未启动 app/test host；Debug app 保持 PID 87037、18:45:54 文件。

## 2026-11-03 19:40 CST 已批准稳定签名 runtime evidence

### 发现的事实

用户明确批准本机稳定签名 runtime test。`Scripts/dev-test.sh` 使用 Amethyst Dev 签名的 DevTestDerivedData host 完整运行了当前 suite；test host 验证通过且没有残留运行进程。测试日志包含 `com.apple.linkd.autoShortcut` connection errors，但 268 tests 全部通过。当前 macOS 26 runtime diagnostics 显示 Accessibility true、Secure Input false、Separate Spaces false、Space contract ok、current Space 222/type 4。

### 偏离原计划

无。当前机器符合 macOS 26.0 deployment-floor 证据，但 physical preflight 明确失败于 macOS 27.2 gate；不将此运行冒充为 macOS 27.2 release evidence。

### AI 自作主张的决策

按批准执行 `dev-test.sh` 全量 suite，并运行 unsigned release pipeline；再生成 `build/physical-validation/macos-26-runtime-20261103T113850Z/` collection bundle。该 bundle 保留 machine/OS/Xcode/SDK/display/debug-info 与 preflight 结果，实施状态表将其明确标为非 27.2 gate。

### 需要人类复核的点

`com.apple.linkd.autoShortcut` error 未造成 test failure，但若在正常运行可见，需要在 macOS 27.2 dedicated runner 复核。D3–D5、Developer ID/notarytool/production feed 和 27.2 matrix/soak 仍是 release blocker。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 268 tests、0 failures，test host `codesign --verify --deep --strict` 通过且 Authority 为 Amethyst Dev。unsigned release pipeline 通过（minimum 26.0、arm64-only、manifest 13 dependencies）。physical evidence collection 的 preflight status 为 1，原因是 macOS 26.6.2 而非 27.2；这是预期且已记录。

## 2026-11-03 20:19 CST D4 macOS 27.2 验证暂缓

### 发现的事实

维护者确认不需要为当前使用专门执行 macOS 27.2 physical matrix 或 48 小时 soak，理由是当前目标是 macOS 26.6.2 上使用，且没有需要等待 27.2 的产品改动。现有 macOS 26.6.2 stable-signed runtime 已有完整 suite、Space/TCC diagnostics 和 unsigned arm64 archive evidence。

### 偏离原计划

原计划将 macOS 27.2 作为 release-blocking runtime baseline。按维护者决定改为暂缓的后续验证：当前使用/代码发布以 macOS 26.6.2 stable-signed runtime 为基线；没有 27.2 physical matrix 时不得声称已完成 27.2 真机验证。

### AI 自作主张的决策

无。仅将维护者决定同步到 adaptation plan、support policy、validation checklist、implementation status 和 maintainer handoff；保留完整 27.2 checklist/script，以便未来恢复时不丢失验收模板。

### 需要人类复核的点

D3 private Space failure policy 与 D5 Sparkle trust 仍需维护者决定。若未来要对外宣传 macOS 27.2 已验证，必须恢复 D4 matrix/soak，不能引用当前 macOS 26 结果替代。

### 测试与验证结果

文档一致性搜索未发现残留“macOS 27.2 当前 release baseline/hard blocker”表述，`git diff --check` 通过。未执行 build、test、app launch、网络或发布操作。

## 2026-11-03 20:24 CST 发布事务暂缓

### 发现的事实

维护者进一步确认 Developer ID、notarization、生产 Sparkle key、appcast 托管/发布/撤回和公共 rollout 均暂不开展。此前 D4 已暂缓，但 D5/WP6/WP8 状态仍可能被解读为当前待办。

### 偏离原计划

原计划的 WP6/WP8 是 release gate。按维护者决定改为暂缓，不再作为当前 macOS 26.6.2 使用或代码发布的前置工作；恢复发布时仍需完整执行。

### AI 自作主张的决策

无。仅把维护者决定同步到 adaptation plan、support policy、implementation status、validation checklist 和 maintainer handoff。保留所有签名/appcast 脚本及操作说明，未创建凭据、未联网发布、未修改 feed。

### 需要人类复核的点

当前唯一仍需维护者决定但不影响日常使用的是 D3：是否正式接受“Space API 失败仅禁用 Space commands，普通 tiling/focus/跨屏移动继续”的策略。未来恢复发布时，需要重新决定 D5 并按 handoff 配置所有生产资源。

### 测试与验证结果

文档搜索未发现旧 D5 awaiting 或 macOS 27.2 hard-blocker 文案，`git diff --check` 通过。未执行 build、test、app launch、网络、凭据或发布操作。

## 2026-11-03 21:18 CST Display × Space layout persistence and per-window tiling

### 发现的事实

ScreenManager 已按 display cache 与 Space UUID 分离 layout，但原先只在 app termination 时保存整个 WindowManager，用户切换显示器/桌面后刚选的 layout 在异常退出前可能丢失。状态菜单也未显示 Layouts action 实际作用于哪块显示器/哪个 Space。每窗口退出 tiling 的能力已存在为 Toggle Float shortcut，但没有 status menu 入口，容易被全局 Disable Tiling 淹没。

### 偏离原计划

维护者明确旧版 0.24.3 upgrade/rollback compatibility 不在当前范围；WP5 的该项验证从当前 use/code-release gate 中移除。实现重点转为当前 Display × Space layout 使用体验和 focused-window control。

### AI 自作主张的决策

ScreenManagerDelegate 新增 persistent state change callback；WindowManager 将它转发给 AppDelegate 的 VersionedStatePersistence，因此 layout selection 和 layout state update 在已知 Space 上立即写入。Layouts submenu 添加 disabled target item，使用显示器本地名称和 Space ID。status menu 增加动态的 Disable/Enable Tiling for Focused Window，复用既有 toggle-float 语义：窗口保持打开，仅在 floating 与布局管理之间切换；全局 Disable Tiling 保留。

### 需要人类复核的点

当前 global layout list、margins、window max count 和快捷键仍是全局设置；如果“单独配置”还要求这些按 Display × Space 分叉，需要单独定义 schema/UX。实际 status menu 的本地名称、Space target 和 focused-window action 已进入稳定签名 app，但用户可按日常使用确认显示文案。Space 名称不是公开 API，因此目前显示 Space ID 而非 Mission Control 用户命名。

### 测试与验证结果

新增 immediate persistent state callback、layout target presentation、focused-window tiling presentation tests；稳定签名 `dev-test.sh` 完成 274 tests、0 failures。unsigned release pipeline 通过（minimum 26.0、arm64-only、manifest 13 dependencies）。SwiftLint 与 `git diff --check` 通过。稳定签名 Debug app 已于 21:13:45 重新构建；之后 release archive 未替换该文件。

## 2026-11-03 21:56 CST 按显示器与桌面关闭 Tiling

### 发现的事实

维护者的“按窗口关闭”实际是“按桌面关闭 Tiling”。先前状态菜单的 focused-window action 会在打开菜单后丢失 AX focus，从而错误显示 `No Focused Window`，不适合作为该功能的交互。当前实现把开关状态保存在每个 ScreenManager 的 `tilingEnabledBySpaceUUID` 中，因此目标粒度是 Display × Space；该状态与布局选择一起即时持久化。

### 偏离原计划

原计划错误地把需求解释为 focused-window tiling。收到澄清后，已移除该菜单逻辑，改为 `Disable/Enable Tiling for This Display & Space`。全局 Disable Tiling 仍保留，窗口级暂时浮动仍由既有 Toggle Float shortcut 负责。

### AI 自作主张的决策

将菜单标题固定描述为当前显示器和 Space，而不根据焦点窗口决定可见性；在未知 legacy Space descriptor（type 0 且 UUID 为空）出现时保留最后一个已知 Space 的布局状态，避免该 descriptor 将用户选择覆盖为默认 tall。没有把 margins、window-max-count 或快捷键拆成 Display × Space 配置，因为维护者尚未提出该范围。

### 需要人类复核的点

本机 runtime diagnostics 报告 `Separate Spaces: false`，所以 macOS 会让所有显示器一起切换桌面；若要让不同显示器真正独立停留在不同桌面，需要在“桌面与程序坞”启用 Displays have separate Spaces。系统仍偶发返回 `id=1, type=0, uuid=` 的未知当前 Space descriptor；代码已防止其覆盖状态，但需要维护者在日常桌面切换中确认 status-menu target 与实际桌面一致。

### 测试与验证结果

稳定签名 `Scripts/dev-test.sh` 完成 275 tests、0 failures，结果为 `build/dev-test-evidence/20261103T135440Z.xcresult`。`Scripts/dev-build.sh --run` 重启 Debug app，签名为 `Authority=Amethyst Dev`；`--debug-info` 显示 Accessibility trusted、Secure Input false、Space contract ok（4 个 user Spaces）。`Scripts/release-pipeline.sh unsigned` 通过：deployment floor 26.0，app 和 Sparkle 嵌套组件为 arm64。archive 仅产生既有第三方 Silica umbrella-header warnings。

## 2026-11-03 22:04 CST Separate Spaces 命令行诊断修复

### 发现的事实

维护者截图显示“显示器具有单独空间”已开启，但直接执行 `Amethyst --debug-info` 曾报告 `Separate Spaces: false`。原因是该命令行路径在 `NSApplicationMain` 之前读取 `NSScreen.screensHaveSeparateSpaces`；在未初始化 AppKit 的进程中该值为 false。先访问 `NSApplication.shared` 后，同一 API 在本机返回 true，且当前焦点显示器的 user Space 为 222。

### 偏离原计划

先前把未初始化命令行进程的诊断值当作系统设置状态，错误地建议维护者开启已开启的设置。修复范围仅为诊断读取顺序；不改变 GUI 运行时的 Display × Space 路由，也不修改任何用户设置。

### AI 自作主张的决策

`DebugInfo.separateSpacesAreEnabled()` 先初始化共享 AppKit application，再读取 `NSScreen.screensHaveSeparateSpaces`。新增注入闭包的 unit test 验证初始化先于读取。读取 `EncodedWindowManager` 时发现 3 个显示器 namespace 和 7 条 Space layout state；其中存在一个历史遗留的空 Space UUID 条目。该条目已被当前 unknown-descriptor 防护忽略，本轮不清除已有用户状态。

### 需要人类复核的点

空 Space UUID 条目来自旧的未知 legacy descriptor；它当前不参与 Space 更新，但未来若要清理，应先获得维护者对删除保存状态的明确授权。第二和第三显示器当前仍报告 type 0 Space descriptor；non-empty UUID 被现有分类视为可恢复的用户 Space，真实切换/恢复效果仍需要维护者日常使用确认。

### 测试与验证结果

稳定签名 `Scripts/dev-test.sh` 完成 276 tests、0 failures，结果为 `build/dev-test-evidence/20261103T140318Z.xcresult`。`Scripts/dev-build.sh --run` 重启 `Authority=Amethyst Dev` 的 Debug app；修复后的 `--debug-info` 显示 `Separate Spaces: true`、Accessibility trusted、current Space `222/type 4`、Space contract ok。`git diff --check` 尚待本 milestone 追加后执行。

## 2026-11-03 22:14 CST 本地 Release candidate DMG

### 发现的事实

维护者要的是本机可安装的 Release 配置 DMG，而不是 ZIP 或公开 release。现有 `ci-archive.sh` 能构建 unsigned arm64 Release archive 并检查 deployment floor 26.0，但项目没有 DMG 打包脚本；生产 Developer ID、notarization、Sparkle appcast 与公开发布仍处于暂缓状态。

### 偏离原计划

先生成的本地 ZIP 不作为交付物。按维护者澄清，改为直接从最新 `Amethyst.app` Release archive 制作可挂载的 DMG；未推送代码、创建 tag、上传产物或变更 appcast。

### AI 自作主张的决策

使用本机稳定 `Amethyst Dev` identity 对 Release app 重签名，然后制作只读压缩 DMG。此选择让当前 Mac 的 TCC identity 保持稳定；没有冒充 Developer ID，也没有运行不适用于自签名包的 Gatekeeper/notarization 成功断言。

### 需要人类复核的点

该 DMG 仅适用于当前已信任 `Amethyst Dev` identity 的开发 Mac；其他机器不会获得 Developer ID/notarization 信任。若需要 GitHub/public release，维护者须恢复暂缓的证书、notarytool、Sparkle key、appcast 托管、tag 和发布授权流程。

### 测试与验证结果

`Scripts/release-pipeline.sh unsigned` 通过，archive contract 为 minimum 26.0、所有 Mach-O 为 arm64。DMG `build/Amethyst-0.24.3-129-macos26-arm64-local-20261103T1414Z.dmg` 的 `hdiutil verify` 通过；只读挂载后仅有 `Amethyst.app`，其 `codesign --verify --deep --strict` 通过，随后已卸载。SHA-256 为 `d2adfef113c770a631c4d1a4740164ce16338c1ae44a78ed040a7ba7d52a1e96`。


## 2026-11-04 14:13 CST 按显示器默认配置与登录项提示

### 发现的事实

主显示器的桌面 Space 由 CGS 报告为 id 1、type 0、UUID 为空，且没有 `fs_wid`；同一显示器上 type 4 的 Space 带 `fs_wid`、`pid` 与 `WallSpace`，是 fullscreen 应用 Space。既有判定把 type 4 当作用户桌面、把空 UUID 的 type 0 当作 legacy 忽略，于是 per-Space 状态键落在 fullscreen Space（8DCDBCBA / 11190CE0）上，桌面上的 layout 与 tiling 状态没有对应的键，表现为实际 Space 与保存的窗口状态不一致。`~/Library/Preferences/com.amethyst.Amethyst.plist` 中该显示器只保存了 fullscreen Space 的条目，主桌面没有条目。

### 偏离原计划

本轮原定目标只是修复登录项菜单提示；用户随后要求废除“看起来友好的默认方式”，改为按显示器设置默认开关与 layout，并提供可视化。实现范围因此扩展为 Space 判定、状态键、per-display 默认与 Displays 偏好页。

### AI 自作主张的决策

新增 `DisplayDefaults`，按显示器标识保存默认 tiling 开关与默认 layout key，存放于 `display-defaults` 键。新 Space 在显示器未配置默认时 tiling 默认关闭，不再默认开启；layout 仍从全局 layouts 列表初始化，默认选择取显示器配置。空 UUID 的桌面用 `display:<screenID>` 作为 Space state key，不再作为 legacy descriptor 忽略。fullscreen Space 改由 `fs_wid` 识别，type 4 但带 `fs_wid` 的 Space 不再计入用户桌面。保留全局 layouts 列表作为可选布局池，没有在本轮移除。登录项在 requiresApproval、notFound 与未知状态下改为可点击并弹出系统设置指引，打开状态菜单时刷新登录项标题与 tooltip。

### 需要人类复核的点

全局 layouts 列表仍然存在，per-display 默认只决定新 Space 的初始选择与 tiling；如果“废除”还要求移除全局列表、改成每显示器独立布局集合，需要单独确认。登录项当前仍指向 `/Applications/Amethyst.app`，新构建尚未安装到该路径，因此登录时运行的仍是旧构建，菜单提示的修复要在安装新构建后才可见。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 282 tests、0 failures，结果为 `build/dev-test-evidence/20261104T061245Z.xcresult`。`Scripts/lint.sh` 0 violations，`git diff --check` 无输出，Debug 配置构建成功。新增 Displays 偏好页只有构造级测试，未做 GUI 手动验证。

## 2026-11-04 14:17 CST 桌面 Space 收养与本地安装

### 发现的事实

安装新构建并重启后，主显示器没有生成桌面状态键，`EncodedWindowManager` 仍只包含两个 fullscreen Space 的条目。原因是 `updateSpace` 只由 `activeSpaceDidChange` 触发，启动阶段或全屏 Space 期间的切换通知可能丢失；此时 `space` 保持 nil，reflow 用的是全局列表首个布局，与保存状态不一致。补上 reflow 前的当前 Space 读取后，主显示器写出了 `display:<display-uuid>` 键，tiling 为 false，布局索引 0。

### 偏离原计划

原实现只依赖 `activeSpaceDidChange`。实测暴露启动竞态后，追加了 reflow 前的 self-heal，而不是等待下一次手动切换桌面。

### AI 自作主张的决策

在 `ScreenManager.reflow()` 前读取 `currentSpaceForScreen`，若当前 Space 是用户桌面且与已跟踪 Space 不同，则调用 `updateSpace` 收养；fullscreen 与 system Space 不收养。把 Release 构建用 `Amethyst Dev` 重新签名后安装到 `/Applications/Amethyst.app`，旧包备份在 `build/app-backups/Amethyst-20261104T1415Z.app`，未改动登录项注册。

### 需要人类复核的点

Displays 偏好页只做了构造级测试，无法在本机截屏，需要维护者手动确认布局与交互。主显示器当前没有配置 display defaults，因此 tiling 默认为关闭；需要在 Displays 页显式设置默认开关与默认 layout。全局 layouts 列表仍保留为可选布局池，是否也要移除需要单独确认。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 284 tests、0 failures，结果为 `build/dev-test-evidence/20261104T061657Z.xcresult`。`Scripts/lint.sh` 0 violations，`git diff --check` 无输出。Release 构建与 `Scripts/sign-dev-app.sh` 签名通过，`/Applications/Amethyst.app` 的 `codesign --verify --deep --strict` 通过，进程从该路径启动。安装后持久化状态新增 `display:<display-uuid>` 键。

## 2026-11-04 14:20 CST 空 UUID 桌面的布局索引键修正

### 发现的事实

`setCurrentLayoutIndex` 仍以 `space.uuid` 写入 `currentLayoutIndexBySpaceUUID`。空 UUID 桌面的布局选择因此写到空字符串键，`display:` 键保持旧索引，重新进入桌面时恢复错误布局。

### 偏离原计划

无；这是同一目标下遗漏的写入路径。

### AI 自作主张的决策

无。

### 需要人类复核的点

无。

### 测试与验证结果

新增「空 UUID 桌面的布局选择写入 display 键」测试。`Scripts/dev-test.sh` 完成 285 tests、0 failures；`Scripts/lint.sh` 0 violations；`git diff --check` 无输出；Release 重新签名并安装到 `/Applications/Amethyst.app`，`codesign --verify --deep --strict` 通过。

## 2026-11-04 14:24 CST Displays 页按桌面直接配置 layout

### 发现的事实

Displays 页此前只展示每个 Space 的当前 layout 文本，桌面 layout 仍要通过状态菜单切换；用户要求在该页直接为桌面配置 layout。

### 偏离原计划

原实现把 Displays 页定位为“每显示器默认值”配置页；按用户澄清扩展为逐桌面控件，默认值保留为新区块。

### AI 自作主张的决策

`ScreenManager` 新增 `layoutKey(for:)`、`tilingEnabled(for:)`、`setLayout(_:for:)` 与 `setTilingEnabled(_:for:)`，允许配置非当前跟踪的桌面；选择不在该 Space 现有列表中的 layout 时追加该 layout 后再记录索引。Displays 页把桌面行改为 label + layout 下拉 + Tiling 复选框，fullscreen/system Space 仅作为只读提示列出。

### 需要人类复核的点

Displays 页仍只有构造级测试，无法在本机截屏，需要维护者确认下拉与复选框的实际交互和行宽。默认值区块仍保留，语义是“新桌面默认”，与逐桌面配置分开。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 286 tests、0 failures；`Scripts/lint.sh` 0 violations；`git diff --check` 无输出。Release 构建、`Amethyst Dev` 签名与 `codesign --verify --deep --strict` 通过；`/Applications/Amethyst.app` 与构建产物 SHA-256 一致并已重启。

## 2026-11-04 14:33 CST 多桌面枚举与实时刷新

### 发现的事实

维护者截图时主显示器只有 Space 1 一个桌面；随后在 14:29 与 14:31 分别创建了 Space 85（88F61FBE）和 Space 91（3E6CB12D）。CGS 的 `Spaces` 数组会列出这些新桌面，Displays 页的 `spacesForScreen` 也能读到，但页面只在 `viewWillAppear` 时重建，面板打开期间新建的桌面不会出现，看起来像“每台显示器只列一个桌面”。

### 偏离原计划

原实现只做打开时加载，没有监听 Space 变化；按维护者反馈补上实时刷新与手动刷新入口。

### AI 自作主张的决策

Displays 页在 `viewWillAppear` 注册 `NSWorkspace.activeSpaceDidChangeNotification` 与 `NSApplication.didChangeScreenParametersNotification`，`viewWillDisappear` 注销；顶部加 Refresh 按钮，覆盖“创建桌面但未切换”这类不触发通知的情况。桌面行改为按 Spaces 顺序编号显示 `Desktop N (Space id, current)`，fullscreen/system Space 仍只读列出。

### 需要人类复核的点

创建桌面是否会稳定触发 `activeSpaceDidChange` 取决于 Mission Control 的行为；未触发时需要点 Refresh。三台显示器目前只有主显示器有多个桌面（Space 1/85/91），其余各一个。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 286 tests、0 failures；`Scripts/lint.sh` 0 violations；`git diff --check` 无输出。Release 构建、签名、`codesign --verify --deep --strict` 通过，安装产物与构建产物 SHA-256 一致并已重启。`--debug-info` 现在报告主显示器 `spaces=[1:0, 85:0, 91:0, 45:4, 28:4]`，用户桌面数为 5。

## 2026-11-04 14:42 CST Displays 页按 HIG 重做

### 发现的事实

旧 Displays 页把实现细节直接放进界面：monospaced 的 Display ID、`Space 45 (fullscreen)` 这类编号、`Other Spaces: …` 调试行，没有信息层级也没有对齐，不符合 macOS Human Interface Guidelines 对 Settings、Labels 与 Layout 的要求。

### 偏离原计划

原实现只求把状态显示出来；按维护者要求改为遵循 HIG 的信息层级与控件规范。

### AI 自作主张的决策

参照 HIG：Settings 页使用不可自定义工具栏、窗口标题跟随当前 pane、最小化按钮移除；Labels 使用系统字体与 label/secondary/tertiary 颜色；Layout 使用 20pt 边距、固定列宽对齐、分隔线分组，并把控件放在内容顶部而不是窗口底部；Toggles 使用窗口主体的 checkbox。界面上移除 Display ID 与 “Other Spaces” 调试行，桌面按 `Desktop 1…N` 编号，当前桌面用 tertiary “Current”，全屏与系统 Space 不再列出；默认值行改名为 “New desktops”。同时移除 Refresh 按钮，改为监听 `activeSpaceDidChange`、`didBecomeActive` 与屏幕参数变化自动刷新；替换两个已废弃的 SF Symbol。

### 需要人类复核的点

无法截屏验证视觉；需要维护者确认列宽、间距、字号与当前桌面标记的观感。全屏与系统 Space 已从页面移除，如果仍需要只读展示，需要另行确认位置。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 286 tests、0 failures；`Scripts/lint.sh` 0 violations；`git diff --check` 无输出；Release 构建通过且 ibtool 不再产生 SF Symbol 废弃警告；签名、安装到 `/Applications/Amethyst.app`、`codesign --verify --deep --strict` 与 SHA-256 一致性均通过，应用已重启。

## 2026-11-04 14:57 CST 修复布局不生效与统一布局入口

### 发现的事实

临时诊断日志显示：在 Space 91 上，`Reflow check ... tracked=91 current=91 tiling=false`；新窗口的 `.add` 事件已经到达，但 reflow 因 `tiling=false` 提前返回，没有任何 frame 应用。原因有两个：新桌面在废除隐式默认后初始 tiling 为 false，而在 Displays 里选择 layout 并不会打开 tiling；另外 `setLayout` 追加的桌面专属布局（不在全局 layouts 列表里的那些）在启动解码时被全局列表覆盖，索引从 5 回退到 0，形成用户看到的“降级”。状态菜单的 Layouts 子菜单只列当前桌面的列表，而 Displays 下拉列全部可用布局，两边集合不一致放大了这个问题。

### 偏离原计划

原实现把布局配置分散在全局 Layouts 列表、状态菜单和 Displays 页三处；按维护者要求收敛到 Displays 一处，并保证选择后立即生效且重启不丢失。

### AI 自作主张的决策

`ScreenManager.setLayout` 现在同时把该 Space 的 tiling 设为 true，Displays 页的 Tiling 复选框同步勾选。`decodedLayouts` 改为：配置中的布局按配置顺序保留已保存实例，Space 专属布局追加在末尾，不再丢弃；索引按 layout key 重新定位，避免启动降级。按维护者要求删除状态菜单的 Layouts 子菜单和 Preferences 的 Layouts 面板，移除 `LayoutsPreferencesViewController`、对应 xib、pbxproj 条目以及菜单 target 相关代码与测试；全局 `layouts` 列表保留为新桌面的种子，但不再有编辑界面。顺带修复 `--log` 启动参数：main.swift 在 ArgumentParser 之前处理该参数，否则会被当作未知选项退出。

### 需要人类复核的点

状态菜单不再提供布局切换，切换布局现在需要打开 Preferences → Displays；如果仍需要快速切换，需要另定入口（例如状态菜单里直接列当前桌面的布局）。全局 `layouts` 种子列表已无 UI，只能通过配置文件修改。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 286 tests、0 failures；更新了删除布局与移除布局相关的解码测试以匹配“保留 Space 专属布局”的新语义。`Scripts/lint.sh` 0 violations；`git diff --check` 无输出；Release 构建通过（仅第三方 Silica umbrella header 警告），签名后安装到 `/Applications/Amethyst.app`，`codesign --verify --deep --strict` 与 SHA-256 一致性通过，应用已重启。

## 2026-11-04 16:06 CST 内部记录脱敏

### 发现的事实

`docs/internal/implementation-notes.md` 含两处主显示器标识（一处完整、一处截断），属于设备级标识；仓库其他文档未发现用户名、家目录、邮箱、IP、内网地址或密钥。PID、构建路径、macOS/Xcode 版本与 DMG 摘要属于环境信息，保留用于复现。

### 偏离原计划

按 append-only 约定历史 milestone 不应改写；按维护者要求，对其中两处显示器标识做最小脱敏，保留语义与上下文。

### AI 自作主张的决策

只替换显示器标识为 `<display-uuid>`，不改写其余历史内容；PID、构建路径与环境版本保留。

### 需要人类复核的点

已提交的历史（`808fe88` 及更早）仍包含原显示器标识。如果公开仓库连带历史发布，需要用 `git filter-repo` 清理或从干净历史重新发布；当前只清理了工作区文件。

### 测试与验证结果

脱敏后在工作区（排除 `build/` 与 `.git/`）搜索不到原显示器标识；文档改动不影响代码，未重跑测试。

## 2026-11-04 16:27 CST 独立 fork 身份与移除 Sparkle

### 发现的事实

应用仍使用上游的 `com.amethyst.Amethyst`、`0.24.3 (129)`、`ianyh.com` 的 Sparkle feed，并依赖 Sparkle 包与更新菜单。维护者决定走独立 fork 路线，明确不要 Sparkle 更新渠道，bundle 改为 `com.totoleo.Amethyst`，版本改为 `0.25.0`。

### 偏离原计划

原 fork 清单计划更换 feed 与 Sparkle 密钥；维护者改为完全移除更新渠道，因此直接删除 Sparkle 依赖、菜单项、canary 设置与相关脚本，而不是替换 feed。

### AI 自作主张的决策

移除 `import Sparkle`、`SPUStandardUpdaterController`、`SparkleFeedConfiguration`、检查更新菜单、`use-canary-build` 配置、Debug 页的更新选项、Sparkle 包依赖与 Package.resolved 条目；删除 appcast、密钥注入、密钥配对、EdDSA 自测等 10 个脚本；简化 release pipeline 与 preflight 为 Developer ID + notarytool；CI 去掉 Sparkle 步骤；README/configuration/glossary 同步清理。安装时把旧的 `com.amethyst.Amethyst` UserDefaults 导入到 `com.totoleo.Amethyst`，保留布局与快捷键配置。

### 需要人类复核的点

旧 bundle id 的登录项/BTM 与 TCC 条目可能仍残留，需要确认是否手动清理；`docs/macos-27-*` 与 `release-maintainer-handoff.md` 仍含 Sparkle 内容，尚未改写；设置已自动迁移，如需全新状态可删除 `com.totoleo.Amethyst` 域后重来。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 281 tests、0 failures（移除了 5 个 Sparkle feed 测试）；`Scripts/lint.sh` 0 violations；Release 构建与 `Scripts/sign-dev-app.sh` 签名通过，安装到 `/Applications/Amethyst.app` 后 `CFBundleIdentifier=com.totoleo.Amethyst`、版本 `0.25.0 (130)`，`--debug-info` 显示 Accessibility trusted、二进制中无 Sparkle 字符串，launchd 出现 `application.com.totoleo.Amethyst` 登录项。

## 2026-11-04 16:33 CST 应用改名为 Mon

### 发现的事实

应用此前产品名为 Amethyst、bundle 为 `com.totoleo.Amethyst`；菜单、登录项提示、隐私政策与文档仍使用 Amethyst 名称。维护者选择完整改名，要求应用文件为 Mon.app、名称为 Mon、bundle 改为 `com.totoleo.Mon`。

### 偏离原计划

无；这是上一轮 fork 身份改造的延续。保留 Xcode target、scheme、Swift module 名 Amethyst，避免破坏测试宿主、xib 的 customModule 与现有脚本调用。

### AI 自作主张的决策

`PRODUCT_NAME` 改为 Mon、`PRODUCT_MODULE_NAME` 保持 Amethyst、bundle 改为 `com.totoleo.Mon`；菜单与登录项文案、README、隐私政策、配置与自定义布局文档改用 Mon；自定义布局目录改为 `~/Library/Application Support/Mon/Layouts/`，首次启动时从旧 Amethyst 目录复制；设置从 `com.totoleo.Amethyst` 导入到 `com.totoleo.Mon`；脚本与 CI 中的 app/archive/zip 路径和签名 identifier 同步更新。配置文件仍保留 `.amethyst.yml` 以兼容现有配置。

### 需要人类复核的点

旧 bundle id 的 TCC 与登录项条目可能残留；`.amethyst.yml` 配置文件名与 `default.amethyst` 资源名未改；`docs/macos-27-*` 与 `release-maintainer-handoff.md` 仍含 Sparkle 内容，待后续清理。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 281 tests、0 failures；`Scripts/lint.sh` 0 violations；Release 构建与签名通过，`/Applications/Mon.app` 的 `CFBundleName=Mon`、`CFBundleIdentifier=com.totoleo.Mon`、版本 `0.25.0 (130)`；`--debug-info` 显示 Accessibility trusted，二进制无 Sparkle 字符串，自定义布局已迁移到 Mon 目录，launchd 出现 `application.com.totoleo.Mon` 登录项。

## 2026-11-04 16:40 CST 完整改名为 Mon 与许可证整理

### 发现的事实

上一轮只改了产品名与 bundle，Xcode target/scheme/module、工程与工作区文件、配置文件、默认资源、脚本与文档仍保留 Amethyst 名称；LICENSE.md 只有上游版权行，README 仍含上游徽章与捐赠段落。

### 偏离原计划

上一轮为降低风险保留了内部名称；维护者要求把这些残留一起改掉，并按开源社区规则更新 README 与 license。

### AI 自作主张的决策

把 target、scheme、Swift module、工程、工作区、测试 target 全部改为 Mon/MonTests；配置文件改为 `~/.mon.yml` / `~/.config/mon/mon.yml`，保留 `.amethyst.yml` 作为后备读取；资源改为 `default.mon`；自定义布局目录已在上轮迁移；命令键 `relaunch-amethyst` 改为 `relaunch-mon`；删除构建产物中残留的 `default.amethyst`。README 重写为 fork 说明、与上游差异、构建方式、无更新渠道、许可与上游支持；LICENSE 保留原 MIT 全文与 Ian 版权，并追加 Mon 贡献者版权。上游 URL 与上游项目名保留，避免错误归属。签名身份仍为 `Amethyst Dev`，因为换证书会重置本地 TCC 授权。

### 需要人类复核的点

本地开发签名身份 `Amethyst Dev` 未改名；`docs/macos-27-*` 仍含 Sparkle 历史内容；旧 `com.totoleo.Amethyst` 的 TCC/登录项条目可能残留，需要时手动清理。

### 测试与验证结果

`Scripts/dev-test.sh` 完成 281 tests、0 failures；`Scripts/lint.sh` 0 violations；Release 构建与签名通过，安装到 `/Applications/Mon.app` 后 `CFBundleName=Mon`、bundle `com.totoleo.Mon`、版本 `0.25.0 (130)`，`--debug-info` 显示 Accessibility trusted，Resources 中只剩 `default.mon`，应用已重启。

## 2026-11-04 17:08 CST 三场景构建入口与签名隔离

### 发现的事实

现有 `dev-build.sh` 适合本地 Debug 迭代，`release-pipeline.sh unsigned` 适合无签名 archive gate，但用户自行安装与 CI 没有各自明确的顶层入口；本地 `Amethyst Dev` 与面向其他安装者的本地签名也没有区分。

### 偏离原计划

原计划只在 `release-pipeline.sh` 增加安装模式；按维护者要求改为本地开发、用户自行安装、CI 构建三个独立入口，同时保留 Developer ID 公共分发模式。

### AI 自作主张的决策

保留 `Scripts/dev-build.sh --run` 作为本地开发入口，显式固定 `Amethyst Dev` 以延续当前机器的 TCC 授权；新增 `Scripts/user-install.sh`，调用 `release-pipeline.sh local` 构建 Release archive、以独立的 `Mon Dev` 自签名、备份旧安装并替换 `/Applications/Mon.app`；新增 `Scripts/ci-build.sh` 聚合环境证据、support/toolchain gates、lint、测试、Release custom layout 与 unsigned archive，禁止创建身份、安装或启动 GUI；`release-pipeline.sh` 改为 `ci|local|signed` 三种模式，`unsigned` 仅作为临时兼容别名；`signed` 继续要求 Developer ID 与 notarization，不使用 `Mon Dev`。签名 bootstrap 与 sign 脚本改为接收身份名称，分别持久化不同证书。

### 需要人类复核的点

`Mon Dev` 是本地自签名证书，不提供 Gatekeeper 公共信任；真正对外分发仍须使用 `release-pipeline.sh signed`。`unsigned` 兼容别名何时删除尚未决定。

### 测试与验证结果

所有新增和修改的 shell 脚本通过 `bash -n`。`dev-build.sh` 构建 Debug 并显示 `Authority=Amethyst Dev`；`user-install.sh --no-run` 在隔离安装路径完成 Release 构建、`Authority=Mon Dev`、`codesign --verify --deep --strict` 与版本 `0.25.0` 验证；`ci-build.sh` 完整执行 281 tests、lint、Release custom layout、unsigned archive 与 manifest gates 并通过。仅有既有第三方 Silica umbrella-header warnings。
