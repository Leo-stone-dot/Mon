# macOS 27 Validation Checklist

> **Archived historical checklist.** This template preserves the 2026-11-03
> adaptation gates and is not the current release contract. Sparkle/appcast and
> Layouts UI items below are retained only as historical evidence requirements;
> Mon now has no update feed, and layout configuration is in Preferences →
> Displays. Use the current support policy and maintainer handoff for any new
> validation session.

> D4 note (2026-11-03): macOS 27.2 physical validation is deferred by the
> maintainer. This checklist remains the required evidence template if that
> validation is resumed; its unchecked 27.2/soak items do not block current
> macOS 26.6.2 use or code-release work, and no release may claim 27.2
> physical verification without them.

> Release note (2026-11-03): production signing, notarization, Sparkle feeds,
> appcast publication/withdrawal, and public rollout are also deferred by the
> maintainer. Keep G4/G5 unchecked until that work is resumed.

Copy this file per release candidate and fill every evidence field. A checkbox
without machine, build, result, and artifact references is not release evidence.

## Session identity

- RC version/build:
- Git commit:
- Artifact SHA-256:
- Machine model/chip:
- Architecture (`uname -m`):
- macOS version/build (`sw_vers`):
- Xcode build (`xcodebuild -version`):
- SDK (`xcrun --sdk macosx --show-sdk-version`):
- Displays and arrangement:
- Separate Spaces:
- Stage Manager:
- Mission Control animation settings:
- Accessibility permission state at start:
- Tester and timestamp:
- Logs/screenshots directory:

## G0 — toolchain

- [ ] Clean resolve uses committed `Package.resolved` without update.
- [ ] `Scripts/verify-toolchain-locks.sh` passes: Mint tools, fastlane, and
      SwiftPM revisions are pinned; bootstrap does not upgrade Brewfile
      dependencies; Xcode build phases do not format source.
- [ ] Debug arm64 build passes.
- [ ] Release arm64 build/archive passes.
- [ ] All unit tests run and pass.
- [ ] Build leaves `git diff --exit-code` clean.
- [ ] Environment/dependency graph artifact is attached.
- [ ] `build/release-manifest.json` records version/build, commit, OS/Xcode/SDK,
      dependency lock hash and resolved revisions, and every Mach-O architecture.

Evidence:

## G1/G2 — core runtime and Space safety

- [ ] Accessibility fresh-install denial is recoverable.
- [ ] Accessibility grant enables management without relaunch loop/crash.
- [ ] Runtime permission revoke is recoverable and bounded.
- [ ] Local runtime tests use `Scripts/dev-test.sh` or a dedicated CI runner;
      they do not launch an unsigned Accessibility test host in a developer's
      normal desktop session.
- [ ] Window create/destroy/move/resize/focus/minimize passes.
- [ ] AppKit, SwiftUI, Electron/Chromium, and Catalyst fixtures pass.
- [ ] Single display, hot-plug, negative origin, vertical offset, and scaled Retina pass.
- [ ] Separate Spaces on/off, full screen, and Stage Manager on/off pass.
- [ ] Private Space API behavior satisfies
      [Private macOS API Boundary](private-apis.md): missing symbol/key/type
      disables only Space-dependent features while visible active windows on the
      current display continue to tile.
- [ ] Space inventory, current Space, fullscreen Space detection, and uuidless
      desktop fallback match the installed macOS runtime.
- [ ] Space switch/throw timeout, cancellation, and termination always post mouse-up.
- [ ] Stress run has zero stuck drag, crash, and hang.

Evidence:

## G3 — services and state

- [ ] Start at Login register/unregister/status matches System Settings.
- [ ] `requiresApproval` provides an actionable path.
- [ ] Stable/canary feed selection and offline/bad-feed behavior pass.
- [ ] Legacy 0.24.3 profile upgrade/rollback is deferred by maintainer; it is
      not a current macOS 26.6.2 use/code-release gate.
- [ ] Layout choices persist independently for each display × Space target and
      Preferences → Displays identifies the target display and desktop.
- [ ] YAML, JSON, old state, corrupt state, missing JS, and throwing JS fixtures pass.
- [ ] Corrupt encoded layout state starts with default layouts, preserves the
      original state plus backup, and shows the status-menu recovery message;
      **Reset Layouts** clears only saved layout state and backup.
