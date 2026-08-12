# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Scope

`null-app` is a **standalone SwiftUI application** and a self-contained git repository. It shares no code, design system, or conventions with any sibling folder under `WROKSPACE/`. The workspace-level `CLAUDE.md` at `/Users/purintae/Documents/WROKSPACE/CLAUDE.md` auto-loads and describes a documents-only workspace with "no build, test, or lint step" — **that does not apply here**. This project builds with Xcode, and the instructions in this file take precedence.

As of writing, the app is an unmodified Xcode SwiftUI template: `null_appApp.swift` (the `@main` entry point) renders `ContentView.swift`, which shows a globe icon and "Hello, world!".

## Commands

Build for simulator (no code signing required):

```bash
xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build
```

Build for macOS:

```bash
xcodebuild -scheme null-app -destination 'platform=macOS' build
```

Clean:

```bash
xcodebuild -scheme null-app clean
```

There is **no test target**. `xcodebuild test` will fail until one is added to the project.

## Project configuration

Facts that are spread across `project.pbxproj` and shape how you should work:

**Synchronized file groups.** The project uses `PBXFileSystemSynchronizedRootGroup` (`objectVersion = 77`, Xcode 16+). Every file under `null-app/` is picked up automatically. **Create new Swift files with the Write tool directly — never hand-edit `project.pbxproj` to register them.** Editing that file to add sources is both unnecessary and likely to corrupt the project.

**One target, four platforms.** A single `null-app` target ships to iOS, iPadOS, macOS, and visionOS (`TARGETED_DEVICE_FAMILY = "1,2,7"`, `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator"`). There is no per-platform target, so all code is shared. When a layout or API only makes sense on one platform, gate it with `#if os(...)` or size-class checks rather than assuming iPhone.

**MainActor by default.** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` are set, while `SWIFT_VERSION = 5.0` keeps language mode 5. Practically: unannotated types and functions are already main-actor-isolated, so UI code needs no `@MainActor` annotation, and work intended to run off the main actor must be explicitly marked (`nonisolated`, or moved into an actor / `Task.detached`).

**No Info.plist file.** `GENERATE_INFOPLIST_FILE = YES`. To add plist keys (usage descriptions, URL schemes, background modes), add `INFOPLIST_KEY_*` build settings rather than creating an `Info.plist`.

**Deployment target 26.5** for both iOS and macOS. Availability checks are unnecessary for anything introduced at or below 26.5 — modern APIs (`@Observable`, SwiftData, the current SwiftUI surface) can be used unconditionally.

**Signing.** `CODE_SIGN_STYLE = Automatic` with no `DEVELOPMENT_TEAM` set. Simulator builds work as-is; building for a physical device requires selecting a team in Xcode first. Bundle identifier is `purin.null-app`.
