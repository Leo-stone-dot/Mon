# 发布交接：维护者需要做什么

> Status: deferred by maintainer on 2026-11-03. Do not create production
> credentials, publish/withdraw an appcast, or perform release approval until
> the maintainer resumes these activities.

2026-11-03：维护者明确将生产签名凭据、appcast 发布/撤回和 D3–D5 决策留给自己执行，随后暂缓全部发布事务。AI 负责代码、脚本、自动测试、诊断与操作说明；不将这些人工事项作为继续实现的阻塞，也不代替维护者签署或标记发布验证通过。

当前 macOS 26.6.2 上的本地使用可以继续走 `Scripts/dev-build.sh --run`。以下资源在对外分发、自动更新时准备；日常本地使用无需先完成。

## 1. Developer ID Application

在 Apple Developer Program 团队中申请或取得 **Developer ID Application** 证书，并在负责发布的 Mac 上安装证书及其配对私钥。仅有下载的 `.cer` 文件、没有创建证书时的私钥，无法签名。已有团队证书时使用既有管理流程。

在发布 Mac 上检查：

```bash
security find-identity -v -p codesigning
```

交接结果：有效的 `Developer ID Application: 名称 (TEAMID)` 身份及 Team ID。团队证书私钥保存在发布 Mac 的 Keychain 或团队管理的凭据库，不发送到聊天。

## 2. notarytool 凭据

用具有对应团队权限的 Apple Account 准备 app-specific password，然后执行下列命令。替换邮箱与 Team ID，密码由工具安全提示输入：

```bash
xcrun notarytool store-credentials "Amethyst-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID"
xcrun notarytool history --keychain-profile "Amethyst-notary"
```

交接结果：profile 名称 `Amethyst-notary` 和验证成功状态。profile 存在于该 Mac 的 Keychain；迁移到 CI runner 时须在 runner 上配置，不能只传同名字符串。团队也可选择 App Store Connect API key，工具支持 `--key`、`--key-id`、`--issuer`，按实际团队凭据类型配置。

## 3. 生产 Sparkle EdDSA 密钥

如果这条发布线已有密钥，继续使用既有密钥。仅在首次建立自己的发布线时生成新的一对。换密钥属于更新信任迁移，不能在正常升级中随意同时更换 Developer ID 与 EdDSA 身份。

在仓库根目录，使用当前已解析的 Sparkle 工具：

```bash
amethyst_sparkle_bin="$PWD/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
"$amethyst_sparkle_bin/generate_keys" --account amethyst-production
"$amethyst_sparkle_bin/generate_keys" --account amethyst-production -p
```

工具将私钥放进 Keychain，`-p` 仅输出公钥。当前发布脚本使用私钥文件；如由维护者选择使用这个流程，可导出到仓库外的受控目录：

```bash
umask 077
amethyst_signing_dir="$HOME/.config/amethyst-release"
mkdir -p "$amethyst_signing_dir"
"$amethyst_sparkle_bin/generate_keys" --account amethyst-production \
  -x "$amethyst_signing_dir/ed25519-private-key"
chmod 600 "$amethyst_signing_dir/ed25519-private-key"
```

交接结果：公钥字符串、私钥文件路径，以及团队内部的备份负责人和恢复办法。私钥内容不要发到聊天、提交到 Git 或加入构建日志。**公钥无需保密，可以记录在源码或发布配置中**；目前脚本选择通过 `SPARKLE_PUBLIC_KEY` 注入产物。

当前脚本对应输入：

| 输入 | 维护者准备的值 |
| --- | --- |
| `DEVELOPER_ID_APPLICATION` | 有效签名身份的名称或 SHA-1 |
| `NOTARYTOOL_PROFILE` | 已在发布机验证的 Keychain profile 名称 |
| `SPARKLE_SIGN_UPDATE` | 本次已解析 Sparkle 的 `bin/sign_update` 路径 |
| `SPARKLE_ED_KEY_FILE` | 仓库外的生产私钥文件路径 |
| `SPARKLE_PUBLIC_KEY` | 配对的公钥字符串 |
| `AMETHYST_APPCAST_PATH` | 本地待发布 XML 文件路径 |

## 4. appcast 托管、发布与撤回

维护者需要提供自己有写权限的 HTTPS 托管位置，分别存放 stable appcast、canary appcast、版本化 ZIP 和 release notes。记录上传方式、回滚权限、缓存刷新方法和发布前的 feed 备份。

源码目前的 `SUFeedURL`/`SUCanaryFeedURL` 是上游 `ianyh.com` 地址。建立自己的发布线时，把自己的 URL 交给 AI 接入并测试。上游地址不会因为本地构建而获得写权限，也不应让自建版本误读上游发布线。

代码验证就绪后的人工发布顺序：

