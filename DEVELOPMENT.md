# Development Guide

## Prerequisites

- macOS 14.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [SwiftLint](https://github.com/realm/SwiftLint) — `brew install swiftlint`
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) — `brew install swiftformat`
- [prek](https://github.com/j178/prek) — `brew install j178/tap/prek`

## Setup

```bash
git clone git@github.com:EurFelux/Lyrisland.git
cd Lyrisland
prek install      # install pre-commit hooks
xcodegen generate # generate Xcode project
```

Then open `Lyrisland.xcodeproj` in Xcode, or build from CLI:

```bash
xcodebuild -project Lyrisland.xcodeproj -scheme Lyrisland -destination 'platform=macOS' build
```

## Code Quality

SwiftFormat and SwiftLint run automatically at two stages:

1. **Pre-commit** — via prek, blocks commit if lint errors exist
2. **Xcode build** — as pre-build scripts, formats and lints on every build

To run manually:

```bash
swiftformat Sources
swiftlint --fix Sources && swiftlint Sources
```

Config files: `.swiftformat`, `.swiftlint.yml`, `prek.toml`.

## Project Generation

The `.xcodeproj` is gitignored and generated from `project.yml` via XcodeGen. Re-run after:

- Adding or removing source files
- Changing build settings or entitlements

```bash
xcodegen generate
```

> **Note:** `xcodegen generate` overwrites `Lyrisland.entitlements` from `project.yml`'s `entitlements.properties`. Don't hand-edit the entitlements file directly.
