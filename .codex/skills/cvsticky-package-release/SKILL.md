---
name: cvsticky-package-release
description: Package this CVSticky SwiftPM macOS repository into dist/CVSticky.app, dist/CVSticky-macOS-arm64.dmg, and dist/CVSticky-macOS-arm64.zip with the project-specific resource-bundle fix and verification. Use when the user asks to rebuild, repackage, recreate, verify, or resend the CVSticky macOS DMG or app from this repository after release packaging, especially when avoiding the SwiftPM CVSticky_CVSticky.bundle flattening crash.
---

# CVSticky Package Release

## Overview

Use this skill only inside the CVSticky macOS repository.
The critical packaging invariant is that `CVSticky_CVSticky.bundle` must remain a valid macOS bundle:

```text
CVSticky.app/Contents/Resources/CVSticky_CVSticky.bundle/Contents/Info.plist
CVSticky.app/Contents/Resources/CVSticky_CVSticky.bundle/Contents/Resources/milkdown-editor.js
CVSticky.app/Contents/Resources/CVSticky_CVSticky.bundle/Contents/Resources/milkdown-editor.css
```

If that bundle is flattened so resources sit directly under `CVSticky_CVSticky.bundle/`, `Bundle.module` fails at launch and the app crashes when `MarkdownWYSIWYGEditor` loads.

## Preferred Workflow

1. Work from the repository root.
2. Run the project-level script:

```bash
.codex/skills/cvsticky-package-release/scripts/package_cvsticky.sh
```

3. If `swift build` fails because the current Command Line Tools cannot load SwiftUI macros, use the existing release build artifacts:

```bash
.codex/skills/cvsticky-package-release/scripts/package_cvsticky.sh --from-existing-release
```

4. If `hdiutil create` or `hdiutil attach` fails with `设备未配置` or a sandbox device error, rerun that command with escalation. Do not skip DMG verification unless the user explicitly accepts the risk.

## Outputs

The script produces:

```text
dist/CVSticky.app
dist/CVSticky-macOS-arm64.dmg
dist/CVSticky-macOS-arm64.zip
```

Give the user clickable absolute links to the DMG and, if useful, the app and ZIP.

## Verification

Always verify these before final response:

```bash
find dist/CVSticky.app/Contents/Resources/CVSticky_CVSticky.bundle -maxdepth 3 -type f \( -name Info.plist -o -name milkdown-editor.js -o -name milkdown-editor.css \)
codesign --verify --deep --strict --verbose=2 dist/CVSticky.app
```

For the DMG, mount read-only and check the same structure:

```bash
mkdir -p /tmp/cvsticky-dmg-check
hdiutil attach -readonly -nobrowse -mountpoint /tmp/cvsticky-dmg-check dist/CVSticky-macOS-arm64.dmg
find /tmp/cvsticky-dmg-check/CVSticky.app/Contents/Resources/CVSticky_CVSticky.bundle -maxdepth 3 -type f \( -name Info.plist -o -name milkdown-editor.js -o -name milkdown-editor.css \)
codesign --verify --deep --strict --verbose=2 /tmp/cvsticky-dmg-check/CVSticky.app
hdiutil detach /tmp/cvsticky-dmg-check
```

## User Guidance

When the user tests the package, tell them to delete `/Applications/CVSticky.app` first and then drag the new app from the new DMG. This avoids macOS continuing to run an old installation whose resource bundle was flattened.
