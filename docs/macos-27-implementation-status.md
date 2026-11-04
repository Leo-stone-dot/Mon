# macOS 27 Adaptation Implementation Status

> Snapshot: 2026-11-03. This is an evidence index, not a release approval.
> The support floor is macOS 26.0 on Apple silicon `arm64`; macOS 27.2
> physical validation remains the release runtime baseline.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| Implemented | Source, scripts, and a local reproducible check exist. |
| Compiled only | Source is included in a no-launch build, but its new runtime test has not run on the current desktop. |
| External evidence required | Completion depends on a maintainer-controlled credential, host, decision, or physical Mac. |
| Pending | No sufficient implementation/evidence is recorded yet. |

## Work package evidence

| WP | Status | Current evidence | Remaining completion evidence |
| --- | --- | --- | --- |
| WP0 support contract | Implemented | `Scripts/verify-support-contract.sh`; support policy; deployment target 26.0; arm64 archive check. | D3–D5 maintainer decisions. |
| WP1 toolchain/CI | Implemented locally | Mintfile/Gemfile.lock; `verify-toolchain-locks.sh`; non-mutating lint; resolved SwiftPM; CI requires `ci` runner label. | A dedicated labeled runner must execute the workflow. |
| WP2 AX/CGS/Screen | Implemented locally | `AccessibilityClient`, `SpaceClient`, `ScreenTopologyClient`, `EventPostingClient`; Space contract probe; secure-input transaction; fail-closed Space commands and core-tiling fallback; stable-signed macOS 26 suite. | macOS 27.2 TCC, display, Space, sleep/wake, and stress evidence. |
| WP3 login/dependencies/updater | Implemented locally | `SMAppService`, one-time migration notice, Sparkle 2 controller, pinned Silica revision, feed-selection tests. | Login Items/reboot, live stable/canary feed, bad-network tests on a physical Mac. |
| WP4 AppKit/status UI | Partially implemented | Runtime status items expose Accessibility, Space, Secure Input, and saved-layout recovery. | macOS 27.2 screenshots, VoiceOver, Full Keyboard Access, scale/localization review. |
| WP5 config/state/custom layouts | Implemented locally | Versioned state envelope/backup, immediate Display × Space layout persistence, layout key recovery across screens and Spaces, config diagnostics, Release custom-layout test gate. | Signed Hardened Debug JSC entitlement check; legacy 0.24.3 upgrade/rollback is out of current scope. |
| WP6 distribution/supply chain | Deferred by maintainer | Unsigned arm64 archive, manifest, public-key injection, key-pair/public-key verification, appcast staging generator, self-tests remain available. | Production Developer ID/notarytool/EdDSA key/hosting work is postponed. |
| WP7 matrix/soak | Deferred by maintainer | Checklist and physical evidence capture script exist; macOS 26.6.2 bundle is collected. | Restore macOS 27.2 physical matrix, M1/current hardware, and 48-hour soak before claiming 27.2 validation. |
| WP8 rollout/support | Deferred by maintainer | Support guide, troubleshooting, validation checklist, issue template, maintainer handoff remain available. | Public rollout, fresh-install walkthrough, and published rollback evidence are postponed. |

## Runtime-test safety boundary

The current development desktop has a stable `Amethyst Dev` signing identity.
Do not run raw `xcodebuild test` there after granting Accessibility: an
unsigned test host can obtain a new code identity and trigger TCC prompts.

- Use `Scripts/dev-test.sh` only after explicit user approval for a local
  runtime test.
- Use the `ci`-labeled runner for ordinary CI tests.
- Use the `physical` + `macos-27.2` runner only for controlled physical
  validation sessions.

## Evidence locations

| Evidence | Location |
| --- | --- |
| Support/toolchain/release self-checks | `Scripts/verify-support-contract.sh`, `Scripts/verify-toolchain-locks.sh`, `Scripts/test-*.sh` |
| Local layout/state regressions | `build/layout-restore-evidence/`, `build/space-degradation-evidence/`, `build/state-recovery-evidence/` |
| Approved macOS 26 runtime bundle | `build/physical-validation/macos-26-runtime-20261103T113850Z/` (collection only; not a macOS 27.2 gate) |
| Release custom layout result bundles | `build/release-custom-layout-evidence/` |
| Physical session bundle | `Scripts/capture-physical-validation-evidence.sh` output |
| External release ownership | [release maintainer handoff](release-maintainer-handoff.md) |

This document deliberately does not mark any G1–G5 runtime or distribution
gate complete without its required physical or maintainer evidence. See the
[adaptation plan](macos-27-adaptation-plan.md),
[validation checklist](macos-27-validation-checklist.md), and
[support policy](macos-27-support-policy.md) for the authoritative criteria.