- [ ] \`Scripts/test-release-custom-layouts.sh\` passes after the Debug custom
      layout suite, proving the same fixtures execute in an optimized Release
      build with empty Release entitlements.
- [ ] Any removal of Debug JIT/library-validation exceptions is separately
      validated with a signed hardened Debug runtime; an unsigned XCTest build
      alone is not evidence for that removal.

Evidence:

## G4 — distribution

- [ ] `lipo -archs` returns only `arm64` for every executable.
- [ ] Built Info.plist minimum system version is 26.0.
- [ ] Nested code and top-level `codesign --verify --deep --strict` pass.
- [ ] Notarization submission succeeds and ID is recorded.
- [ ] `stapler validate` and Gatekeeper assessment pass.
- [ ] Sparkle EdDSA verification succeeds with the built app's public key;
      one-byte archive tamper, wrong signature, and wrong public key fail.
- [ ] Clean Mac download, first launch, authorization, update, and reboot pass.
- [ ] `Scripts/verify-signed-release-artifact.sh` passes on the notarized app.
- [ ] `Scripts/release-pipeline.sh signed` completes with Developer ID,
      notarytool, and Sparkle EdDSA inputs.
- [ ] `Scripts/verify-appcast.sh` passes for the signed staging appcast item.
- [ ] `Scripts/generate-appcast.sh` produces the staging feed from an
      archive directory using the paired EdDSA key, HTTPS URL prefixes, and
      the current build only; the generated feed preserves prior items.
- [ ] `Scripts/test-generate-appcast.sh` passes, proving non-HTTPS URLs and
      mismatched private keys fail, the generated item has a real EdDSA
      signature, archive length, and release-notes URL, and regenerating the
      same build does not duplicate it.
- [ ] `Scripts/test-verify-appcast.sh` passes, proving the appcast gate rejects
      missing signatures, non-HTTPS enclosures, wrong minimum OS, version,
      signature, and length mismatches.
- [ ] `Scripts/test-sparkle-eddsa.sh` passes, proving an ephemeral Ed25519 key
      signs and verifies an archive, validates it through the paired public key,
      rejects archive tampering, a wrong key, a wrong public key, and a wrong
      signature, and accepts the resulting real EdDSA signature in appcast.
- [ ] `Scripts/test-verify-sparkle-key-pair.sh` passes, proving a public key
      is derived from the configured private seed and mismatched/malformed keys
      fail before release signing.
- [ ] `Scripts/test-inject-sparkle-public-key.sh` passes, proving the release
      pipeline writes and replaces `SUPublicEDKey` and rejects malformed keys.
- [ ] The built Info.plist `SUPublicEDKey` matches the release
      `SPARKLE_PUBLIC_KEY` before signing.
- [ ] `Scripts/release-preflight.sh` passes before the signed release pipeline.
- [ ] `Scripts/release-preflight.sh --post-archive` passes after the public key
      is injected and before nested code is signed.
- [ ] `Scripts/test-release-preflight.sh` passes, proving the preflight rejects
      missing environment inputs, a malformed `SPARKLE_PUBLIC_KEY`, and a
      missing Developer ID identity.
- [ ] Signed `build/release-manifest.json` records the final ZIP path, byte
      count, SHA-256, dependency revisions, and notarization submission ID.

Evidence:

## G5 — product/support and soak

- [ ] README, target, built Info.plist, artifact, and appcast support floors agree.
- [ ] Status menu/preferences pass light/dark, scaled, English/pseudo-localized checks.
- [ ] VoiceOver and Full Keyboard Access reach all critical controls/statuses.
- [ ] P0 matrix is 100% pass; every P1 failure has owner/workaround/ship decision.
- [ ] The same RC completes a 48-hour soak including sleep/wake, display reconnect,
      and repeated Space/window churn with zero crash/hang/stuck input.
- [ ] Rollback artifact and instructions are verified on a clean macOS 27.2 Mac.
- [ ] `Scripts/capture-physical-validation-evidence.sh` output is attached for
      each physical validation session, including `debug-info.txt`.

Evidence:

## Approval

- G0 owner/date:
- G1 owner/date:
- G2 owner/date:
- G3 owner/date:
- G4 owner/date:
- G5 owner/date:
- Maintainer ship/no-ship decision:
