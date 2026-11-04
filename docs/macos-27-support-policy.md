# macOS 27 Support Policy

This document is the product support contract for releases built from the
macOS 27 adaptation work. It is intentionally narrower than historical
Amethyst releases.

## Supported configurations

| Architecture | Operating system | Support level |
| --- | --- | --- |
| Apple silicon `arm64` | macOS 26.x–27.x | Full support. macOS 26.0 is the deployment floor; macOS 26.6.2 stable-signed runtime is the current baseline. macOS 27.2 physical validation is deferred. |
| `arm64e.x1` on M6+ | macOS 27.x | Compatibility observation only; no separate artifact or optimization gate. |

New artifacts have `MACOSX_DEPLOYMENT_TARGET=26.0` and contain only an `arm64`
slice. Intel, Rosetta, universal binaries, and macOS 25 or earlier are out of
scope. The final pre-migration Intel-compatible artifact remains downloadable
but is end-of-support and must not receive a macOS 26+ Sparkle update.

Public configuration keys, YAML/JSON locations, shortcuts, layout state, and
custom JavaScript layout semantics remain compatible unless a separately
reviewed migration says otherwise.

## Release blockers

A release cannot be described as macOS 27 compatible until G0 through G5 in
the [adaptation plan](macos-27-adaptation-plan.md#7-release-gates) have current,
traceable evidence. In particular:

- Xcode 27.2 compilation is not evidence of macOS 27.2 runtime behavior.
- Unit tests do not replace Accessibility, TCC, Space, display, login, update,
  signing, notarization, or soak evidence.
- A release artifact must be `arm64` only and have a minimum system version of
  26.0 in the target, built Info.plist, README, and appcast item.

Evidence is recorded with
[the versioned validation checklist](macos-27-validation-checklist.md).

## Decision record

| Decision | State | Contract |
| --- | --- | --- |
| D1 architecture | Accepted in the adaptation plan | Apple silicon only; release artifact is `arm64` only. |
| D2 system floor | Revised 2026-11-03 by maintainer decision | macOS 26.0; Apple silicon only, no Intel/Rosetta support. macOS 27.x remains in support. |
| D3 private Space failure | Awaiting maintainer sign-off | Recommended: disable only Space-dependent commands, surface a diagnostic reason, and preserve core tiling/focus/screen movement. |
| D4 runtime gate | Deferred by maintainer on 2026-11-03 | Current use/code-release baseline is macOS 26.6.2 stable-signed runtime. Do not claim macOS 27.2 physical verification until its matrix is restored. |
| D5 Sparkle trust | Deferred by maintainer on 2026-11-03 | Production signing, notarization, Sparkle key, appcast, and release approval are postponed. If resumed, use Sparkle EdDSA plus Developer ID/notarization. |

On 2026-11-03 the maintainer assigned production credentials, appcast publication
and withdrawal, and D3–D5 sign-off to themselves. The
[maintainer handoff](release-maintainer-handoff.md) lists the required actions
and evidence. Implementation and automated validation continue; those external
steps do not imply approval or completion of the release gates.

## Degradation boundary

The proposed fail-closed boundary for a missing or changed private Space API is
to disable Space inventory/HUD/throw commands while preserving ordinary window
discovery, tiling, focus, and movement between screens. Missing Accessibility
permission, login registration, or updater availability must remain a visible,
recoverable state and must not prevent application launch. This section becomes
normative only when D3 is accepted.
