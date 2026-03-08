# AGENTS.md

## Cursor Cloud specific instructions

This is a native iOS app (Swift 5 / Xcode) — a client for [appdb.to](https://appdb.to). The codebase consists of 335 Swift source files across two targets: the main `appdb` app and a `Widgets` extension.

### Environment constraints

- **This project requires macOS + Xcode to build and run.** On Linux Cloud VMs, you can only perform linting and syntax checking — not a full build or simulator run.
- There is no `Package.swift`; dependencies are managed via Xcode's SPM integration inside `appdb.xcodeproj`.
- There are **no automated test targets** (no unit tests or UI tests).

### Available tooling on Linux

| Tool | Command | Notes |
|---|---|---|
| **SwiftLint** | `swiftlint lint` | Run from repo root. Config: `.swiftlint.yml`. Reports 204 warnings, 0 errors on current codebase. |
| **Swift syntax check** | `swiftc -parse <file.swift>` | Checks individual file syntax. Does not resolve imports (UIKit etc. are macOS/iOS-only). |

### Key directories

- `appdb/` — Main app source (models, tabs, API, networking, extensions, resources)
- `Widgets/` — WidgetKit extension (home screen widgets)
- `appdb.xcodeproj/` — Xcode project (build settings, SPM package references, schemes)
- `.swiftlint.yml` — SwiftLint configuration

### No backend / no local services

The app is a thin API client that talks to `https://api.dbservices.to/v1.7/`. There are no local databases, Docker containers, or backend servers to run.
