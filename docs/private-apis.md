# Private macOS API Boundary

Mon uses macOS private Space APIs for display and desktop awareness. Apple does
not guarantee these APIs across macOS releases. This document defines the project
boundary for using them and the required degradation behavior.

## APIs and data shape

The private boundary includes these functions and Space dictionary fields:

- `CGSCopyManagedDisplaySpaces`
- `CGSCopySpacesForWindows`
- `CGSSpaceID`
- `CGSSpaceType`
- Space `uuid`
- `ManagedSpaceID`
- `Current Space`
- `Spaces`
- `Display Identifier`
- `type`
- `fs_wid`

These values are treated as runtime observations, not stable schema.

## Features that depend on the private boundary

- Display and desktop inventory in Preferences → Displays.
- Space-specific layout and tiling state.
- Filtering windows by current Space.
- Moving or throwing windows between Spaces.
- Distinguishing desktop Spaces from fullscreen/system Spaces.
- Space command availability diagnostics.

## Required degradation behavior

When the private Space boundary is unavailable or reports an unknown shape:

1. Mon must not fail application launch.
2. Core tiling, focus, and movement between displays should remain available.
3. Space-dependent commands must fail closed.
4. The status menu must surface a diagnostic reason when Space commands are disabled.
5. Window selection may fall back to visible active windows on the current display.
6. Saved layout state must not be deleted solely because the private boundary failed.

## Development requirements

Changes that add or modify private Space API usage must include:

- An injectable boundary or test fixture for the new behavior.
- A regression case for the failure or unknown-shape path.
- A user-visible diagnostic when a command is disabled.
- A verification note in the relevant support or validation document when runtime
  behavior cannot be fully covered by unit tests.

Do not expand the private boundary for convenience when a public AppKit,
Accessibility, or CoreGraphics API can provide the required behavior.

## Distribution boundary

Private API usage makes Mac App Store distribution unsuitable for Mon. Source-only
GitHub releases and optional Developer ID distribution remain possible, but
notarization or Developer ID signing does not make the private Space APIs stable.

## Validation entry points

Use these documents with this boundary:

- [macOS 27 Support Guide](macos-27-support.md)
- [macOS 27 Support Policy](macos-27-support-policy.md)
- [macOS 27 Validation Checklist](macos-27-validation-checklist.md)
