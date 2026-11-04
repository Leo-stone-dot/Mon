---
name: Bug report
about: Create a report to help us improve
title: ''
labels: ''
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:

**Expected behavior**
A clear and concise description of what you expected to happen.

**Applications involved**
- App names:
- App types if known: AppKit / SwiftUI / Electron or Chromium / Catalyst / other
- Window type: normal window / dialog or sheet / full-screen / not resizable / other

**Amethyst build**
- Version:
- Build number:
- Install source: direct download / Homebrew / local build / other
- Artifact architecture from `lipo -archs /Applications/Amethyst.app/Contents/MacOS/Amethyst`:

**Mac and OS**
- Exact macOS version and build from `sw_vers`:
- Mac model:
- Chip:
- Architecture from `uname -m`:

**Displays**
- Number of displays:
- Arrangement: single / built-in + external / two external / other
- Any negative origin, vertical offset, rotation, scaled Retina, or hot-plug involved?
- Attach `system_profiler SPDisplaysDataType` if display topology is relevant.

**Spaces and window management**
- Separate Spaces: on / off
- Stage Manager: on / off
- Full-screen Space involved: yes / no
- Mission Control "Automatically rearrange Spaces": on / off
- Command involved: layout / focus / throw to Space / throw to screen / login item / update / other

**Permissions**
- Accessibility permission: granted / denied / revoked during run
- Screen Recording permission: granted / denied / not requested
- Secure Input suspected: yes / no / unsure
- TCC reset attempted: yes / no

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Debug Info**
```
$ /Applications/Amethyst.app/Contents/MacOS/Amethyst --debug-info [--include-apps]
```
Note: `--include-apps` will list your manageable applications, but is optional if you don't want to list that.

**Logs and validation evidence**
- Attach relevant Amethyst logs if available.
- Review the macOS 27 support guide before filing issues specific to macOS 27:
  `docs/macos-27-support.md`
- For macOS 27 release candidates or validation sessions, attach the output directory from:
```
$ Scripts/capture-physical-validation-evidence.sh
```

**Additional context**
Add any other context about the problem here.
