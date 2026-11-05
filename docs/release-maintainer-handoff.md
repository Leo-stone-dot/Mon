# 发布交接：维护者需要做什么

> Status: optional. Mon 没有 Sparkle 更新渠道，本地使用与 source-only
> GitHub Release 不需要先完成本页。只有维护者决定另行分发二进制时才执行。

GitHub 的 **Publish source release** workflow 只发布 tag 源码归档与说明，
不会附加应用 bundle。可选的二进制分发是独立人工流程，只需要两类凭据，
不需要 appcast 或 EdDSA 密钥。

## 1. Developer ID Application

在 Apple Developer Program 团队中取得 **Developer ID Application** 证书，并安装证书及其配对私钥。仅有下载的 `.cer`、没有创建证书时的私钥，无法签名。

```bash
security find-identity -v -p codesigning
```

交接结果：有效的 `Developer ID Application: 名称 (TEAMID)` 身份。

## 2. notarytool 凭据

使用 Apple Account 的 app-specific password 建立 Keychain profile：

```bash
xcrun notarytool store-credentials "Mon-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID"
xcrun notarytool history --keychain-profile "Mon-notary"
```

交接结果：`Mon-notary` profile 验证成功。profile 保存在发布 Mac 的 Keychain；迁移到 CI 时须在 runner 上重新配置。

## 3. 构建与分发

环境变量：

| 输入 | 值 |
| --- | --- |
| `DEVELOPER_ID_APPLICATION` | 有效签名身份的名称或 SHA-1 |
| `NOTARYTOOL_PROFILE` | 已验证的 Keychain profile 名称 |

执行：

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: …" \
NOTARYTOOL_PROFILE="Mon-notary" \
Scripts/release-pipeline.sh signed
```

产物为已签名、公证并 staple 的 `build/Mon-macos27-arm64.zip`，以及 `build/release-manifest.json`。Mon 没有自动更新；若决定分发，将 ZIP 通过独立渠道交给用户手动安装，不要把它描述为 source-only GitHub Release 的附件。分发前保留当前与上一版 ZIP 以便回滚；仓库无法为未保存的二进制提供回滚下载。

## 4. 发布检查

1. `Scripts/release-preflight.sh` 通过。
2. `Scripts/ci-archive.sh` 的 deployment floor 与架构检查通过。
3. `codesign --verify --deep --strict`、`spctl`、`stapler validate` 通过。
4. manifest 与 ZIP 的 SHA-256 一致。
5. 在干净用户环境安装一次，确认辅助功能授权与基本平铺正常。