1. 选择具有唯一 build number 的 RC，完成签名、公证、staple、Gatekeeper 和公钥验签，保存最终 ZIP、SHA-256、manifest、notary submission ID 与验证日志。
2. 在**本地 staging directory** 中保留当前 feed、最终 ZIP 和同 basename 的 release notes。先备份当前 feed，再以已公证的 app bundle 和配对密钥生成候选 feed；此步骤不上传网络：

   ```bash
   amethyst_app_path="$PWD/build/Amethyst.xcarchive/Products/Applications/Amethyst.app"
   amethyst_staging_dir="/secure/amethyst-release/stable"
   export SPARKLE_GENERATE_APPCAST="$PWD/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
   export SPARKLE_ED_KEY_FILE="/secure/amethyst-release/ed25519-private-key"
   Scripts/generate-appcast.sh "$amethyst_app_path" "$amethyst_staging_dir" \
     "https://downloads.example.com/amethyst/" \
     "https://downloads.example.com/amethyst/release-notes/"
   Scripts/verify-appcast.sh "$amethyst_staging_dir/appcast.xml" "$amethyst_app_path"
   ```

   `generate-appcast` 只为当前 build 写入 item，并保留该 staging directory 中的历史 items；staging ZIP 与 release notes 名称必须一致，且该目录应与 stable/canary 分开。
3. 上传最终 ZIP 和 release notes 到固定的版本化 HTTPS 地址。从外网重新下载，核对 SHA-256 与公钥验签；签名后不再修改 ZIP。再上传步骤 2 的通过验证的 `appcast.xml`。
4. 先在 canary/staging 验证客户端实际检查更新、下载、安装与重启，再发布 stable feed。feed 更新使用托管服务的原子替换或版本切换机制，避免客户端下载到半写入 XML。
5. 演练撤回：恢复发布前备份的 feed 或移除坏版本 item，刷新缓存，并重新请求 feed 确认不再向未升级客户端推荐坏版本。
6. 撤回 feed 不会自动把已经升级的客户端降级。已升级用户按回退文档手动安装上一签名版本，或接收 build number 更高的修复版；保留原有用户配置和旧发布物。

交接结果：四类 URL、发布/撤回负责人、上述演练的版本、时间与验证结果。上传凭据在维护者自己的环境或 CI 中使用。

## 5. D3–D5 决策记录

这些是产品发布决策，不是证书签名。为每项填写“接受/修改”、具体内容、姓名、日期和证据链接；可在下面的表格中记录，再同步到 [support policy](macos-27-support-policy.md)。

| 决策 | 当前建议 | 维护者记录 |
| --- | --- | --- |
| D3 | private Space API 失效时停用 Space 相关命令，显示原因，保留普通平铺/聚焦/跨屏移动；代码测试须证明这条降级边界。 | 待维护者填写 |
| D4 | 暂缓 macOS 27.2 真机与 48 小时 RC 验证；当前 macOS 26.6.2 stable-signed runtime 是使用/代码发布基线。恢复 27.2 matrix 前不得作 27.2 已验证声明。 | Maintainer deferred 2026-11-03 |
| D5 | 暂缓生产发布信任决策；恢复时采用 Developer ID/notarization 与 Sparkle EdDSA 双重验证。 | Maintainer deferred 2026-11-03 |

此次“由维护者办理”的指示只确定执行责任，不等于已经接受这三项的具体选项或批准发布。可安排另一台机器或测试者完成 D4，不要求升级当前工作机。

## 6. AI 仍负责的代码工作

准备好凭据不等于当前 `Scripts/release-pipeline.sh signed` 已经可用于生产发布。按本次源码核对，下列项目仍属于实现工作，不能转嫁给维护者手工补脚本：

- 将维护者的 stable/canary URL 接入目标产物并验证更新行为。
- 审核嵌套代码签名顺序及 Sparkle 裸可执行文件，并在真实 Developer ID 环境中验证。脚本按目录深度先签内部 bundle，再签父 bundle 和 app；仍须以实际产物的 `codesign --verify` 证据确认。
- 将维护者的 stable/canary URL 接入目标产物并验证客户端更新行为；本地 staging feed 已可由 `Scripts/generate-appcast.sh` 生成，但上传、撤回和实际客户端验证仍由维护者环境完成。
- 完成其余迁移代码和自动测试，提供真机 checklist。维护者在自己的发布环境执行上述生产步骤后，才填入实际验证证据。

本地实现可以持续推进。这份交接不把 G4 或整体迁移标成已经通过。

## 依据

- Apple：[Developer ID](https://developer.apple.com/developer-id/)；[Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。
- Sparkle：[基础配置与 key rotation](https://sparkle-project.org/documentation/)；[Publishing an update](https://sparkle-project.org/documentation/publishing/)。
- 已核对本机 `xcrun notarytool store-credentials --help` 和已解析 Sparkle `generate_keys --help`。
- 仓库：[release-pipeline.sh](../Scripts/release-pipeline.sh)、[release-preflight.sh](../Scripts/release-preflight.sh)、[validation checklist](macos-27-validation-checklist.md)。
